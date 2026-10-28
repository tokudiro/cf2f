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
| `cf2v` | variables declared in each function (`"func()" -> "type name"`) |

### cf2v

For the same hoge.c as above with a local variable added:

```C
void foo() { int b; bar(); }
void bar() {}
```

`cf2v hoge.c` prints:

```
	"foo()" -> "int b"
	"foo()"[color=red];
	"bar()"[color=red];
```

Like cf2f, the output is a partial dot-format text, so wrap it with `digraph{` and `}` as shown above.
