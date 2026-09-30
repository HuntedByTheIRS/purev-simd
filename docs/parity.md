# Parity with vlib's simd module

The point of this module is that existing code does not have to change, so the
public surface is vlib's, name for name.

## API

| vlib `simd` | here | notes |
| --- | --- | --- |
| `F32x4` | same | same field layout, private `values [4]f32` |
| `f32x4(a, b, c, d) F32x4` | same | |
| `broadcast_f32x4(value) F32x4` | same | |
| `load_f32x4(src) !F32x4` | same | errors when `src.len < 4` |
| `load_f32x4_part(src) !F32x4` | same | zero fills, errors when `src.len > 4` |
| `(v F32x4) to_array() [4]f32` | same | |
| `(v F32x4) store(mut dst) !` | same | errors when `dst.len < 4` |
| `(v F32x4) store_part(mut dst) !` | same | errors when `dst.len > 4` |
| `(v F32x4) + - * / (other F32x4)` | same | lane wise |
| `(v F32x4) sqrt() F32x4` | same | |
| `(v F32x4) mul_add(mul, add) F32x4` | same | rounding differs by lane, see below |
| `(v F32x4) sum() f32` | same | lane order |
| errors | same text | `simd.load_f32x4 needs at least 4 values`, and the rest |

Two things are new, because they are how code and tests ask which lane they got:

| addition | returns |
| --- | --- |
| `simd.lane() backend.Lane` | `.pure_v`, `.sse2`, `.fma` or `.neon` |
| `simd.lane_name() string` | the same as text, for logs |
| `simd.backend.lane` | the constant the ladder and the dispatch both use |

`simd.backend` is a public module. vlib's kernels are module private; here they
are the reference lane the tests compare against, and a caller who wants the
portable answer regardless of the target can call
`simd.backend.add_f32x4_pure_v(...)` on purpose.

## Behaviour differences

`mul_add` is the only operation whose result can differ from vlib's.

vlib's `mul_add` is `v * multiplier + addend`, and the README there says it does
not promise fused rounding. On the C backend with SSE or NEON the compiler may
contract it into an FMA; anywhere else it rounds twice.

Here it depends on the lane: `fma` and `neon` round once, `sse2` and `pure_v`
round twice, and a C compiler may still contract the split lanes on its own. Code
that needs a particular rounding should ask `simd.lane_name()` rather than assume,
which is what `tier_test.v` does.

Everything else is exact: the four arithmetic operations, `sqrt`, `sum`, lane
order and the error text are the same on every lane, and `tier_test.v` compares
the live lane against the pure V reference to keep it that way.

## Compile flags

| vlib | here |
| --- | --- |
| `-cflags -DV_SIMD_FORCE_SCALAR` (scalar C in the header) | `-d simd_force_pure_v` (the pure V lane) |
| `-cflags -mavx2` and similar are ignored, only SSE/NEON are used | `-d simd_addon_fma` adds the FMA lane; wider addons arrive with wider types |

## Swapping it in

The module directory is `simd/`, so a project that has it on its module path gets
it for `import simd` in place of vlib's:

```sh
# vendor it next to your project, or point V at the checkout
v -path "/path/to/purev-simd|@vlib|@vmodules" run your_program.v
```

`tier_test.v` and `simd_test.v` sit in the repository root on purpose. A test
file one directory down, or inside `simd/` itself, resolves `import simd` to
vlib's module instead of this one and passes while testing the wrong code. That
trap is why the tests live where they do.

## What was left out

`simd/simd.h`, `simd/simd.c.v` and the `#flag -I @VEXEROOT/vlib/simd` include have
no counterpart: there is no C header in this module. The `$if @BACKEND == 'c'`
branch in vlib's operators is gone too, replaced by the lane dispatch in
`simd/backend/backend.v`.
