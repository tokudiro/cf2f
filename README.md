# cf2f
c-language function call-tree

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

