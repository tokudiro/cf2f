# cf2f
c-language function call-tree

## useage

echo graph{ > hoge.dot
cf2f hoge.c | sort | uniq >> hoge.dot
echo } >> hoge.dot

dot -Tpng -ohoge.png hoge.dot
