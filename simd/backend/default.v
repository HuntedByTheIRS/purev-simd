module backend

import math

// The pure V lane. Plain lane arithmetic over the four values, no inline
// assembly, no C header, no compiler builtin.
//
// It is compiled into every build, including builds that run on a native lane,
// for two reasons: it is the fallback wherever inline assembly is unavailable
// (tcc, MSVC, the JS and WASM backends, the native backends, every architecture
// without a kernel here), and it is the reference the native lanes are checked
// against, in process, by the tests in tier_test.v.
//
// The functions are spelled out lane by lane rather than looped so a C compiler
// has an unrolled body to autovectorize. Nothing depends on it doing so.

// add_f32x4_pure_v adds corresponding lanes.
pub fn add_f32x4_pure_v(a [4]f32, b [4]f32) [4]f32 {
	return [a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]]!
}

// sub_f32x4_pure_v subtracts corresponding lanes.
pub fn sub_f32x4_pure_v(a [4]f32, b [4]f32) [4]f32 {
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]]!
}

// mul_f32x4_pure_v multiplies corresponding lanes.
pub fn mul_f32x4_pure_v(a [4]f32, b [4]f32) [4]f32 {
	return [a[0] * b[0], a[1] * b[1], a[2] * b[2], a[3] * b[3]]!
}

// div_f32x4_pure_v divides corresponding lanes.
pub fn div_f32x4_pure_v(a [4]f32, b [4]f32) [4]f32 {
	return [a[0] / b[0], a[1] / b[1], a[2] / b[2], a[3] / b[3]]!
}

// sqrt_f32x4_pure_v returns the square root of each lane.
pub fn sqrt_f32x4_pure_v(a [4]f32) [4]f32 {
	return [f32(math.sqrt(a[0])), f32(math.sqrt(a[1])), f32(math.sqrt(a[2])), f32(math.sqrt(a[3]))]!
}

// mul_add_f32x4_pure_v returns v * multiplier + addend for each lane, rounding
// twice, the way separate multiply and add instructions do.
pub fn mul_add_f32x4_pure_v(v [4]f32, multiplier [4]f32, addend [4]f32) [4]f32 {
	return [v[0] * multiplier[0] + addend[0], v[1] * multiplier[1] + addend[1],
		v[2] * multiplier[2] + addend[2], v[3] * multiplier[3] + addend[3]]!
}
