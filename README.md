# TenKeysTyping

テンキー（数字キーパッド）操作に特化した macOS 用タイピングゲームです。
電卓を使う試験の練習用に、`123 + 456` のような四則演算の式をランダムに出題し、
**打鍵の正確さと速さ**を計測して上達をグラフで可視化します。

- SwiftUI / AppKit の macOS 標準 GUI
- 効果音はコード内で波形合成しているため、外部アセット不要
- 記録は `~/Library/Application Support/TenKeysTyping/history.json` に保存

## ビルドと起動

```bash
./build.sh              # リリースビルドして TenKeysTyping.app を生成
./build.sh --run        # ビルドして起動
./build.sh --install    # /Applications へインストール
./build.sh --out ~/Downloads   # 指定ディレクトリへ配置
open TenKeysTyping.app
```

必要環境: macOS 14 以降 / Xcode（Swift 5.10 以降のツールチェーン）。

`swift run` でも起動できますが、アプリバンドル経由（`./build.sh`）のほうが
メニューバーやキーボードフォーカスの挙動が安定します。

`/Applications` は管理者グループに書き込み権があるため、通常 `sudo` は不要です。
権限がない環境では `--out ~/Downloads` で書き出して手動でコピーしてください。

## アイコン

`Resources/icon/source.svg`（元イラスト）から `Resources/AppIcon.icns` を生成します。

```bash
./Resources/icon/make-icon.sh
```

`compose.py` が 1024×1024 の角丸スクエア（スーパー楕円）にイラストを配置した
`AppIcon.svg` を組み立て、QuickLook(WebKit) でラスタライズして `sips` / `iconutil` で
`.icns` にまとめます。イラストや配色を変えたらこのスクリプトを再実行してください
（`build.sh` は `.icns` が無いときだけ自動生成します）。

## 遊びかた

画面に出た式を **そのままテンキーで打ち、Enter で確定** します。
数字を暗算する必要はありません。電卓に打ち込む動作そのものを訓練します。

```
  12,345 + 678
  → 1 2 3 4 5 + 6 7 8 Enter
```

確定すると参考解（`= 13,023`）が一瞬表示されます。

### キー割り当て

| キー | 動作 |
| --- | --- |
| テンキー `0`〜`9` `+` `-` `*` `/` | 入力 |
| テンキー `Enter` / `=` / `return` | 確定 |
| `delete` | 1文字戻る |
| テンキー `clear` | 入力中の式を全消し |
| `esc` | 中断してモード選択に戻る |

**間違ったキーは入力に反映されません**（ミスとして記録され、音と振動でフィードバック）。
そのまま正しいキーを押せば続行できます。

設定の「テンキーのみ受け付ける」をオンにすると、メインキーボードの数字・記号キーを
無視します。テンキーから指を離さない訓練をしたいときに使います。

## モードと難易度

プレイ時間がそのまま難易度です。**プレイ中も時間経過に応じてレベルが上がり**、
桁数・項数・演算子の種類が段階的に増えていきます。

| モード | 時間 | レベル数 | 開始 | 最終 |
| --- | --- | --- | --- | --- |
| スプリント | 30秒 | 6 | 3桁 / 2項 / `+` | 5〜6桁 / 3項 / `+ − ×` |
| スタンダード | 60秒 | 8 | 3〜4桁 / 2項 / `+ −` | 6〜7桁 / 4項 / `+ − × ÷` |
| エンデュランス | 2分 | 10 | 4桁 / 2項 / `+ −` | 8〜9桁 / 5項 / `+ − × ÷` |

`×` `÷` の相手は 1〜3 桁に抑えています（電卓実務に近づけるため）。
参考解は `× ÷` を優先する通常の演算順序で計算しています。

レベル表は `Sources/TenKeysTyping/Models/GameMode.swift` の `levels` に定義されています。
難易度を変えたいときはここを編集してください。

## 記録される指標

| 指標 | 意味 |
| --- | --- |
| スコア | 打鍵数 × レベル × コンボ ＋ 速度ボーナス − ミス減点 |
| 問題正答率 | 正解した問題 ÷（正解＋途中確定） |
| キー正確率 | 正しい打鍵 ÷ 全打鍵 |
| KPM | 1分あたりの正打鍵数 |
| 平均解答時間 | 1問あたりの秒数 |
| 到達レベル / 最大コンボ | 到達した難易度と連続ノーミス数 |

「記録と上達グラフ」画面では、モード別に**キー正確率・KPM・平均解答時間**の推移を
折れ線と 5 回移動平均（破線）で表示します。結果画面には前回との差分も出ます。

## 開発

```
Sources/TenKeysTyping/
├── TenKeysTypingApp.swift   アプリ本体（@main）
├── Models/
│   ├── GameMode.swift       モードとレベル表（難易度定義）
│   ├── Problem.swift        出題の生成・表示モデル・評価
│   ├── GameEngine.swift     進行・判定・スコア
│   ├── KeyInput.swift       NSEvent → 入力へのマッピング
│   ├── SessionRecord.swift  1プレイ分の記録
│   └── HistoryStore.swift   JSON 永続化
├── Audio/
│   ├── Synth.swift          波形合成
│   └── SoundEngine.swift    効果音の設計と再生
└── Views/                   HomeView / GameView / ResultView / StatsView ほか
```

動作確認用に環境変数 `TKT_AUTOSTART` を用意しています。

```bash
open -n ./TenKeysTyping.app --env TKT_AUTOSTART=sprint   # 起動と同時にプレイ開始
open -n ./TenKeysTyping.app --env TKT_AUTOSTART=stats    # 記録画面を開く
```
