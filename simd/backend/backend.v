module backend

// This file is the single point of the module: it decides which lane a build
// runs, and it is the only place that knows how an operation reaches a lane.
//
// Layout
//
//	backend/backend.v         lane ladder, dispatch, and lane reporting (this file)
//	backend/default.v         the pure V lane: always compiled, never gated, the reference
//	backend/sse2_amd64.c.v    x86-64 SSE2 kernels for the sse2 lane
//
// A native lane lands as two edits: a kernel file next to this one, and a branch
// in the ladder below plus a branch in the operations at the bottom.
//
// File names carry the target filter; contents carry the lane filter. V compiles
// a file whose name holds another architecture's marker (`..._amd64.v` on an
// AArch64 build) nowhere, so an arch specific file never has to write `$if
// arm64 { }` around itself. Within a compiled file, a lane-specific kernel sits
// in a top level `$if lane == '<lane>' { }` block, which is why an operation
// naming a kernel that does not exist on this target is still fine: the branch
// holding the reference is gone before the checker looks at it.

// Lane names the kernel set a build runs.
pub enum Lane {
	pure_v
	sse2
}

// lane is the whole lane decision, and every dispatch function below reads it.
//
// It is a string rather than a Lane member because `$if` compares comptime string
// constants but not enum members. Each branch is a documented build shape, in
// order of preference:
//
//	- `-d simd_force_pure_v`  the caller asked for the pure V lane whatever else fits
//	- amd64                   GCC/Clang, C backend: SSE2 kernels, split mul_add
//	- anything else           tcc, MSVC, JS, WASM, the native backends, other archs
//
// GCC and Clang are the only C compilers that assemble V inline assembly, so tcc
// and MSVC fall through to the pure V lane instead of failing to build.
$if simd_force_pure_v ? {
	pub const lane = 'pure_v'
} $else $if amd64 && !tinyc && !msvc && @BACKEND == 'c' {
	pub const lane = 'sse2'
} $else {
	pub const lane = 'pure_v'
}

// active_lane returns lane as a Lane, for callers that prefer a typed comparison
// over lane_name().
pub fn active_lane() Lane {
	return match lane {
		'sse2' { .sse2 }
		else { .pure_v }
	}
}

// has_native_lane reports whether the build runs on anything other than the pure
// V lane.
pub fn has_native_lane() bool {
	return lane != 'pure_v'
}

// add_f32x4 adds corresponding lanes.
@[inline]
pub fn add_f32x4(a [4]f32, b [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return add_f32x4_sse2(a, b)
	} $else {
		return add_f32x4_pure_v(a, b)
	}
}

// sub_f32x4 subtracts corresponding lanes.
@[inline]
pub fn sub_f32x4(a [4]f32, b [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return sub_f32x4_sse2(a, b)
	} $else {
		return sub_f32x4_pure_v(a, b)
	}
}

// mul_f32x4 multiplies corresponding lanes.
@[inline]
pub fn mul_f32x4(a [4]f32, b [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return mul_f32x4_sse2(a, b)
	} $else {
		return mul_f32x4_pure_v(a, b)
	}
}

// div_f32x4 divides corresponding lanes.
@[inline]
pub fn div_f32x4(a [4]f32, b [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return div_f32x4_sse2(a, b)
	} $else {
		return div_f32x4_pure_v(a, b)
	}
}

// sqrt_f32x4 returns the square root of each lane.
@[inline]
pub fn sqrt_f32x4(a [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return sqrt_f32x4_sse2(a)
	} $else {
		return sqrt_f32x4_pure_v(a)
	}
}

// mul_add_f32x4 returns v * multiplier + addend for each lane. SSE2 has no fused
// multiply-add, so the sse2 lane rounds twice, like the pure V lane.
pub fn mul_add_f32x4(v [4]f32, multiplier [4]f32, addend [4]f32) [4]f32 {
	$if lane == 'sse2' {
		return mul_add_f32x4_sse2(v, multiplier, addend)
	} $else {
		return mul_add_f32x4_pure_v(v, multiplier, addend)
	}
}
