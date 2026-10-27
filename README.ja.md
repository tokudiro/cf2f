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

## その他のツール

`make` で3つのツールがビルドされます。いずれも第1引数の C ソースファイルを読み、結果を標準出力に出力します。

| ツール | 出力 |
|---|---|
| `cf2f` | 関数の呼び出し関係 (`"呼び出し元()" -> "呼び出し先()"`) |
| `funclist` | 関数名の一覧 |
| `cf2v` | 各関数内で宣言された変数 (`"関数()" -> "型 変数名"`) |

### cf2v

上の hoge.c にローカル変数を加えた例です。

```C
void foo() { int b; bar(); }
void bar() {}
```

`cf2v hoge.c` の出力は次のとおりです。

```
	"foo()" -> "int b"
	"foo()"[color=red];
	"bar()"[color=red];
```

cf2f と同様に出力は部分的な dot 形式なので、上の例のように `digraph{` と `}` で囲んでください。
