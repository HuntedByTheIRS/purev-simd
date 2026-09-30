#!/bin/sh
# lib.sh holds what more than one check needs. It is sourced, not run.
#
# find_disassembler prints the name of a disassembler that can actually read the
# object it is given.
#
# This exists because the fallback is a trap. `objdump` from a binutils built for
# one target refuses a foreign object with `file format elf64-littleaarch64 not
# recognized` on stderr, exits non-zero, and prints nothing to stdout, which in a
# pipeline reads as "no instructions found" rather than as a missing tool. So ask
# each candidate to describe the object, and take the one that names aarch64.
#
# Pinning one name is the other half of the trap: this machine has
# `llvm-objdump-21` and no unversioned `llvm-objdump`, while a CI runner tends to
# have the unversioned one.
find_disassembler() {
	object="$1"
	for candidate in llvm-objdump llvm-objdump-22 llvm-objdump-21 llvm-objdump-20 \
		llvm-objdump-19 llvm-objdump-18 aarch64-linux-gnu-objdump objdump; do
		if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -f "$object" 2>/dev/null | grep -q aarch64; then
			printf '%s' "$candidate"
			return 0
		fi
	done
	return 1
}
