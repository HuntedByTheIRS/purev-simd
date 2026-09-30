// The mnemonics the NEON lane writes as raw words, in the order they appear in
// simd/backend/neon_arm64.c.v. This file is assembled for AArch64 by
// tools/check-neon-encodings.sh, which then compares the encodings with the
// `.inst` words in the kernel file.
	.text
	fadd v0.4s, v0.4s, v1.4s
	fsub v0.4s, v0.4s, v1.4s
	fmul v0.4s, v0.4s, v1.4s
	fdiv v0.4s, v0.4s, v1.4s
	fsqrt v0.4s, v0.4s
	fmla v0.4s, v1.4s, v2.4s
