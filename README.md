# purev-simd

An alternate implementation of vlib's `simd` module that does not rely on C
compiler builtins.

vlib's module writes its kernels as `_mm_add_ps` and `vaddq_f32` in
`simd/simd.h` and calls them through a C file, which means SSE or NEON on the C
backend and a scalar fallback everywhere else: the JS, WASM and native backends,
and tcc or MSVC, which cannot compile those headers at all.

This module keeps the same API and puts the vector work in V. Operations run on
one of four lanes, picked at compile time from the target and the toolchain:

| lane | kernels | selected when |
| --- | --- | --- |
| `pure_v` | plain V lane arithmetic | always available; the fallback |
| `sse2` | V inline assembly, SSE2 | amd64, GCC or Clang, C backend |
| `fma` | `sse2` with a fused `mul_add` | the above plus `-d simd_addon_fma` |
| `neon` | V inline assembly, NEON | arm64, GCC or Clang, C backend |

```v
import simd

fn main() {
	a := simd.f32x4(1, 2, 3, 4)
	b := simd.broadcast_f32x4(2)
	println((a * b).to_array()) // [2.0, 4.0, 6.0, 8.0]
	println(simd.lane_name())   // pure_v, sse2, fma or neon
}
```

Everything vlib's module documents works the same way, including the error text,
the partial load and store helpers, and `mul_add` not promising fused rounding.
`docs/parity.md` has the full table and the one behavioral difference, which is
that fused rounding follows the lane.

## Using it

Point V at the checkout, or vendor the `simd/` directory next to your project:

```sh
v -path "/path/to/purev-simd|@vlib|@vmodules" run your_program.v
```

To pick a lane, and to see what a lane is worth on your machine:

```sh
v -path "@vlib|@vmodules|." run examples/demo.v
v -path "@vlib|@vmodules|." -cc gcc run examples/demo.v
v -path "@vlib|@vmodules|." -cc gcc -d simd_addon_fma run examples/demo.v
v -path "@vlib|@vmodules|." -cc gcc -d simd_force_pure_v run examples/demo.v
v -path "@vlib|@vmodules|." -cc gcc run bench/f32x4_bench.v
```

`-d simd_force_pure_v` is the portable lane, whatever the target can do. It is
the equivalent of vlib's `-cflags -DV_SIMD_FORCE_SCALAR`, except that it selects a
V implementation rather than a scalar `#else` branch in a C header.

## Layout

```
simd/simd.v                 F32x4 and the operators
simd/backend/backend.v      the lane ladder, the dispatch, the addon gates
simd/backend/default.v      the pure V kernels
simd/backend/sse2_amd64.c.v SSE2 kernels
simd/backend/fma_amd64.c.v  FMA addon kernel
simd/backend/neon_arm64.c.v NEON kernels
docs/                       design, porting guide, parity with vlib
tools/                      lane and target checks, NEON encoding check
simd_test.v, tier_test.v    tests, in the root on purpose (see docs/parity.md)
```

A port adds one file and one branch in the ladder; `docs/backends.md` has the
recipe and the traps, including the one that matters most: V's lexer cannot spell
a NEON arrangement suffix (`v0.4s`), so the AArch64 arithmetic is written as raw
instruction words that a script checks against the assembler.

## Checks

```sh
v test .                       # the lane this host gets by default
tools/check-lanes.sh           # every lane this host can select, tests each one
tools/check-targets.sh         # cross builds: windows, arm64, and the fallbacks
tools/check-neon-encodings.sh  # NEON words against the assembler
v fmt -verify simd/ simd_test.v tier_test.v
```

`tools/check-lanes.sh` prints the lane each run actually used and fails if a run
asked for one lane and got another. `tools/check-targets.sh` shows the lane in
the generated output rather than claiming one. Both skip a check whose toolchain
is missing, with a printed reason, and the addon gate check asserts the gate's
own message rather than a non-zero exit, because a compiler that is simply absent
also exits non-zero.

CI runs these same scripts rather than repeating their commands, so a lane that
passes there passes here. The jobs install only tools Ubuntu packages (tcc,
clang, mingw-w64); zig is not one of them and comes from an action, and a target
whose toolchain never arrives is skipped with its reason printed rather than
failing the job.

## State

`F32x4` is complete, which is the whole of vlib's module. The pure V, SSE2 and FMA
lanes have been built and run on linux/amd64; the NEON lane has been cross
assembled for linux/arm64 and disassembled to confirm the instructions, but not
run on AArch64 hardware. Windows has been linked to a PE32+ executable with mingw,
not executed. Wider types (`F32x8`, `F32x16`) and the 256-bit and 512-bit lanes
they need are not here yet; `docs/backends.md` says where they go and why a wider
register without a wider type would be a downgrade.

## License

MIT. See LICENSE.
