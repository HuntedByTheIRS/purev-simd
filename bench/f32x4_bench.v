module main

import simd
import simd.backend
import time

// A lane against a lane. Both loops do the same amount of work, so the ratio says
// what the selected lane is worth on this machine. Run it with the lane you care
// about:
//
//	v -path "@vlib|@vmodules|." run bench/f32x4_bench.v
//	v -path "@vlib|@vmodules|." -cc gcc run bench/f32x4_bench.v
//	v -path "@vlib|@vmodules|." -cc gcc -d simd_addon_fma run bench/f32x4_bench.v
//
// The numbers are a smoke signal, not a benchmark suite: a pass the optimiser
// cannot remove, no warm-up policy, and no measurements across machines.
//
// Read the ratio with the call in mind. A native kernel is a function call with
// a `memory` clobber per operation, so the accumulator leaves the register file
// every iteration, and the scalar loop it is compared against is free to keep
// everything in registers. The comparison says what an operation costs end to
// end, not what one instruction costs.
const iterations = 4_000_000

fn measure_lane(mut a [4]f32, b [4]f32) f32 {
	for _ in 0 .. iterations {
		a = backend.add_f32x4(backend.mul_f32x4(a, b), b)
	}
	return a[0]
}

fn measure_reference(mut a [4]f32, b [4]f32) f32 {
	for _ in 0 .. iterations {
		a = backend.add_f32x4_pure_v(backend.mul_f32x4_pure_v(a, b), b)
	}
	return a[0]
}

fn main() {
	a := simd.f32x4(1.1, 2.2, 3.3, 4.4)
	mut seed := a.to_array()
	b := simd.broadcast_f32x4(1.000001).to_array()
	println('lane: ${simd.lane_name()}, ${iterations} iterations of add(mul(acc, b), b)')

	mut start := time.sys_mono_now()
	lane_checksum := measure_lane(mut seed, b)
	lane_ns := time.sys_mono_now() - start

	seed = a.to_array()
	start = time.sys_mono_now()
	reference_checksum := measure_reference(mut seed, b)
	reference_ns := time.sys_mono_now() - start

	println('lane      : ${f64(lane_ns) / f64(iterations) * 1000.0:.2f} ns/op (checksum ${lane_checksum:e})')
	println('reference : ${f64(reference_ns) / f64(iterations) * 1000.0:.2f} ns/op (checksum ${reference_checksum:e})')
	if reference_ns > 0 {
		println('ratio     : ${f64(reference_ns) / f64(lane_ns):.2f}x (reference / lane)')
	}
}
