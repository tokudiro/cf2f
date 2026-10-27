#!/bin/sh
# Usage: tests/run.sh <tool>   (e.g. tests/run.sh cf2v)
# Compares "<tool> case.c" with case.out for each case in tests/<tool>/.
# Cases in tests/<tool>/xfail/ are known issues: a failure is reported as XFAIL
# and does not fail the run; a pass is reported as XPASS and does.
cd "$(dirname "$0")/.." || exit 2
tool=$1
[ -x "./$tool" ] || { echo "run.sh: ./$tool not built" >&2; exit 2; }
pass=0; fail=0; xfail=0; xpass=0
for c in tests/$tool/*.c tests/$tool/xfail/*.c; do
    [ -e "$c" ] || continue
    if "./$tool" "$c" | diff -u "${c%.c}.out" - > /dev/null; then ok=1; else ok=0; fi
    case $c in
        */xfail/*)
            if [ $ok = 1 ]; then echo "XPASS $c"; xpass=$((xpass+1)); else echo "XFAIL $c"; xfail=$((xfail+1)); fi ;;
        *)
            if [ $ok = 1 ]; then echo "PASS  $c"; pass=$((pass+1));
            else echo "FAIL  $c"; "./$tool" "$c" | diff -u "${c%.c}.out" - ; fail=$((fail+1)); fi ;;
    esac
done
echo "$pass passed, $fail failed, $xfail expected failures, $xpass unexpected passes"
[ $fail = 0 ] && [ $xpass = 0 ]
