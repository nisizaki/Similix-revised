# Similix 5.0 使い方マニュアル(日本語版)

Similix-revised(現代 Chez Scheme 対応版)向けの日本語マニュアルです。
Chez Scheme 10.0.0(Linux aarch64)で全例題の動作を確認しています。

オリジナルの詳細な仕様は `manual.dvi`(英語)を参照してください。本書は、
現代環境で Similix を実際に使うための実践的な解説です。

---

## 目次

1. [Similixとは](#1-similixとは)
2. [動作環境とインストール](#2-動作環境とインストール)
3. [まず動かしてみる(getting-started 逐行解説)](#3-まず動かしてみる)
4. [コア概念:バインディングタイムとゴール呼び出し](#4-コア概念バインディングタイムとゴール呼び出し)
5. [APIリファレンス](#5-apiリファレンス)
6. [Similix入力言語(.sim ファイル)](#6-similix入力言語sim-ファイル)
7. [例題ツアー](#7-例題ツアー)
8. [Futamura射影の実演](#8-futamura射影の実演)
9. [実践的Tips](#9-実践的tips)
10. [トラブルシューティング](#10-トラブルシューティング)
11. [参考資料](#11-参考資料)

---

## 1. Similixとは

Similixは **部分評価器(partial evaluator / autoprojector)** です。Anders
Bondorf 氏(DIKU、コペンハーゲン大学)が1993年に公開した Similix 5.0 を
ベースにしています(Olivier Danvy、Jesper Jørgensen 両氏の貢献を含む)。

**部分評価(混合計算)** とは、プログラムの入力の一部(静的=static な入力)
が事前に分かっているとき、その情報を使ってプログラムを**特殊化**することです。
結果として得られる **残差プログラム(residual program)** は、残りの入力
(動的=dynamic な入力)だけを受け取り、高速に動作します。

例:`(append1 '(1 2 3) l2)` の `'(1 2 3)` を静的に与えて特殊化すると、

```scheme
(define (append1-0 l2_0) (cons 1 (cons 2 (cons 3 l2_0))))
```

という残差プログラムが得られます。元の再帰・`null?`/`car`/`cdr` の判定が
すべて特殊化時に実行済みになり、残差は3つの `cons` だけになりました。

Similixの特徴:

- **自動的**: unfolding(関数展開)情報などのユーザー注記は基本不要。
  バインディングタイム解析(BTA)が自動で行われます
  (ループを避けるための手動の「バインディングタイム改善」が有効な場合は
  あります。`manual.dvi` に定番テクニックの節があります)
- **安全な保証**: 計算が破棄されたり複製されたりしません
  (部分評価が停止性を保存します)
- **高階関数対応**: 環境を関数で表したインタプリタや、継続渡しスタイル
  (CPS)のインタプリタも特殊化できます
- **自己適用可能**: 部分評価器自身を部分評価できます。
  これにより **コンパイラを自動生成** できます(Futamura射影、後述)
- **部分静的データ構造(partially static data)** を扱えます
- 限られたクラスの副作用(入出力など)を扱えます

---

## 2. 動作環境とインストール

### 2.1 必要なもの

- Chez Scheme(動作確認: **10.0.0**。v9系以降で動くはずです)
- Similix-revised リポジトリ一式

Ubuntu系なら `sudo apt install chezscheme` で導入できます
(実行ファイル名は `chezscheme` または `scheme`)。

### 2.2 本revised版のポイント:ブートストラップ不要

オリジナル配布物では Chez 向けに `script1`(ファイルの `.scm`→`.ss` リネーム)
と `compile-file` によるコンパイルが必要でした。**Similix-revised では
すべて不要**です。`system/sim-chez.ss` がシステム全ファイルを
(`spec.sim`・`cogen.sim` を含め)ソースから直接ロードします。

技術的詳細(興味がある方向け):

- 1993年当時の Chez 3.2 は記号を読み込む際に**大文字小文字を区別しません
  でした**(小文字に折り畳み)。生成済みの `cogen.sim` は小文字、本体は
  `**Similix-library**` のように大文字混じりで、当時は同一視されていました。
  現代 Chez は既定で大文字小文字を区別するため、`sim-chez.ss` の
  **最初のフォーム**に `(case-sensitive #f)` を置いて歴史的挙動を復元しています
  (`load` は1フォームずつ読むので、この位置に置くことが重要です)
- それ以外の1993年ソース(`system/*.scm`、`examples/*.sim` 等)は**無修正**で動作します

### 2.3 起動

ジョブは**書き込み権限のあるディレクトリ**(通常は `examples/`)をカレント
ディレクトリにして起動します。Similix は作業用一時ファイル `_simtmp.scm`
をカレントディレクトリに作成・削除するためです。

```console
$ cd examples
$ chezscheme --quiet
> (load "../system/sim-chez.ss")

Welcome to Similix 5.0
Copyright (C) 1993 Anders Bondorf
Contributions by Olivier Danvy and Jesper Joergensen

util langext abssyn miscspec runtime front lam-lift bt-eod sp oc rl post spec
>
```

数秒で全システムがロードされ、REPLで使えるようになります。
`system/` ディレクトリをカレントにして `(load "sim-chez.ss")` してもOKです
(パスは自動判別)。

`examples/` 内のジョブファイルを使う場合は、最初のロード行を差し替えます。

```scheme
;; 元: (load "../system/sim-scm.scm")
(load "../system/sim-chez.ss")
```

なお、オリジナルREADMEにある `(load "../system/sim-chez.so")` という書き方は
(コンパイル済みオブジェクトを参照する旧方式なので)**使いません**。

---

## 3. まず動かしてみる

`examples/getting-started`(マニュアルの最初の例)を日本語で読み解きます。

```scheme
(load "../system/sim-chez.ss")     ; システムをロード

(load "append.sim")                ; 対象プログラム(普通のSchemeとして実行用)
(append1 '(1 2 3) '(4 5 6))        ; => (1 2 3 4 5 6)  (普通に実行)

; 部分評価:append1 の第1引数 '(1 2 3) を静的、第2引数を動的にして特殊化
(similix 'append1 (list '(1 2 3) '***) "append.sim")
;   "front-end flow bt sp eod oc rl"  (フロントエンド+各種解析の進行)
;   "specializing"                    (特殊化実行)
;   => 残差プログラムが値として返る:
;      ((define (append1-0 l2_0) (cons 1 (cons 2 (cons 3 l2_0)))))

(load-residual-program)            ; 残差をREPLに定義(append1-0 が使えるように)
(append1-0 '(4 5 6))               ; => (1 2 3 4 5 6)  (残差を実行)
(define target (residual-program)) ; 残差プログラム(データ)を保存

(pp (showpall))                    ; バインディングタイム注記付きの前処理済みプログラムを表示

; cogen(コンパイラ生成器)で「append1専用コンパイラ」を生成
(cogen 'append1 '(static dynamic) "append.sim")
;   "loading compiler generator"   (cogen.sim をロード)
;   "generating compiler"          (自己適用でコンパイラ生成)

; 生成されたコンパイラで '(1 2 3) を「コンパイル」
(comp (list '(1 2 3) '***))
;   "loading current compiler" "specializing"

(define new-target (residual-program))
(equal? target new-target)         ; => #t  (similixとcompが同じ残差を生成)
```

`similix` で直接特殊化した結果と、`cogen`+`comp`(コンパイラ経由)の結果が
**完全に一致する(#t)** のが、この例の成功基準です。

---

## 4. コア概念:バインディングタイムとゴール呼び出し

### 4.1 静的と動的

- **静的(static, s)**: 特殊化の時点で値が分かっている入力。特殊化中に
  計算に使われ、残差には現れません
- **動的(dynamic, d)**: 実行時にしか分からない入力。残差プログラムの
  パラメータとして残ります

### 4.2 ゴール呼び出し(arg-pat)の書き方

`similix` や `comp` に渡す「ゴール呼び出し」リストで、**各引数を値そのもの
で書くと静的**、**`'***` を書くと動的**になります。動的マーカーは `***`
(3つの星)だけです。**`*` や `**` に特別な意味はありません**(普通のシンボル
として静的な値になります。実験済み:

```scheme
(similix 'append1 (list '(1 2 3) '**) "append.sim")
;; => ((define (append1-0) '(1 2 3 . **)))   ; l2 は静的な値「シンボル **」!
```

正しくは:

```scheme
(similix 'append1 (list '(1 2 3) '*) ...)  ; ✗ 誤り(静的になる)
(similix 'append1 (list '(1 2 3) '**) ...) ; ✗ 誤り(静的になる)
(similix 'append1 (list '(1 2 3) '***))    ; ✓ 正しい(第2引数が動的)
```

対象プログラム自体に `***` というデータが現れる場合は、衝突を避けるため
`(set-dynamic-input-symbol sym)` でマーカーを変更できます。

### 4.3 bt-pat(s/d 表記)

`cogen` や `preprocess!` では、ゴール手続きの仮引数ごとに `s`/`d` の
シンボルでバインディングタイムを指定します。

```scheme
(cogen 'run '(s d) "MP-int.sim")    ; 第1引数=静的、第2引数=動的
(cogen '_P '(s s d) "com-int.sim")  ; 3引数のうち前2つが静的
```

`'(static dynamic)` のようにスペルを書いても構いません(`'s`/`'d` との
混在も可)。bt-pat中では `'d` と `'***` が動的を意味します。

### 4.4 残差プログラムの命名

残差のゴール手続き名は自動的に `<元の名前>-0` のようになります
(連番カウンタは `reset-similix` でリセット)。`similix` のオプション引数
`residual-goal` で名前を指定することもできます。

---

## 5. APIリファレンス

REPLで `(help)` を実行すると一覧が表示されます。以下は主要なものの解説です。

### 部分評価・コンパイル

| API | 説明 |
|---|---|
| `(similix goal arg-pat source-sim-file [n] [residual-goal] [residual-file ['pp]])` | プログラムを特殊化し、残差を値として返す |
| `(similix goal-call prep-pgm [n] [residual-goal] [residual-file ['pp]])` | 前処理済みプログラム(`preprocess!` 済み)を直接指定する形式。`goal-call` は `'(手続き名 引数...)` 形式 |
| `(similix [n] [residual-goal] [residual-file ['pp]])` | 直前に `preprocess!` したプログラムで特殊化 |
| `(cogen goal bt-pat source-sim-file [n] [cmp-goal] [cmp-file ['pp]])` | コンパイラを生成(`current-compiler` に格納) |
| `(cogen prep-pgm [n] [cmp-goal] [cmp-file ['pp]])` | 前処理済みプログラムからコンパイラ生成 |
| `(comp [cmp-goal] [cmp-file] arg-pat [n] [residual-goal] [residual-file ['pp]])` | 生成済みコンパイラでプログラムを「コンパイル」(=特殊化) |
| `(preprocess! goal bt-pat source-sim-file)` | フロントエンド+BTA+前処理だけ実行(`similix` の内部でも使用) |
| `(front-end goal source-sim-file)` | フロントエンド(言語拡張の翻訳)のみ |

**オプション引数の共通意味**:

- `n`: 特殊化を n 回繰り返してタイム計測(1 なら普通に1回だけ)
- `residual-goal` / `cmp-goal`: 残差(コンパイラ)のゴール手続き名
- `residual-file` / `cmp-file`: 残差(コンパイラ)をファイルに書き出す。
  書き出した場合は戻り値が `'()` になるので `(residual-program)` で取得
- `'pp`: ファイルをプリティプリントで書き出す

**`comp` の `cmp-file`**:コンパイラのファイル名(例 `"MP-cmp.sim"`)。
省略時はメモリ上の「現在のコンパイラ」(`current-compiler`)を使い、
必要なら自動ロードします("loading current compiler" と表示)。

### 結果の取得・表示

| API | 説明 |
|---|---|
| `(residual-program)` | 直近の残差プログラム(データとして) |
| `(load-residual-program)` | 残差をREPLにロード(`append1-0` などが定義される) |
| `(current-compiler)` | `cogen` が生成したコンパイラ(データとして) |
| `(preprocessed-program)` | `(ゴール名 前処理済みプログラム)` |
| `(show)` / `(showpall)` | 前処理済みプログラムを表示。`showpall` はバインディングタイム等の全注記付き |
| `(sim2scheme file)` | `.sim` ファイルを素のSchemeに翻訳 |
| `(compile-sim-file sim-file)` | `.sim` → Schemeソースファイルへ翻訳して書き出し |
| `(compile-and-load-sim-file sim-file)` | 同上+ロード |

### ロード関係

| API | 説明 |
|---|---|
| `(load "foo.sim")` | `.sim` ファイルを**実行用**にロード(`case-match` を含まない場合) |
| `(loads "foo.sim")` | `.sim` ファイルを翻訳(`case-match` 処理)してロード |
| `(loadt "foo.adt")` | `.adt`(代数的データ型の表示定義)をロード。`show`/`showpall` の表示整形に使われる |
| `(loadt! ...)`, `(unloadt ...)` | `.adt` の再ロード/解除 |

### 制御・設定

| API | 説明 |
|---|---|
| `(reset-similix)` | すべての状態(残差、名前カウンタ、設定)をリセット |
| `(verbose-prep-on)` / `(verbose-prep-off)` | 前処理の進行表示のオン/オフ |
| `(verbose-spec n)` | 特殊化の冗長度(0=静か) |
| `(postunfold-on)` / `(postunfold-off)` | ポストunfolding最適化のオン/オフ |
| `(standard-memoization-on/off)` | メモ化方式の切り替え |
| `(set-dynamic-input-symbol sym)` | 動的マーカー(`***`)を変更 |
| `(help)` | API一覧表示 |

### ユーティリティ

`(file->item file)`, `(file->list file)`, `(ntimes suspension n)`
(タイム計測), `(pp e)`, `(out e)`, `(outnl e)`, `(outpp e)`, `(size e)`,
`(writef e file)`, `(writel l file)` ほか。

---

## 6. Similix入力言語(.sim ファイル)

`.sim` ファイルは、厳密な関数型言語サブセット+限定的な副作用を持つ
Scheme方言です(R4RS相当のScheme処理系ならそのまま実行できるように
書かれています)。`examples/append.sim` の全体がこれです:

```scheme
(define (append1 l1 l2)
  (if (null? l1)
      l2
      (cons (car l1) (append1 (cdr l1) l2))))
```

主な約束ごと:

- **バインディングタイムの注記はソースに書きません**。ゴール呼び出し
  (`similix`/`cogen` への引数)で指定し、BTAが自動で決めます
- 扱える副作用は、引数を取らず1つの値を返す**動的プリミティブ**
  (例: 入力操作)などの限定的なクラスだけです
- `case-match`(`(case-match x (pat exp) ...)` 形式のパターンマッチ)という
  言語拡張が使えます。`loads`・`compile-sim-file`・フロントエンドが自動的に
  素のSchemeの `cond`/`let` に翻訳します
- 部分静的データ構造(コンスセル列の静的な「骨格」+動的な「要素」など)が
  扱えます。残差には `(lift e)`(リフト:動的値の静的文脈への持ち上げ)や
  `_cons` などが現れることがあります
- `.adt` ファイルは型に応じた表示定義で、`show`/`showpall` の整形にのみ
  使われます(特殊化の意味には影響しません)

---

## 7. 例題ツアー

`examples/` には5つのジョブ(実行手順を記したスクリプト)があります。
いずれも冒頭のロード行を `sim-chez.ss` に差し替えれば Chez で動きます。
最終フォームが `#t` になれば成功です。

### getting-started — append

§3で解説した入門例。`similix` による特殊化と、`cogen`+`comp` による
コンパイラ経由の特殊化が同一の残差を生成することを確認します。

### MP-job — Mixwell…ではなくMP言語のインタプリタ

Peter Sestoft 氏の論文(DIKU 85/11, 1985)に基づく、while言語(MP言語)
インタプリタ `MP-int.sim` を特殊化します。対象プログラム `power.MP`
(べき乗を計算するMP言語プログラム)を静的に与え、データは動的にします。

```scheme
(similix 'run (list power '***) "MP-int.sim" 1 "power.sim")   ; 残差を "power.sim" に書き出す
(cogen 'run '(s d) "MP-int.sim" 1 "MP-cmp.sim")  ; MP言語向けコンパイラを生成
(comp (string-append "MP-cmp" **Similix-compiled-sim-suffix**)
      (list power '***))                          ; 生成コンパイラで power.MP をコンパイル
```

3つの等式(インタプリタ実行 = 残差実行、similixの残差 = compの残差)が
すべて `#t` になることを確認します。

### com-job — 遅延コンビネータ評価器(Futamura射影の実演)

コンビネータ言語のインタプリタ `com-int.sim`(ゴール手続き `_P`)を題材に、
**コンパイラ生成から「コンパイラ生成器の再現」まで**を一気に検証する、
最も濃い例題です(§8で詳説)。`evens.com`(even数列を生成するコンビネータ
プログラム)を読み込んで使います。

### mw-job — Mixwell インタプリタ

Mixwell 言語のインタプリタ `mw-int.sim`。MP と同じ構成
(インタプリタ実行 → 特殊化 → コンパイラ生成 → コンパイル)を別言語で確認します。

### cog-job — cogen の二重自己適用(要注意)

**通常は実行しないジョブ**です。コンパイラ生成器 `system/cogen.sim` 自体を、
`similix` の二重自己適用で**再生成**します。実行すると
`system/cogen.sim` が(意味は同じでも)内部的な番号付けの異なる版で
**上書きされます**。バックアップ or `git checkout -- system/cogen.sim` で
復元してください。このジョブが `#t` で完走すること自体が、
「部分評価器が自分自身を特殊化できている」ことの強力な証明です。

---

## 8. Futamura射影の実演

部分評価理論の中心概念 **Futamura予測子** を、com-job がそのまま実演して
います。ジョブ内のコメントで使われている `L` 記法は
「L_{(実行系)}(入力…) = 出力」の意味です。

3つの入力を考えます:インタプリタ `int`、対象言語のプログラム `source`、
データ `data`。

| 関係式 | 意味 | com-job での対応 |
|---|---|---|
| `L int (source, data)` | インタプリタで普通に実行 | `(ntimes (lambda () (_P evens 'goal 20)) 10)` |
| `L mix (int, source)` | **第1射影**:インタプリタを特殊化 = source向けコンパイル | `(similix '_P (list evens 'goal '***) "com-int.sim" 1 "evens.sim")` |
| `L cogen (int)` | **第2射影**:コンパイラ生成器でコンパイラ生成 | `(cogen '_P '(s s d) "com-int.sim" 1 "com-cmp.sim")` |
| `L mix (mix, int)` | **第3射影**:mix自身を特殊化してコンパイラ生成器を作る | ジョブ末尾の `(similix '_sim-specialize (list '_P '*** com '***) "…/spec.sim")` |

ジョブの最終等式 `(equal? com-cmp new-com-cmp)` は、
「cogen(第2射影)で作ったコンパイラ」と「similix を mix 自体に適用(第3射影)
して作ったコンパイラ」が**同一である**ことを確認しています。
つまり **コンパイラ生成器 cogen は、特殊化器自身の自己適用から自動的に
導出できる** ことを、この小さな系が実際にデモンストレーションしている
わけです。

そして cog-job は、その cogen すらも二重自己適用で再生成できる
(=系が完全に自己言及的に閉じている)ことを示します。

---

## 9. 実践的Tips

### ジョブの実行方法

- **対話(REPL推奨)**: `chezscheme --quiet` して `(load "../system/sim-chez.ss")`
  のあとジョブをコピペ、または `(load "MP-job")`。トップレベルの値が
  エコーされるので、`#t` の確認が簡単です
- **スクリプト実行**: `chezscheme --script <job>` でも動きますが、
  トップレベル式の**値は表示されません**。`(display ...)` を入れるか、
  REPLに流し込んでください(`chezscheme --quiet < gs-test` でも値が見えます)

### 特殊化が止まらない(ループ)とき

Similixは自動BTAですが、展開が無限に続いてループすることがあります。
`manual.dvi` の「バインディングタイム改善」の節にある定番手法
(静的な引数を動的に落とす、`lift` を入れる、データの表現を変えるなど)が
役に立ちます。まずは `showpall` で注記付きプログラムを眺めて、
どの呼び出しが展開されているかを把握するのが定石です。

### 状態のリセット

`similix`/`cogen` は状態(名前カウンタ、残差、UDL情報など)を持ち越します。
続けて実験するときは `(reset-similix)` を挟むと再現性が保てます。

### 作業ファイル

- `_simtmp.scm`:カレントディレクトリに作られる一時ファイル。通常は
  自動削除されます
- 残差・コンパイラを書き出すファイル名はジョブごとに慣例があります
  (`power.sim`、`MP-cmp.sim`、`evens.sim` など)。上書きに注意してください

---

## 10. トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| `Exception: variable **similix-path** is not bound` 等 | `(case-sensitive #f)` が効いていない。`sim-chez.ss` を改変して `(case-sensitive #f)` が先頭フォームでなくなっていないか確認 |
| `incorrect number of arguments ... append1-0` | ゴール呼び出しのマーカーが `*` や `**`(静的シンボルとして扱われる)。`***` を使う |
| `Exception in load: ... _simtmp.scm` | 書き込み権限のないディレクトリで実行している。`examples/` など書ける場所で |
| `system/cogen.sim` が git で変更された扱いになる | `cogen`/`cog-job` が cogen.sim を再生成したため。意味は同じ(番号付けが違うだけ)なので `git checkout -- system/cogen.sim` で復元 |
| `No current compiler available` | `comp` を `cogen` なしに(ファイル名もなしに)呼んだ。先に `cogen` を実行するか、`comp` にコンパイラファイル名を渡す |
| `No preprocessed program available` | form3の `similix`/`cogen` を `preprocess!` なしに呼んだ |
| 起動時に `variable verbose is not bound` 等 | Scm用アダプタ `sim-scm.scm` をロードしている。`sim-chez.ss` に置き換える |

---

## 11. 参考資料

- `manual.dvi` — Similix 5.0 公式マニュアル(仕様の正典。バインディング
  タイム改善の節は必読)
- `README` — 本リポジトリのREADME(インストール概要、現代Chez対応の節)
- A. Bondorf 氏らによる Similix 関連の一連の論文(システムの自己説明は
  "Similix, a Self-Applicable Partial Evaluator for a Subset of Scheme")
- P. Sestoft: *The structure of a self-applicable partial evaluator*,
  DIKU technical report 85/11, 1985(MP例題の由来)
- Futamura予測子: Y. Futamura (1971) に由来する部分評価理論の基礎概念

---

*本マニュアルは Similix-revised(https://github.com/nisizaki/Similix-revised)
のために作成されました。Similix 5.0 のオリジナル著作権表示(GPL、
Copyright (C) 1993 Anders Bondorf)は `COPYING`・`README` を参照してください。*
