#!/bin/sh
# check-neon-encodings.sh compares the raw instruction words in
# simd/backend/neon_arm64.c.v against what the assembler produces for the same
# mnemonics. The V lexer cannot spell a NEON arrangement suffix (`v0.4s` reads as
# the number 0.4), so those kernels are written as `.inst` words with the mnemonic
# in a comment, and this script is what keeps the words and the comments honest.
#
#   tools/check-neon-encodings.sh
#
# Needs an AArch64 assembler (zig, aarch64-linux-gnu-gcc or clang) and a
# disassembler that can read the result. A missing tool skips the check with a
# printed reason; a mismatch fails.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/simd/backend/neon_arm64.c.v"
MNEMONICS="$ROOT/tools/neon_kernels.s"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=tools/lib.sh
. "$ROOT/tools/lib.sh"

if command -v zig >/dev/null 2>&1; then
	zig cc -target aarch64-linux-gnu -c "$MNEMONICS" -o "$WORK/neon.o"
elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
	aarch64-linux-gnu-gcc -c "$MNEMONICS" -o "$WORK/neon.o"
elif command -v clang >/dev/null 2>&1; then
	clang --target=aarch64-linux-gnu -c "$MNEMONICS" -o "$WORK/neon.o"
else
	echo 'skipped: no AArch64 assembler (zig, aarch64-linux-gnu-gcc or clang)'
	exit 0
fi

if ! objdump_cmd=$(find_disassembler "$WORK/neon.o"); then
	echo 'skipped: no disassembler here reads aarch64 (a single-target binutils cannot)'
	exit 0
fi

assembled=$("$objdump_cmd" -d "$WORK/neon.o" | awk '/^ +[0-9a-f]+: [0-9a-f]+/ { print $2 }' | sort -u)
pasted=$(grep -o '\.inst 0x[0-9a-f]*' "$SOURCE" | sed 's/\.inst 0x//' | sort -u)

if [ "$assembled" = "$pasted" ]; then
	echo "NEON encodings match the assembler ($(printf '%s\n' "$assembled" | wc -l) words, $objdump_cmd)"
	exit 0
fi

echo "NEON encodings do not match the assembler ($objdump_cmd)"
echo 'assembler:'
printf '%s\n' "$assembled"
echo 'neon_arm64.c.v:'
printf '%s\n' "$pasted"
exit 1
