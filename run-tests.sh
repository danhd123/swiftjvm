#!/usr/bin/env bash
# run-tests.sh — compile stale tests and run them against the latest swiftjvm build.
#
# Usage:
#   ./run-tests.sh              # run all tests
#   ./run-tests.sh TypeOps      # run one test by class name (no extension)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/swiftjvm/Tests"

# ── locate the newest built binary ───────────────────────────────────────────
SWIFTJVM=$(ls -t ~/Library/Developer/Xcode/DerivedData/swiftjvm-*/Build/Products/Debug/swiftjvm 2>/dev/null | head -1 || true)
if [[ -z "${SWIFTJVM:-}" ]]; then
    echo "ERROR: swiftjvm binary not found in DerivedData." >&2
    echo "       Run: xcodebuild -scheme swiftjvm -configuration Debug build" >&2
    exit 1
fi

# ── colour helpers (disabled when stdout is not a tty) ───────────────────────
if [[ -t 1 ]]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    RESET=$'\033[0m'; BOLD=$'\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; RESET=''; BOLD=''
fi

FILTER="${1:-}"
pass=0
fail=0

# ── run_test <path/to/Foo.java> ───────────────────────────────────────────────
run_test() {
    local java_file="$1"
    local base
    base=$(basename "$java_file" .java)
    local class_file="${TESTS_DIR}/${base}.class"

    # Recompile if the .class is missing or older than the .java source.
    if [[ ! -f "$class_file" || "$java_file" -nt "$class_file" ]]; then
        printf "  %-28s%s[compiling]%s\n" "$base" "$YELLOW" "$RESET"
        local compile_out
        if ! compile_out=$(javac "$java_file" 2>&1); then
            printf "  %-28s%sCOMPILE FAIL%s\n" "$base" "$RED" "$RESET"
            printf '%s\n' "$compile_out" | sed 's/^/    /'
            fail=$((fail + 1))
            return
        fi
    fi

    # Run the interpreter; capture stdout+stderr, preserve exit code.
    local output exit_code
    output=$("$SWIFTJVM" "$class_file" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local last_line
        last_line=$(printf '%s' "$output" | tail -1)
        printf "  %-28s%sPASS%s  %s\n" "$base" "$GREEN" "$RESET" "$last_line"
        pass=$((pass + 1))
    else
        printf "  %-28s%sFAIL%s  (exit %d)\n" "$base" "$RED" "$RESET" "$exit_code"
        printf '%s\n' "$output" | sed 's/^/    /'
        fail=$((fail + 1))
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────
printf "%sswiftjvm test harness%s\n" "$BOLD" "$RESET"
echo "  binary : $SWIFTJVM"
echo "  tests  : $TESTS_DIR"
[[ -n "$FILTER" ]] && echo "  filter : $FILTER"
echo ""

cd "$SCRIPT_DIR"

found=0
for java_file in "$TESTS_DIR"/*.java; do
    [[ -f "$java_file" ]] || continue
    base=$(basename "$java_file" .java)
    if [[ -n "$FILTER" && "$base" != "$FILTER" ]]; then
        continue
    fi
    found=$((found + 1))
    run_test "$java_file"
done

if [[ $found -eq 0 ]]; then
    printf "%sERROR: no test found matching '%s'%s\n" "$RED" "$FILTER" "$RESET" >&2
    exit 1
fi

echo ""
echo "────────────────────────────────────"
printf "  %sPassed%s : %d\n" "$GREEN" "$RESET" "$pass"
if [[ $fail -gt 0 ]]; then
    printf "  %sFailed%s : %d\n" "$RED" "$RESET" "$fail"
else
    printf "  Failed : 0\n"
fi
echo ""

[[ $fail -eq 0 ]]
