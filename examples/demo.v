module main

import simd

fn main() {
	a := simd.f32x4(1, 2, 3, 4)
	b := simd.broadcast_f32x4(2)
	println('lane                = ${simd.lane_name()}')
	println('a * b               = ${(a * b).to_array()}')
	println('sqrt(a)             = ${a.sqrt().to_array()}')
	println('mul_add(a, b, 1)    = ${a.mul_add(b, simd.broadcast_f32x4(1)).to_array()}')
	println('sum(a)              = ${a.sum()}')

	// A dot product over three vectors, the shape this module exists for: load a
	// vector, multiply lane wise, accumulate.
	x := [f32(0.5), 1.5, 2.5, 3.5]
	y := [f32(2), 4, 6, 8]
	mut dot := f32(0)
	for i := 0; i + 4 <= x.len; i += 4 {
		part := simd.load_f32x4(x[i..]) or { break }
		weight := simd.load_f32x4(y[i..]) or { break }
		dot += (part * weight).sum()
	}
	println('dot(x, y)           = ${dot}')
}
