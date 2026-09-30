module main

import simd
import simd.backend
import time

// A lane against a lane. Both loops do the same amount of work, so the ratio says
// what the selected lane is worth on this machine. Run it with the lane you care
// about:
//
//	v -path . run bench/f32x4_bench.v
//	v -path . -cc gcc run bench/f32x4_bench.v
//	v -path . -cc gcc -d simd_addon_fma run bench/f32x4_bench.v
//
// The numbers are a smoke signal, not a benchmark suite: a pass the optimiser
// cannot remove, no warm-up policy, and no measurements across machines.
const iterations = 4_000_000

fn measure_lane(a [4]f32, b [4]f32) f32 {
	mut acc := a
	for _ in 0 .. iterations {
		acc = backend.add_f32x4(backend.mul_f32x4(acc, b), b)
	}
	return acc[0]
}

fn measure_reference(a [4]f32, b [4]f32) f32 {
	mut acc := a
	for _ in 0 .. iterations {
		acc = backend.add_f32x4_pure_v(backend.mul_f32x4_pure_v(acc, b), b)
	}
	return acc[0]
}

fn main() {
	a := simd.f32x4(1.1, 2.2, 3.3, 4.4).to_array()
	b := simd.broadcast_f32x4(1.000001).to_array()
	println('lane: ${simd.lane_name()}, ${iterations} iterations of add(mul(acc, b), b)')

	start := time.sys_mono_now()
	lane_checksum := measure_lane(a, b)
	lane_ns := time.sys_mono_now() - start

	start = time.sys_mono_now()
	reference_checksum := measure_reference(a, b)
	reference_ns := time.sys_mono_now() - start

	println('lane      : ${f64(lane_ns) / f64(iterations) * 1000.0:.2f} ns/op (checksum ${lane_checksum:e})')
	println('reference : ${f64(reference_ns) / f64(iterations) * 1000.0:.2f} ns/op (checksum ${reference_checksum:e})')
	if reference_ns > 0 {
		println('ratio     : ${f64(reference_ns) / f64(lane_ns):.2f}x (reference / lane)')
	}
}
