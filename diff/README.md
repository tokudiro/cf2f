# diff/

Tools for comparing cf2f with other tools (see issue #6).

```sh
make
diff/cflow.sh [-v] file.c...
```

`cflow.sh` prints, per file: `cf2f-edges cflow-edges common only-cf2f only-cflow file`.
`-v` lists the edges found by only one side.

Known differences that are by design (see doc/spec.md):

- cflow also reports a function name passed as a value (`sort(a, n, cmp)`); cf2f reports calls only.
- cflow hides names starting with `_` unless run with `-i _`.
- Member calls (`p->fn()`) are reported by cf2f only (#12).
