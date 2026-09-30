#!/bin/sh
# check-targets.sh builds the module for every target this host has a compiler
# for. A lane that only builds on the machine it was written on is not portable,
# and the only way to find out is to build somewhere else.
#
# Each check prints the lane the build selected. Where the target runs here the
# lane comes from the program itself; for a cross target it is read out of the
# generated source, because a native lane shows up there as its instructions and
# the pure V lane shows up as none.
#
#   tools/check-targets.sh
#
# Targets whose toolchain is missing are skipped with a printed reason, not
# silently dropped.

set -eu

V="${V:-v}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/build/targets}"
PATHS="$ROOT|@vlib|@vmodules"

mkdir -p "$OUT"
cd "$ROOT"

# shellcheck source=tools/lib.sh
. "$ROOT/tools/lib.sh"

want() {
	command -v "$1" >/dev/null 2>&1
}

# native_instructions counts the vector instructions a lane would have left in
# generated output: any at all means a native lane was selected.
native_instructions() {
	grep -c 'addps\|mulps\|sqrtps\|\.inst 0x' "$1" 2>/dev/null || true
}

echo "host ($(uname -s)/$(uname -m))"
$V -path "$PATHS" run examples/demo.v | awk -F'= ' '/^lane/ { print "  lane: " $2 }'

if want x86_64-w64-mingw32-gcc; then
	echo 'windows/amd64 (mingw):'
	$V -os windows -cc x86_64-w64-mingw32-gcc -path "$PATHS" -o "$OUT/demo.exe" \
		examples/demo.v >/dev/null 2>&1
	file "$OUT/demo.exe" | sed 's/^/  /'
	$V -os windows -cc x86_64-w64-mingw32-gcc -o "$OUT/demo_windows.c" examples/demo.v >/dev/null 2>&1
	echo "  native instructions in the generated C: $(native_instructions "$OUT/demo_windows.c")"
else
	echo 'windows/amd64 (mingw): skipped, x86_64-w64-mingw32-gcc not found'
fi

if want zig; then
	echo 'linux/arm64 (zig cc, cross assembled):'
	# tier_test.v exercises all six kernels, so every NEON word the module can
	# emit shows up in the object.
	$V -os linux -arch arm64 -cc zig -o "$OUT/tier_arm64.c" tier_test.v >/dev/null 2>&1
	zig cc -target aarch64-linux-gnu -O2 -w -c "$OUT/tier_arm64.c" -o "$OUT/tier_arm64.o"
	if ! DUMP=$(find_disassembler "$OUT/tier_arm64.o"); then
		echo '  assembled, but skipped the readback: no disassembler here reads aarch64'
		echo "  the object is at $OUT/tier_arm64.o"
	else
		neon=$("$DUMP" -d "$OUT/tier_arm64.o" \
			| grep -E '^\s+[0-9a-f]+:\s+[0-9a-f]+\s+f(add|sub|mul|div|sqrt|mla)\s+v' \
			| sed 's/^ *[0-9a-f]*: *[0-9a-f]* *//' | sort -u)
		if [ -z "$neon" ]; then
			echo "  FAILED: the aarch64 object holds no NEON kernels, so the neon lane was not selected ($DUMP)"
			exit 1
		fi
		printf '%s\n' "$neon" | sed 's/^/  /'
	fi
else
	echo 'linux/arm64: skipped, zig not found'
fi

echo 'linux/arm32, wasm32, js (pure V lane by construction):'
for target in 'linux arm32 c' 'wasm32_emscripten wasm32 c'; do
	set -- $target
	os="$1"
	arch="$2"
	kind="$3"
	out="$OUT/fallback_${os}_${arch}.$kind"
	$V -os "$os" -arch "$arch" -o "$out" examples/demo.v >/dev/null 2>&1 || { echo "  $os/$arch: skipped, target unavailable"; continue; }
	echo "  $os/$arch: native instructions $([ "$(native_instructions "$out")" = '0' ] && echo 'none, pure V lane' || echo 'PRESENT, lane ladder is wrong')"
done
js_out="$OUT/fallback_js.js"
if $V -b js_node -o "$js_out" examples/demo.v >/dev/null 2>&1; then
	echo "  js backend: native instructions $([ "$(native_instructions "$js_out")" = '0' ] && echo 'none, pure V lane' || echo 'PRESENT, lane ladder is wrong')"
else
	echo '  js backend: skipped, backend unavailable'
fi

echo 'macos and freebsd (C generation only, no cross SDK on this host):'
for os in macos freebsd; do
	$V -os "$os" -arch amd64 -o "$OUT/demo_$os.c" examples/demo.v >/dev/null 2>&1
	echo "  $os/amd64: native instructions $(native_instructions "$OUT/demo_$os.c")"
done
