# cf2f
Generate function call-tree for C-language.

cf2f analyzes C source code and generates a partial dot-format text (for Graphviz) representing function call relationships.
This helps you visualize function call trees in your C programs.

## build
```
sudo apt install flex
sudo apt install graphviz
make
```

## useage

```
echo digraph{ > hoge.dot
cf2f hoge.c | sort | uniq >> hoge.dot
echo } >> hoge.dot
fdp -Tpng -ohoge.png hoge.dot
```

