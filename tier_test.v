module main

import math
import simd
import simd.backend

// Lane tests. The live lane is whatever the build selected, so these tests prove
// the same thing on every machine: the lane in use answers exactly what the pure
// V reference answers, and mul_add rounds the way its lane is allowed to.
//
// CI runs this file once per lane (`-cc gcc`, `-cc gcc -d simd_addon_fma`,
// `-d simd_force_pure_v`, and the cross builds), which is what turns "the lanes
// agree" from a claim into a result.

fn sample_pairs() [][3][4]f32 {
	return [
		[[f32(1), 2, 3, 4]!, [f32(10), 20, 30, 40]!, [f32(0), 0, 0, 0]!],
		[[f32(-1.5), 0.25, 1e10, -3.5]!, [f32(2), -8, 1e-10, 0.5]!, [f32(1), 1, 1, 1]!],
		[[f32(0), 0, 0, 0]!, [f32(1), 2, 4, 8]!, [f32(-1), -2, -4, -8]!],
	]
}

fn test_lane_arithmetic_matches_the_reference() {
	for triple in sample_pairs() {
		a := triple[0]
		b := triple[1]
		assert backend.add_f32x4(a, b) == backend.add_f32x4_pure_v(a, b)
		assert backend.sub_f32x4(a, b) == backend.sub_f32x4_pure_v(a, b)
		assert backend.mul_f32x4(a, b) == backend.mul_f32x4_pure_v(a, b)
		assert backend.div_f32x4(a, b) == backend.div_f32x4_pure_v(a, b)
		assert backend.sqrt_f32x4(a) == backend.sqrt_f32x4_pure_v(a)
	}
}

// sqrt of a negative lane and of zero lands outside what a lane-agnostic loop can
// compare with ==, so it is checked lane by lane instead.
fn test_lane_sqrt_handles_negative_and_zero_lanes() {
	a := [f32(0), -0.0, -1, 4]!
	got := backend.sqrt_f32x4(a)
	reference := backend.sqrt_f32x4_pure_v(a)
	for i in 0 .. 4 {
		assert math.is_nan(f64(got[i])) == math.is_nan(f64(reference[i]))
		if !math.is_nan(f64(got[i])) {
			assert got[i] == reference[i]
		}
	}
}

// mul_add is the one operation whose result is lane dependent, so this test says
// what each lane is allowed to produce instead of pretending they are equal.
// Lane 0 is the useful one: x = 1 + 2^-23 with an addend of -(1 + 2^-22) makes
// the two roundings differ (2^-46 fused, 0 split). Both expectations are built
// here in f64, where the product of two f32 lanes is exact, so the test does not
// depend on what the compiler did to the reference kernel.
fn test_mul_add_rounds_the_way_its_lane_allows() {
	x := f32(1.0) + f32(math.pow(2, -23))
	cancel := -f32(1.0) - f32(math.pow(2, -22))
	v := [x, 1, 3, 7]!
	m := [x, 2, 0.5, 1]!
	a := [cancel, 0, 0, 1]!
	mut split := [4]f32{}
	mut fused := [4]f32{}
	for i in 0 .. 4 {
		product := f64(v[i]) * f64(m[i])
		split[i] = f32(f64(f32(product)) + f64(a[i])) // rounds the product first
		fused[i] = f32(product + f64(a[i])) // rounds once, at the end
	}
	assert split[0] != fused[0]
	got := backend.mul_add_f32x4(v, m, a)
	reference := backend.mul_add_f32x4_pure_v(v, m, a)
	for i in 0 .. 4 {
		assert reference[i] == split[i] || reference[i] == fused[i]
	}
	match simd.lane_name() {
		'fma', 'neon' {
			// A fused lane must round once.
			assert got == fused
		}
		else {
			// A split lane may produce either, because a C compiler is allowed to
			// contract v * m + a into an FMA. Anything else is a lane bug.
			for i in 0 .. 4 {
				assert got[i] == split[i] || got[i] == fused[i]
			}
		}
	}
}

// The samples above are the shapes a reviewer thinks of. This is the version the
// implementation does not get a vote on: awkward magnitudes crossed with each
// other, then a reproducible sequence of pairs, all four arithmetic operations
// plus sqrt, lane against reference. The sequence comes from a linear congruential
// generator rather than a random source, so the run is the same on every machine
// and a disagreement can be reproduced from the seed.
fn test_lane_arithmetic_matches_the_reference_over_a_sweep() {
	awkward := [f32(0), -0.0, 1.0, -1.0, 1e-38, 1.1754944e-38, 5.8774718e-39, 3.4028235e38, 0.1,
		1.0 / 3.0, 16777216.0, 1e38]
	for x in awkward {
		for y in awkward {
			a := [x, x, -x, -x]!
			b := [y, -y, y, -y]!
			assert backend.add_f32x4(a, b) == backend.add_f32x4_pure_v(a, b)
			assert backend.sub_f32x4(a, b) == backend.sub_f32x4_pure_v(a, b)
			assert backend.mul_f32x4(a, b) == backend.mul_f32x4_pure_v(a, b)
			if y != 0.0 {
				assert backend.div_f32x4(a, b) == backend.div_f32x4_pure_v(a, b)
			}
		}
		if x >= 0.0 {
			assert backend.sqrt_f32x4([x, x, x, x]!) == backend.sqrt_f32x4_pure_v([x, x, x, x]!)
		}
	}

	mut s := u32(12345)
	for _ in 0 .. 20_000 {
		s = s * 1664525 + 1013904223
		x := f32(f64(s >> 8) / 16777216.0)
		s = s * 1664525 + 1013904223
		y := f32(f64(s >> 8) / 16777216.0) + 0.5
		a := [x, x, -x, -x]!
		b := [y, -y, y, -y]!
		assert backend.add_f32x4(a, b) == backend.add_f32x4_pure_v(a, b)
		assert backend.sub_f32x4(a, b) == backend.sub_f32x4_pure_v(a, b)
		assert backend.mul_f32x4(a, b) == backend.mul_f32x4_pure_v(a, b)
		assert backend.div_f32x4(a, b) == backend.div_f32x4_pure_v(a, b)
		assert backend.sqrt_f32x4([x, x, x, x]!) == backend.sqrt_f32x4_pure_v([x, x, x, x]!)
	}
}

// The lane a build reports has to be the lane it runs, and the public entry
// points have to agree with the lane the backend reports.
fn test_reported_lane_matches_the_public_api() {
	a := simd.f32x4(1, 2, 3, 4)
	b := simd.f32x4(10, 20, 30, 40)
	assert (a + b).to_array() == backend.add_f32x4(a.to_array(), b.to_array())
	assert simd.lane() == backend.active_lane()
}
