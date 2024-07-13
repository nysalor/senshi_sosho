# senshi_sosho

防衛省・防衛研究所が公開している戦史叢書(全104巻)の画像ファイルをダウンロードし、PDFを作成します。

ダウンロードしたファイルの利用にあたっては[防衛研究所のガイドライン](https://www.nids.mod.go.jp/utility/index.html)に従って下さい。

また、Webサイトをクローリングするため、過剰なアクセスは控えて下さい。

できるだけWebサーバに負荷をかけないようウェイトを入れてありますが、このプログラムを利用する際にはその動作について十分に理解しているものと考え、それによって発生した問題について作者は責任を負いかねます。

## 使い方

`ruby soshoget.rb get [巻番号/-a] [-v] [-p]`

### オプション

巻番号: 巻数を指定します。2024年7月時点で1巻から104巻まで公開されています。
-a: 全ての巻をダウンロードします。30秒の間隔を空けるため、全巻のダウンロードには1時間程度かかります。
-v: 詳細な途中経過を表示します。
-p: ダウンロードした画像を結合してPDFファイルを作成します。ファイル名は巻のタイトルになります。

出力先は `カレントディレクトリ/downloads/[巻番号]` 以下になります。
