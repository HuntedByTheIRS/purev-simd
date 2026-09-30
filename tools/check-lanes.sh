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
if $V -d simd_addon_fma -cc tcc -o /dev/null examples/demo.v >/dev/null 2>&1; then
	echo 'tcc accepted -d simd_addon_fma: the addon gate is not firing'
	exit 1
fi
printf '%-28s lane=%-8s rejected with tcc\n' 'addon gate (tcc)' 'n/a'
