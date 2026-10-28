#!/bin/sh
# Usage: diff/cflow.sh [-v] file.c...
# Compares the call edges of cf2f with those of GNU cflow (-f dot), as sets.
# Prints one line per file:  cf2f-edges cflow-edges common only-cf2f only-cflow  file
# With -v, also lists the edges that appear on one side only.
# Needs ./cf2f built (make) and cflow installed.
cd "$(dirname "$0")/.." || exit 2
[ -x ./cf2f ] || { echo "cflow.sh: ./cf2f not built" >&2; exit 2; }
command -v cflow > /dev/null || { echo "cflow.sh: cflow not installed" >&2; exit 2; }
verbose=0
[ "$1" = "-v" ] && { verbose=1; shift; }
tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
for f in "$@"; do
    ./cf2f "$f" | sed -n 's/^\t"\(.*\)()" -> "\(.*\)()"$/\1 \2/p' | sort -u > "$tmp/cf2f"
    timeout 60 cflow -f dot "$f" 2> /dev/null \
        | sed -n 's/^ *\([A-Za-z_][A-Za-z_0-9]*\) -> \([A-Za-z_][A-Za-z_0-9]*\).*$/\1 \2/p' | sort -u > "$tmp/cflow"
    echo "$(wc -l < "$tmp/cf2f") $(wc -l < "$tmp/cflow") $(comm -12 "$tmp/cf2f" "$tmp/cflow" | wc -l) $(comm -23 "$tmp/cf2f" "$tmp/cflow" | wc -l) $(comm -13 "$tmp/cf2f" "$tmp/cflow" | wc -l) $f"
    if [ $verbose = 1 ]; then
        comm -23 "$tmp/cf2f" "$tmp/cflow" | sed 's/^/  only cf2f:  /'
        comm -13 "$tmp/cf2f" "$tmp/cflow" | sed 's/^/  only cflow: /'
    fi
done
