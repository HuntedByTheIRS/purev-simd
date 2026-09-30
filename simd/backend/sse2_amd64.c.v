module backend

// x86-64 SSE2 kernels.
//
// The file name gates this file to amd64 targets and to the C backend; the lane
// gate keeps it out of builds that run on the pure V lane, where the assembler
// would either refuse the instructions (tcc, MSVC) or never be reached.
//
// SSE2 is part of the x86-64 baseline, so these kernels need no CPU check. Each
// kernel passes plain pointers in general purpose registers and does the vector
// work in xmm registers, which keeps the calling convention identical on System
// V (Linux, macOS, BSD) and on Windows x64: no vector arrives or leaves as an
// argument.

$if lane == 'sse2' || lane == 'fma' {
	// add_f32x4_sse2 adds corresponding lanes.
	pub fn add_f32x4_sse2(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [a]
			movups xmm1, [b]
			addps xmm0, xmm1
			movups [out], xmm0
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// sub_f32x4_sse2 subtracts corresponding lanes.
	pub fn sub_f32x4_sse2(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [a]
			movups xmm1, [b]
			subps xmm0, xmm1
			movups [out], xmm0
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// mul_f32x4_sse2 multiplies corresponding lanes.
	pub fn mul_f32x4_sse2(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [a]
			movups xmm1, [b]
			mulps xmm0, xmm1
			movups [out], xmm0
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// div_f32x4_sse2 divides corresponding lanes.
	pub fn div_f32x4_sse2(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [a]
			movups xmm1, [b]
			divps xmm0, xmm1
			movups [out], xmm0
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// sqrt_f32x4_sse2 returns the square root of each lane.
	pub fn sqrt_f32x4_sse2(a [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [a]
			sqrtps xmm0, xmm0
			movups [out], xmm0
			; ; r (a) r (out)
			; memory
		}
		return out
	}

	// mul_add_f32x4_sse2 returns v * multiplier + addend for each lane. SSE2 has
	// no fused multiply-add, so this rounds twice; `-d simd_addon_fma` is the way
	// to get a single rounding on x86-64.
	pub fn mul_add_f32x4_sse2(v [4]f32, multiplier [4]f32, addend [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [v]
			movups xmm1, [multiplier]
			mulps xmm0, xmm1
			movups xmm1, [addend]
			addps xmm0, xmm1
			movups [out], xmm0
			; ; r (v) r (multiplier) r (addend) r (out)
			; memory
		}
		return out
	}
}
