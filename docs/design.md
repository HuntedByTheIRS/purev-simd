# Design

## What this is

An implementation of vlib's `simd` module surface that does not lean on C
compiler builtins. vlib's module declares its four arithmetic kernels in
`simd/simd.h` as `_mm_add_ps` and `vaddq_f32` (with a scalar `for` loop in the
last `#else`), and calls them through `simd.c.v`. The C backend therefore gets
SSE or NEON, and every other combination gets the scalar loop: the JS and WASM
backends, the native backends, and tcc or MSVC, which cannot compile the
intrinsic headers the module includes.

Here the operations run on a **lane**, and which lane a build gets is decided at
compile time from the target and the toolchain:

| lane | what it runs | how it is selected |
| --- | --- | --- |
| `pure_v` | plain lane arithmetic in V | always available, the fallback |
| `sse2` | V inline assembly, SSE2 | amd64 + GCC/Clang + C backend |
| `fma` | `sse2` plus a fused `mul_add` | the `sse2` case plus `-d simd_addon_fma` |
| `neon` | V inline assembly, NEON | arm64 + GCC/Clang + C backend |

A build gets exactly one, and `simd.lane_name()` reports it.

## What "no C compiler builtins" means here, exactly

No `#include` of `xmmintrin.h` or `arm_neon.h`, no `__builtin_*`, no intrinsic
calls, no `#flag`, no C file in the library. The vector work is written in V.

The pure V lane leans on one library: vlib's `math.sqrt` for the `sqrt` kernel,
because there is no `sqrt` builtin on `f32` (`f32.sqrt` is `unknown method or
field`). It computes in f64 and narrows, which is correctly rounded for an f32
input and is what the hardware kernels produce too, so the two lanes agree on
every input the tests exercise.

The C compiler is still in the loop on a native lane: V lowers an `asm` block to
an asm template in the generated C, and the C compiler assembles it. That is
assembly, not a compiler extension, and it is the same asm on every compiler that
accepts GCC syntax. On the `pure_v` lane even that is gone: the module is V, and
what the C compiler does with it is the C compiler's business.

## Layers

```
simd/simd.v                 the public surface: F32x4, its operators, lane reporting
simd/backend/backend.v      the lane decision, the per operation dispatch, addon gates
simd/backend/default.v      the pure V kernels, compiled into every build
simd/backend/sse2_amd64.c.v the SSE2 kernels
simd/backend/fma_amd64.c.v  the FMA addon kernel
simd/backend/neon_arm64.c.v the NEON kernels
```

`simd/simd.v` knows nothing about targets. `simd/backend/backend.v` knows nothing
about `F32x4`; it deals in `[4]f32` values. A kernel file knows nothing about the
others. Adding an architecture touches one file and one branch.

The kernels take and return `[4]f32` by value and, on the assembly lanes, move
pointers in general purpose registers only. No vector value crosses a function
boundary, which is why there is no per-OS kernel file: System V and Windows x64
disagree about how a vector argument is passed, and an implementation that never
passes one does not have to care. A kernel that ever needs to take a vector
argument is the moment `backend/<arch>_windows.c.v` starts to be necessary.

## Why the lane is a build time decision

V's `$if` sees the target (`amd64`, `arm64`, `windows`, `linux`), the selected C
compiler (`tinyc`, `gcc`, `clang`, `msvc`) and user defines. It cannot see CPUID,
and there is no flag for an instruction set extension. So a lane is chosen from
what the build can prove: SSE2 is part of the x86-64 baseline, NEON is mandatory
on AArch64, and FMA3 is not, which is why fusing is an opt-in addon.

Runtime dispatch is possible (a function pointer per operation, filled from a
CPUID probe on x86 and `getauxval`/`sysctl` elsewhere) and it would let one binary
use AVX-512 where it exists. It costs an indirect call per operation and a
feature table per OS, and it changes this file's shape, so it is not here yet.
The lane constant is the place it would land.

## Invariants

- Exactly one lane owns the dispatch. `simd/backend/backend.v` picks it once, and
  every dispatch function branches on that same constant.
- The pure V lane compiles everywhere: every OS, every architecture, tcc, MSVC,
  the JS, WASM and native backends. It is what a new target gets on day one.
- The pure V kernels are compiled into every build, native lanes included, so the
  tests can compare the live lane against the reference in the same process.
- A kernel name belongs to one lane. Two lanes defining `add_f32x4_sse2` would
  collide at compile time, which is the intended failure.
- An addon the target cannot run fails the build with `$compile_error` instead of
  falling back quietly.

## Limits

Only `F32x4` is implemented, which is the whole of vlib's module. The kernel
layer was shaped for more widths, but a width is only worth adding with the
operations it needs, and a wider register lane is only worth adding with a type
wide enough to fill it: for four lanes, AVX2 and AVX-512 do not beat SSE2, which
is why the addon mechanism is demonstrated with FMA instead. Where those files
would go is in docs/backends.md.

The lanes are a portability story before they are a speed story, and the
benchmark says so on the machine this was written on: one operation at a time
through a kernel that takes pointers and carries a `memory` clobber costs more
than the same arithmetic inlined as V, because the accumulator leaves the
register file on every call and the optimiser is told to forget what it knew.
Measured on linux/amd64, `bench/f32x4_bench.v` reports the scalar loop at about
0.8x the sse2 lane's time per operation, and about 0.7x the pure V lane's, which
is the same code with a different name. Filling a 128-bit register to compute
four lanes is simply not a lot of work. What makes a lane worth having is a
wider type that needs the wider register, or code that keeps the vectors in
registers across a loop instead of crossing a function boundary per operation.
Both are future work; neither is here.

`mul_add` does not promise fused rounding, matching vlib. It does not promise
split rounding either: the `fma` and `neon` lanes round once, `sse2` and `pure_v`
round twice, and a C compiler is allowed to contract the split lanes into an FMA
on its own. Code that needs a specific rounding has to ask `simd.lane()`.

The `pure_v` lane is not a performance story. It is unrolled lane arithmetic with
an exact definition of every result, and it is what makes the module work
everywhere and testable everywhere.
