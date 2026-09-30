#!/bin/sh
# check-lanes.sh runs the suite once per lane this host can select and prints the
# lane each run actually used, so "every lane answers the same arithmetic" is a
# result rather than a claim. A run that asks for a lane and silently gets another
# one fails here.
#
#   tools/check-lanes.sh
#
# V is taken from $V when set (CI uses this to point at a specific build).

set -eu

V="${V:-v}"
PATHS="@vlib|@vmodules|."
WORK="${TMPDIR:-/tmp}/purev-check-lanes.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

run_lane() {
	label="$1"
	expected="$2"
	shift 2
	lane=$($V -path "$PATHS" "$@" run examples/demo.v | awk -F'= ' '/^lane/ { print $2; exit }')
	status="ok"
	if [ "$expected" != "any" ] && [ "$lane" != "$expected" ]; then
		status="WRONG LANE (wanted $expected)"
	fi
	if [ "$status" != "ok" ]; then
		printf '%-28s lane=%-8s %s\n' "$label" "$lane" "$status"
		exit 1
	fi
	# `v test .` needs no module path: the tests sit in the repo root next to the
	# `simd/` module directory, which is where V looks first. `-path` is only
	# needed for the example, which lives one directory down.
	$V "$@" test . >/dev/null
	printf '%-28s lane=%-8s tests ok\n' "$label" "$lane"
}

run_lane 'pure V (forced)' 'pure_v' -d simd_force_pure_v
run_lane 'host default' 'any'

if command -v gcc >/dev/null 2>&1; then
	run_lane 'gcc' 'any' -cc gcc
fi
if command -v clang >/dev/null 2>&1; then
	run_lane 'clang' 'any' -cc clang
fi

# The FMA lane executes VFMADD213PS, so it can only be run where the CPU has FMA3.
# Linux says so in /proc/cpuinfo; elsewhere this check is skipped rather than
# guessing.
if command -v gcc >/dev/null 2>&1 && [ -r /proc/cpuinfo ] && grep -qw fma /proc/cpuinfo; then
	run_lane 'gcc, -d simd_addon_fma' 'fma' -cc gcc -d simd_addon_fma
fi

# The addon gates are supposed to fail loudly, not fall back quietly.
#
# The assertion is the gate's own message, not just a non-zero exit: a `-cc tcc`
# where tcc is not installed also exits non-zero, and a check that cannot tell
# those apart passes on a machine that never ran the gate. The plain build first
# answers whether tcc is usable here at all.
if $V -cc tcc -o "$WORK/tcc_probe" examples/demo.v >/dev/null 2>&1; then
	if gate_out=$($V -d simd_addon_fma -cc tcc -o "$WORK/tcc_gate" examples/demo.v 2>&1); then
		echo 'tcc accepted -d simd_addon_fma: the addon gate is not firing'
		exit 1
	fi
	case "$gate_out" in
		*simd_addon_fma*)
			printf '%-28s %s\n' 'addon gate (tcc)' "rejected: $(printf '%s\n' "$gate_out" | grep -m1 'simd:')"
			;;
		*)
			echo 'the addon build under tcc failed, but not with the gate:'
			printf '%s\n' "$gate_out" | head -3
			exit 1
			;;
	esac
else
	echo 'addon gate (tcc): skipped, no usable tcc here'
fi
