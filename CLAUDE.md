# CLAUDE.md

TenKeysTyping — テンキー操作訓練用の macOS ネイティブアプリ（SwiftUI + Swift Package Manager）。

## ビルド

```bash
swift build -c release   # コンパイルのみ
./build.sh               # .app バンドルまで生成
./build.sh --run         # 生成して起動
./build.sh --install     # /Applications へ配置（sudo 不要）
./build.sh --out <dir>   # 任意のディレクトリへ配置
```

`swift run` は動くが、キーボードフォーカスやメニューの挙動はバンドル経由のほうが安定する。
動作確認は `open -n ./TenKeysTyping.app --env TKT_AUTOSTART=sprint|standard|endurance|stats`。

## 設計の要点

- **打鍵そのものを訓練する**。暗算はさせない。画面の式を1文字ずつ照合し、
  誤ったキーは入力に反映せずミスとして数える（`GameEngine.handle`）。
- **難易度＝プレイ時間**。`GameMode.levels` が各モードのレベル表で、
  経過割合から `GameMode.level(atProgress:)` で現在レベルを決める。
  難易度調整はこの表だけを触れば済むようにしてある。
- **キー入力は `NSEvent.addLocalMonitorForEvents`** で拾う（`GameView.installMonitor`）。
  first responder に依存せず、消費したイベントは `nil` を返してビープを抑止する。
  keyCode → 文字の対応は `KeyMapper`。テンキーとメインキーボードを区別する。
- **効果音はファイルを持たない**。`Synth` で波形を合成し、`SoundEngine` が
  AVAudioPlayerNode 8本のプールへラウンドロビンで流す。正解音はコンボ段階で音程が上がる。
- **アイコンは SVG から生成する**。`Resources/icon/source.svg` を `compose.py` が
  1024px の角丸スクエア（スーパー楕円 n=5、Apple のアイコングリッド 824/1024）へ
  合成し、`make-icon.sh` が QuickLook でラスタライズして `Resources/AppIcon.icns` を作る。
  ImageMagick の内蔵 SVG レンダラは品質が不安定なので使わない。
- **表示と打鍵対象を分離**。`Problem.display` は桁区切りや `×` `÷` などの表示専用要素を含み、
  `targetIndex` が nil の要素は打鍵対象ではない。色分けは AttributedString で行う。

## 変更時に併せて更新するもの

| 変えたもの | 更新先 |
| --- | --- |
| モード・レベル表・スコア式 | README.md のモード表と指標表 |
| キー割り当て | README.md のキー表、HomeView 下部のヒント文、NumpadGuide |
| 記録する指標（SessionRecord） | ResultView のタイル、StatsView のグラフ・一覧、README |
| 保存形式 | `HistoryStore`（旧 JSON の読み込み互換に注意） |
| アイコン・元イラスト | `Resources/icon/` を編集して `make-icon.sh` を再実行、README のアイコン節 |

記録ファイルは `~/Library/Application Support/TenKeysTyping/history.json`。
`SessionRecord` にフィールドを足すときは、既存 JSON がデコードできるよう
デフォルト値を持たせるか、デコード側で補うこと。
