module simd

import simd.backend

// F32x4 holds four f32 values for lane wise arithmetic.
//
// Arithmetic operators work on corresponding lanes. The module is a drop in
// replacement for vlib's `simd` module: same names, same signatures, same error
// messages. The difference is underneath. vlib's module forwards to C compiler
// builtins (`_mm_add_ps`, `vaddq_f32`); this one runs on a lane picked from
// `simd/backend/`, and the pure V lane needs nothing but the V compiler itself.
//
//	import simd
//
//	fn main() {
//		a := simd.f32x4(1, 2, 3, 4)
//		b := simd.broadcast_f32x4(2)
//		println((a * b).to_array()) // [2.0, 4.0, 6.0, 8.0]
//	}
pub struct F32x4 {
	values [4]f32
}

// f32x4 creates a vector from four values in lane order.
pub fn f32x4(a f32, b f32, c f32, d f32) F32x4 {
	return F32x4{[a, b, c, d]!}
}

// broadcast_f32x4 copies value into all four lanes.
pub fn broadcast_f32x4(value f32) F32x4 {
	return F32x4{[value, value, value, value]!}
}

// load_f32x4 loads four values from the start of src.
pub fn load_f32x4(src []f32) !F32x4 {
	if src.len < 4 {
		return error('simd.load_f32x4 needs at least 4 values')
	}
	return F32x4{[src[0], src[1], src[2], src[3]]!}
}

// load_f32x4_part loads up to four values and zero-fills the remaining lanes.
pub fn load_f32x4_part(src []f32) !F32x4 {
	if src.len > 4 {
		return error('simd.load_f32x4_part accepts at most 4 values')
	}
	mut values := [4]f32{}
	for i, value in src {
		values[i] = value
	}
	return F32x4{values}
}

// to_array returns the four lanes in order.
pub fn (v F32x4) to_array() [4]f32 {
	return v.values
}

// store writes all four lanes to the start of dst.
pub fn (v F32x4) store(mut dst []f32) ! {
	if dst.len < 4 {
		return error('simd.F32x4.store needs at least 4 values')
	}
	for i in 0 .. 4 {
		dst[i] = v.values[i]
	}
}

// store_part writes one lane for each element of dst, up to four elements.
pub fn (v F32x4) store_part(mut dst []f32) ! {
	if dst.len > 4 {
		return error('simd.F32x4.store_part accepts at most 4 values')
	}
	for i in 0 .. dst.len {
		dst[i] = v.values[i]
	}
}

// + adds corresponding lanes.
@[inline]
pub fn (v F32x4) + (other F32x4) F32x4 {
	return F32x4{backend.add_f32x4(v.values, other.values)}
}

// - subtracts corresponding lanes.
@[inline]
pub fn (v F32x4) - (other F32x4) F32x4 {
	return F32x4{backend.sub_f32x4(v.values, other.values)}
}

// * multiplies corresponding lanes.
@[inline]
pub fn (v F32x4) * (other F32x4) F32x4 {
	return F32x4{backend.mul_f32x4(v.values, other.values)}
}

// / divides corresponding lanes.
@[inline]
pub fn (v F32x4) / (other F32x4) F32x4 {
	return F32x4{backend.div_f32x4(v.values, other.values)}
}

// sqrt returns the square root of each lane.
@[inline]
pub fn (v F32x4) sqrt() F32x4 {
	return F32x4{backend.sqrt_f32x4(v.values)}
}

// mul_add returns v * multiplier + addend for each lane.
//
// Rounding follows the lane: a lane with a fused multiply-add instruction (the
// `fma` addon on x86-64, NEON on AArch64) rounds once, every other lane rounds
// twice. Like vlib's module, this one does not promise fused rounding either way.
// Use simd.lane() when a caller has to know which rounding it gets.
pub fn (v F32x4) mul_add(multiplier F32x4, addend F32x4) F32x4 {
	return F32x4{backend.mul_add_f32x4(v.values, multiplier.values, addend.values)}
}

// sum adds the four lanes in lane order.
pub fn (v F32x4) sum() f32 {
	return v.values[0] + v.values[1] + v.values[2] + v.values[3]
}

// lane reports the kernel lane compiled into this build. Lane selection is
// chosen once per build in `simd/backend/backend.v`; see docs/backends.md for the
// rules and the flags that pick a lane.
pub fn lane() backend.Lane {
	return backend.active_lane()
}

// lane_name reports lane() as a string, for logs and test output.
pub fn lane_name() string {
	return backend.lane
}
