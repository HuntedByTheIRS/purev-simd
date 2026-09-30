module backend

// The FMA addon: one fused multiply-add kernel for the amd64 fma lane.
//
// `-d simd_addon_fma` selects this lane. It changes one operation and one
// observable: mul_add rounds once instead of twice. That is worth a lane of its
// own, and it is the shape every later addon takes, because a wider register is
// only worth a lane once there is a type wide enough to fill it. See
// docs/backends.md for where the 256-bit and 512-bit addons go.

$if lane == 'fma' {
	// mul_add_f32x4_fma returns v * multiplier + addend for each lane, using
	// VFMADD213PS so the product is not rounded before the addition.
	pub fn mul_add_f32x4_fma(v [4]f32, multiplier [4]f32, addend [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile amd64 {
			movups xmm0, [v]
			movups xmm1, [multiplier]
			movups xmm2, [addend]
			vfmadd213ps xmm0, xmm1, xmm2
			movups [out], xmm0
			; ; r (v) r (multiplier) r (addend) r (out)
			; memory
		}
		return out
	}
}
