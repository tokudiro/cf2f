# cf2f

[日本語](README.ja.md)
Generate function call-tree for C-language.

cf2f analyzes C source code and generates a partial dot-format text (for Graphviz) representing function call relationships.
This helps you visualize function call trees in your C programs.

## build
```
sudo apt install flex
sudo apt install graphviz
make
```

## example output
Suppose you have the following C source code (hoge.c):

```C
void foo() { bar(); }
void bar() { baz(); }
void baz() {}
```

If you run cf2f:

```sh
echo digraph{ > hoge.dot
cf2f hoge.c | sort | uniq >> hoge.dot
echo } >> hoge.dot
fdp -Tpng -ohoge.png hoge.dot
```

The output will look like:

hoge.dot
```
digraph{
"bar()" -> "baz()"
  "bar()"[color=red];
  "baz()"[color=red];
  "foo()" -> "bar()"
  "foo()"[color=red];
}
```

<img width="184" height="173" alt="hoge" src="https://github.com/user-attachments/assets/fc9537f6-b479-4241-9331-22d912b2a0d4" />

## other tools

`make` builds three tools. All of them read a C source file given as the first argument (standard input if omitted) and print the result to stdout. If the file cannot be opened, they print an error to stderr and exit with status 1.

| tool | output |
|---|---|
| `cf2f` | function call relationships (`"caller()" -> "callee()"`) |
| `funclist` | list of function names |
| `cf2v` | non-local variables used in each function (`"func()" -> "name"`) |

### cf2v

cf2v reports the variables a function uses that are not declared in it: neither its parameters nor its local variables. These are globals, or anything else defined outside the function.

```C
int counter;
void foo(int a) { int b = a + counter; bar(); }
void bar() {}
```

`cf2v hoge.c` prints:

```
	"foo()" -> "counter"
	"foo()"[color=red];
	"bar()"[color=red];
```

Only the source file is read, so a name is "non-local" simply because no declaration of it was found in the function. Macros, enum constants and variables from headers are therefore treated alike; names in ALL_CAPS are skipped as macros, and member names after `.` or `->` are not reported. A function name passed without a call (`qsort(a, n, s, cmp)`) is reported as a variable.

Like cf2f, the output is a partial dot-format text, so wrap it with `digraph{` and `}` as shown above.

## excluding functions

cf2f has no exclusion option. Filter its output with `grep -v -F -f`, as with `sort | uniq`:

```sh
cf2f hoge.c | grep -v -F -f exclude/stdc.txt | sort | uniq
```

Several lists can be combined by repeating `-f`:

```sh
cf2f hoge.c | grep -v -F -f exclude/stdc.txt -f exclude/posix.txt | sort | uniq
```

[exclude/stdc.txt](exclude/stdc.txt) lists the functions of the C standard library (`printf`, `malloc`, `strlen`, ...), and [exclude/posix.txt](exclude/posix.txt) those of POSIX that are not in it (`open`, `read`, `socket`, `pthread_*`, ...), as `-> "name()"` lines, so only calls to them are removed. Copy it and edit it to add your own functions or to remove ones you want to keep. A function of your own that has the same name as a listed one is excluded too.
