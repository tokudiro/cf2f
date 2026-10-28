# cf2f

[English](README.md)

C言語の関数呼び出しツリーを生成します。

cf2f はC言語のソースコードを解析し、関数の呼び出し関係を表す部分的な dot 形式のテキスト(Graphviz 用)を出力します。C プログラムの関数呼び出しツリーを可視化するのに役立ちます。

## ビルド
```
sudo apt install flex
sudo apt install graphviz
make
```

## 出力例
次のような C ソースコード (hoge.c) があるとします。

```C
void foo() { bar(); }
void bar() { baz(); }
void baz() {}
```

cf2f を実行します。

```sh
echo digraph{ > hoge.dot
cf2f hoge.c | sort | uniq >> hoge.dot
echo } >> hoge.dot
fdp -Tpng -ohoge.png hoge.dot
```

出力は次のようになります。

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

## cf2dot

`bin/cf2dot` は、上の手順(cf2f の実行、重複行の除去、`digraph{` と `}` の追加)をまとめたシェルスクリプトです。

```sh
bin/cf2dot hoge.c > hoge.dot
bin/cf2dot -x stdc -x posix a.c b.c > all.dot    # 標準関数と POSIX の関数を除外
cat a.c b.c | bin/cf2dot -T svg > all.svg        # 標準入力から読み、dot を通す
```

- `-x 一覧`: 一覧にある関数の呼び出しを除外します(`stdc`、`posix`、または自分の一覧のパス。[関数を除外する](#関数を除外する) を参照)。繰り返せます。
- `-T 形式`: 結果を Graphviz の `dot -T 形式` に通します。

## その他のツール

`make` で3つのツールがビルドされます。いずれも第1引数の C ソースファイル(省略時は標準入力)を読み、結果を標準出力に出力します。ファイルを開けない場合は標準エラー出力にメッセージを出し、終了コード 1 で終わります。

| ツール | 出力 |
|---|---|
| `cf2f` | 関数の呼び出し関係 (`"呼び出し元()" -> "呼び出し先()"`) |
| `funclist` | 関数名の一覧 |
| `cf2v` | 各関数内で使われている局所外の変数 (`"関数()" -> "変数名"`) |

### cf2v

cf2v は、関数の中で使われているが、その関数の中で宣言されていない変数(引数でも局所変数でもないもの)を出力します。グローバル変数など、関数の外で定義されたものです。

```C
int counter;
void foo(int a) { int b = a + counter; bar(); }
void bar() {}
```

`cf2v hoge.c` の出力は次のとおりです。

```
	"foo()" -> "counter"
	"foo()"[color=red];
	"bar()"[color=red];
```

読むのはソースファイルだけなので、「関数の中に宣言が見つからない」ことだけを根拠に局所外と判断します。そのため、マクロ、enum の定数、ヘッダの変数は区別されません。すべて大文字の名前はマクロとみなして出力せず、`.` や `->` の後ろのメンバ名も出力しません。呼び出しなしで渡した関数名(`qsort(a, n, s, cmp)` の `cmp`)は、変数として出力されます。

cf2f と同様に出力は部分的な dot 形式なので、上の例のように `digraph{` と `}` で囲んでください。

## 関数を除外する

cf2f に除外のオプションはありません。`sort | uniq` と同じように、出力を `grep -v -F -f` で絞り込みます。

```sh
cf2f hoge.c | grep -v -F -f exclude/stdc.txt | sort | uniq
```

複数の一覧は、`-f` を繰り返して組み合わせられます。

```sh
cf2f hoge.c | grep -v -F -f exclude/stdc.txt -f exclude/posix.txt | sort | uniq
```

[exclude/stdc.txt](exclude/stdc.txt) は C 標準ライブラリの関数(`printf`、`malloc`、`strlen` など)を、[exclude/posix.txt](exclude/posix.txt) はそれ以外の POSIX の関数(`open`、`read`、`socket`、`pthread_*` など)を、`-> "名前()"` の形で並べたものです。呼び出し先として出てくる行だけが消えます。コピーして、自分の関数を足したり、残したいものを消したりして使ってください。一覧にある名前と同じ名前の自作関数も、除外されます。
