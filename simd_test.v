module main

import simd
import simd.backend

// API parity with vlib's simd module. The first three tests are vlib's
// simd/simd_test.v carried over unchanged except for the import, so a behaviour
// difference shows up as a failing test rather than as a missing one.

fn test_f32x4_arithmetic() {
	a := simd.f32x4(1, 4, 9, 16)
	b := simd.broadcast_f32x4(2)
	assert (a + b).to_array() == [f32(3), 6, 11, 18]!
	assert (a - b).to_array() == [f32(-1), 2, 7, 14]!
	assert (a * b).to_array() == [f32(2), 8, 18, 32]!
	assert (a / b).to_array() == [f32(0.5), 2, 4.5, 8]!
	assert a.sqrt().to_array() == [f32(1), 2, 3, 4]!
	assert a.mul_add(b, simd.broadcast_f32x4(1)).to_array() == [f32(3), 9, 19, 33]!
	assert a.sum() == 30
}

fn test_f32x4_load_store_and_tail() {
	src := [f32(1), 2, 3, 4, 5]
	v := simd.load_f32x4(src) or { panic(err) }
	mut dst := [f32(0), 0, 0, 0, 0]
	v.store(mut dst) or { panic(err) }
	assert dst == [f32(1), 2, 3, 4, 0]
	part := simd.load_f32x4_part(src[3..]) or { panic(err) }
	assert part.to_array() == [f32(4), 5, 0, 0]!
	mut tail := [f32(0), 0]
	part.store_part(mut tail) or { panic(err) }
	assert tail == [f32(4), 5]
	assert (simd.load_f32x4_part([]f32{}) or { panic(err) }).to_array() == [4]f32{}
}

fn test_f32x4_rejects_invalid_lengths() {
	mut failed := false
	simd.load_f32x4([f32(1), 2, 3]) or { failed = true }
	assert failed
	failed = false
	simd.load_f32x4_part([f32(1), 2, 3, 4, 5]) or { failed = true }
	assert failed
	mut short := [f32(0), 0, 0]
	failed = false
	simd.f32x4(1, 2, 3, 4).store(mut short) or { failed = true }
	assert failed
	mut long := [f32(0), 0, 0, 0, 0]
	failed = false
	simd.f32x4(1, 2, 3, 4).store_part(mut long) or { failed = true }
	assert failed
}

// The module keeps the error text vlib's module uses, so code that matches on it
// keeps working.
fn test_error_text_matches_vlib() {
	if _ := simd.load_f32x4([f32(1)]) {
		assert false
	} else {
		assert err.msg() == 'simd.load_f32x4 needs at least 4 values'
	}
	if _ := simd.load_f32x4_part([f32(1), 2, 3, 4, 5]) {
		assert false
	} else {
		assert err.msg() == 'simd.load_f32x4_part accepts at most 4 values'
	}
	mut dst := [f32(0), 0]
	if _ := simd.f32x4(1, 2, 3, 4).store(mut dst) {
		assert false
	} else {
		assert err.msg() == 'simd.F32x4.store needs at least 4 values'
	}
}

fn test_lane_is_reported() {
	assert simd.lane_name() in ['pure_v', 'sse2', 'fma', 'neon']
	assert simd.lane_name() == backend.lane
	assert backend.has_native_lane() == (simd.lane_name() != 'pure_v')
}

// Every lane has to answer the same arithmetic, so the public API is checked
// against the reference lane on inputs that are not all tidy round numbers.
fn test_public_api_agrees_with_the_reference_lane() {
	a := [f32(1), -2.5, 3.25, 65536]!
	b := [f32(3), 0.5, -4, 0.125]!
	assert (simd.f32x4(a[0], a[1], a[2], a[3]) + simd.f32x4(b[0], b[1], b[2], b[3])).to_array() == backend.add_f32x4_pure_v(a,
		b)
	assert (simd.f32x4(a[0], a[1], a[2], a[3]) - simd.f32x4(b[0], b[1], b[2], b[3])).to_array() == backend.sub_f32x4_pure_v(a,
		b)
	assert (simd.f32x4(a[0], a[1], a[2], a[3]) * simd.f32x4(b[0], b[1], b[2], b[3])).to_array() == backend.mul_f32x4_pure_v(a,
		b)
	assert (simd.f32x4(a[0], a[1], a[2], a[3]) / simd.f32x4(b[0], b[1], b[2], b[3])).to_array() == backend.div_f32x4_pure_v(a,
		b)
	assert simd.f32x4(a[0], a[1], a[2], a[3]).sqrt().to_array() == backend.sqrt_f32x4_pure_v(a)
}
