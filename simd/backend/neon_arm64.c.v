module backend

// AArch64 NEON kernels.
//
// NEON is mandatory on AArch64, so nothing here needs a CPU check. As on amd64,
// only pointers cross the function boundary, so the kernels do not depend on how
// a platform passes vector arguments.
//
// The arithmetic is written as raw instruction words rather than mnemonics. A
// NEON vector instruction needs its arrangement suffix (`fadd v0.4s, v0.4s,
// v1.4s`), and V lexes `v0.4s` as the number `0.4` followed by a stray digit, so
// the mnemonic cannot be written in a V assembly block at all — see docs/
// backends.md. `.inst` takes the encoding, and the mnemonic sits in the comment
// above it; the encodings are checked against the assembler in
// tools/check-neon-encodings.sh. Loads and stores need no suffix, so those stay
// readable.
//
// NEON has a fused multiply-add (FMLA), so the neon lane needs no addon to round
// once: unlike x86-64, where fusing is opt-in, `-d simd_addon_fma` here would be
// a build error.

$if lane == 'neon' {
	// add_f32x4_neon adds corresponding lanes.
	pub fn add_f32x4_neon(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [a]
			ldr q1, [b]
			.inst 0x4e21d400 // fadd v0.4s, v0.4s, v1.4s
			str q0, [out]
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// sub_f32x4_neon subtracts corresponding lanes.
	pub fn sub_f32x4_neon(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [a]
			ldr q1, [b]
			.inst 0x4ea1d400 // fsub v0.4s, v0.4s, v1.4s
			str q0, [out]
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// mul_f32x4_neon multiplies corresponding lanes.
	pub fn mul_f32x4_neon(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [a]
			ldr q1, [b]
			.inst 0x6e21dc00 // fmul v0.4s, v0.4s, v1.4s
			str q0, [out]
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// div_f32x4_neon divides corresponding lanes.
	pub fn div_f32x4_neon(a [4]f32, b [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [a]
			ldr q1, [b]
			.inst 0x6e21fc00 // fdiv v0.4s, v0.4s, v1.4s
			str q0, [out]
			; ; r (a) r (b) r (out)
			; memory
		}
		return out
	}

	// sqrt_f32x4_neon returns the square root of each lane.
	pub fn sqrt_f32x4_neon(a [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [a]
			.inst 0x6ea1f800 // fsqrt v0.4s, v0.4s
			str q0, [out]
			; ; r (a) r (out)
			; memory
		}
		return out
	}

	// mul_add_f32x4_neon returns v * multiplier + addend for each lane, using FMLA
	// so the product is not rounded before the addition.
	pub fn mul_add_f32x4_neon(v [4]f32, multiplier [4]f32, addend [4]f32) [4]f32 {
		mut out := [4]f32{}
		asm volatile arm64 {
			ldr q0, [addend]
			ldr q1, [v]
			ldr q2, [multiplier]
			.inst 0x4e22cc20 // fmla v0.4s, v1.4s, v2.4s
			str q0, [out]
			; ; r (v) r (multiplier) r (addend) r (out)
			; memory
		}
		return out
	}
}
