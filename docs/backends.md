# Backends

How to add an architecture, an addon, or an operating system to the lane ladder.
The rules below were checked against V 0.5.2 (`v version` prints
`V 0.5.2 74e5877` on the machine this was written on); the traps are things that
looked like they should work and did not.

## Where things live

```
simd/backend/backend.v        the lane ladder and the dispatch, one branch per operation
simd/backend/default.v        the pure V kernels: no gate, compiled everywhere
simd/backend/sse2_amd64.c.v   x86-64 SSE2 kernels
simd/backend/fma_amd64.c.v    the FMA addon kernel
simd/backend/neon_arm64.c.v   AArch64 NEON kernels
```

## How V chooses files

Two mechanisms do most of the gating, and neither needs a line of V code:

- A file name carrying an architecture marker (`x_amd64.v`, `x_arm64.v`) is not
  compiled for other architectures, and one carrying an OS marker (`_linux`,
  `_windows`, `_macos`, `_nix`, `_bsd`, `_freebsd`, `_openbsd`, `_netbsd`,
  `_dragonfly`, `_solaris`, `_android`, `_termux`, `_ios`) is not compiled for
  other systems. `_nix` means "not Windows"; `_bsd` covers macOS and the four
  BSDs; `_freebsd` and friends are listed next to `os_specific_suffixes` in
  `vlib/v/pref/pref.v`, which is the only complete list. The C backend marker
  (`.c.v`) keeps a file out of the JS, WASM and native backends.
- The check is the file name and nothing else. A `_windows.c.v` file with a
  deliberate syntax error does not stop a Linux build, and it does stop a
  `-os windows` one. That is the whole mechanism.
- The marker has to be preceded by a `.` or a `_`. A file called `arm64.v` is
  compiled everywhere, because there is no marker in it; it has to be
  `kernels_arm64.v` or `kernels.arm64.v`.

The trailing `.c.v` does not conflict with the arch marker, so
`sse2_amd64.c.v` is both amd64-only and C-backend-only.

## How a lane is gated

Inside a file that is compiled for the right target, a lane-specific kernel sits
in a top-level `$if`:

```v
$if lane == 'sse2' || lane == 'fma' {
	pub fn add_f32x4_sse2(a [4]f32, b [4]f32) [4]f32 { ... }
}
```

`lane` is a string constant declared in `backend.v`, not an enum member, because
`$if` compares comptime string constants (`$if lane == 'sse2'`) but not enum
members (`$if lane == .sse2` silently takes the else branch, which is worse than
an error).

Two more `$if` details worth knowing before you write a gate:

- Target and toolchain flags are written plain: `$if amd64`, `$if tinyc`,
  `$if gcc && !msvc`, `$if @BACKEND == 'c'`. With a `?` (`$if tinyc ?`) they are
  false, which is the wrong answer rather than an error, so a gate written that
  way just never fires.
- User defines (`-d simd_addon_fma`) are the opposite: they need the `?`
  (`$if simd_addon_fma ?`). Written plain, an undefined define is a hard error
  (`undefined ident`). And `-d flag=false` still counts as defined, so a define
  is a switch, not a value.

## A NEON kernel cannot be written as a mnemonic

The V lexer reads `v0.4s` as the number `0.4` followed by a stray digit, so

```v
fadd v0.4s, v0.4s, v1.4s   // error: this number has unsuitable digit `s`
```

does not compile on any target, including arm64. Every NEON vector instruction
needs an arrangement suffix, so NEON arithmetic is written as raw words:

```v
ldr q0, [a]
ldr q1, [b]
.inst 0x4e21d400 // fadd v0.4s, v0.4s, v1.4s
str q0, [out]
```

Loads and stores need no suffix and stay readable. The words are checked against
the assembler by `tools/check-neon-encodings.sh`, which assembles
`tools/neon_kernels.s` for AArch64 and compares the encodings with the `.inst`
words in the kernel file. Add a mnemonic to both files, in any order; the script
compares sets.

## Adding an architecture

1. Write the kernels in a new file named after the architecture, gated on the
   lane it serves: `backend/myarch.v` with `$if lane == 'myarch' { ... }` around
   the kernels. Take `[4]f32` in and return `[4]f32`, move only pointers across
   the boundary, and mark the asm block `volatile` with a `memory` clobber.
2. Add a `Lane` member and a ladder branch in `backend.v`, with the target and
   toolchain conditions the kernels need.
3. Add the dispatch branch to every operation in `backend.v`, next to its
   siblings: `$else $if lane == 'myarch' { return add_f32x4_myarch(a, b) }`.
4. Gate the addon the architecture does not need. NEON has FMLA, so
   `-d simd_addon_fma` on arm64 is a `$compile_error`; an architecture with a
   fused multiply-add should do the same rather than accept a flag it ignores.
5. Run `tools/check-lanes.sh`, then `tools/check-targets.sh`. A lane that has
   never been built outside the host it was written on has not been ported.

## Adding an addon

An addon is a lane selected by a define, and the rule that keeps addons honest is
that a wider register needs a wider type. For four f32 lanes, SSE2 already fills
the register: AVX2 and AVX-512 would compute the same four results in a wider
register, which is slower and no more accurate. So the 256-bit and 512-bit lanes
belong with `F32x8` and `F32x16`, in files named `avx2_amd64.c.v` and
`avx512_amd64.c.v`, selected by `-d simd_addon_avx2` and `-d simd_addon_avx512f`.

FMA is the exception: it changes an existing operation on an existing type.
`mul_add` stops rounding twice, and that is worth a lane, a flag, and a test that
notices.

The gates to copy, in `backend.v`:

```v
$if simd_addon_avx512f ? && !amd64 {
	$compile_error('simd: -d simd_addon_avx512f is an amd64 addon')
}
```

## Operating systems

No OS appears in the lane ladder today, and none is needed: the kernels touch no
OS API, and no vector value crosses a function boundary. An OS file becomes
necessary when a kernel takes a vector argument (Windows x64 and System V pass
them differently), when a lane needs a runtime feature probe (`getauxval` on
Linux, `sysctl` on macOS, `IsProcessorFeaturePresent` on Windows), or when an
instruction needs the OS to have enabled it. The naming is already there:
`backend/probe_linux.c.v`, `backend/abi_windows.c.v`, and so on.

## What has been built where

| lane | target | host | state |
| --- | --- | --- | --- |
| `pure_v` | linux/amd64 | same | tests pass, tcc default |
| `sse2` | linux/amd64 | same | tests pass with gcc and clang |
| `fma` | linux/amd64 | same | tests pass, and the fused rounding is asserted |
| `neon` | linux/arm64 | amd64 + zig | cross assembled, checksums not executed |
| `sse2` | windows/amd64 | amd64 + mingw | linked to a PE32+ executable, not run |
| `pure_v` | linux/arm32, wasm32, js | same | C/JS generated, no native lane selected |
| `sse2` | macos/amd64, freebsd/amd64 | amd64 | C generated, no cross SDK to link |

The `neon` row is the important gap: the encodings are confirmed by
disassembling the cross assembled object, which catches a wrong instruction, but
nothing has run the lane on real AArch64 hardware yet.
