# Contract: `find-skills.sh`（既存スキル探索）

**Feature**: `001-placement-decision-flow` | **Version**: 1.0.0

対象ファイル: `plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh`

対象リポジトリ内の `SKILL.md` を探索し、**再利用候補**を列挙する（FR-009）。特定の
ディレクトリ構成に依存しない（FR-010）。**読み取り専用**で、対象リポジトリに一切書き込まない
（FR-020）。

---

## 1. 呼び出し形式

```text
find-skills.sh [OPTIONS]
```

### オプション

| オプション | 値 | 既定 | 説明 |
|---|---|---|---|
| `--root <dir>` | ディレクトリパス | `git rev-parse --show-toplevel` の結果（git リポジトリでなければカレントディレクトリ） | 探索の起点 |
| `--query <text>` | 任意の文字列 | （なし ＝ 全件） | `name` または `description` への部分一致フィルタ |
| `--exclude <name>` | ディレクトリ名 | （なし） | 追加の除外ディレクトリ名。複数回指定可 |
| `--detect-conventions` | （なし） | — | スキル候補の代わりに**慣習ディレクトリの実在確認**を出力する |
| `-h`, `--help` | （なし） | — | 使用方法を stdout に出して exit 0 |

**制約**:

- `--query` は**大文字小文字を区別しない**
- `--root` を明示しない場合、**カレントディレクトリではなく git リポジトリルート**を使う
- 上記以外のオプションを指定してはならない

---

## 2. 探索規則

1. ルートを決定する（`--root` > `git rev-parse --show-toplevel` > カレントディレクトリ）
2. ルート配下を `find` で走査し、ファイル名が `SKILL.md` のものを集める
3. 以下のディレクトリを `-prune` で除外する

   `.git` / `node_modules` / `tmp` / `dist` / `build` / `vendor` / `.venv` / `venv` / `__pycache__`
   （`--exclude` で追加指定された名前も加える）

4. **ドット始まりのディレクトリを一律に除外しない**（`.github/skills/` を対象に含めるため）
5. 各 `SKILL.md` のフロントマターから `name` と `description` を読む
6. `--query` が指定されていれば、`name` または `description` に部分一致するものだけを残す
7. 出力パスを**昇順にソート**して出力する

**除外の根拠**: 除外しないと `.git` のオブジェクトや `node_modules` を走査し、性能目標
（1 万ファイル規模で 2 秒未満）を満たせない。`.github/` を除外すると FR-010 と受入シナリオ 7 が
壊れるため、ドット始まりを一律除外してはならない。

---

## 3. 標準出力

### 3.1 通常モード（候補の列挙）

**タブ区切りの 1 行 1 候補**。ヘッダ行は出さない。

```text
<repo-relative-path>\t<name>\t<description>
```

- `path` は**リポジトリルート相対**（絶対パスを出力してはならない。FR-007 / FR-020）
- `description` にタブが含まれる場合、タブを空白 1 個に置換する（列が崩れるのを防ぐ）
- `description` の改行は空白 1 個に置換する（1 候補 1 行を保証する）
- 候補が 0 件のときは**何も出力しない**（空行も出さない）
- `path` の昇順でソートする（決定性のため）

### 3.2 慣習検出モード（`--detect-conventions`）

**タブ区切りの 1 行 1 件**。検出候補ごとに `exists` を報告する。

```text
<layer>\t<path>\t<exists>
```

| `layer` | 候補 `path` |
|---|---|
| `skill` | `.github/skills/` |
| `skill` | `plugins/*/skills/` |
| `subagent` | `.github/agents/` |
| `subagent` | `.claude/agents/` |

- `exists` は `yes` または `no`
- 出力順は `layer` → `path` の昇順
- **4 行すべてを出力する**（存在しないものも `no` として報告する。存在しないこと自体が
  利用者にとっての情報になるため）

---

## 4. 終了コード

| コード | 条件 | stdout |
|---|---|---|
| `0` | 探索が完了した（候補 0 件、慣習 0 件を含む） | 上記の行、または空 |
| `2` | 入力が不正（不明なオプション、値の欠落） | なし（stderr に理由） |
| `3` | `--root` で指定されたディレクトリが存在しない、または読み取れない | なし（stderr に理由） |

- **候補 0 件はエラーではない**（exit 0）。「重なる既存スキルがない」は正常な結果

---

## 5. 決定性（FR-008 / FR-010）

- 同じリポジトリ状態と同じ引数に対して、**常に同じ stdout と終了コード**を返す
- ファイルシステムの列挙順に依存しない（必ずソートする）
- `--root` を明示すれば、カレントディレクトリを変えても同じ結果になる
- 出力は UTF-8 かつロケール非依存。ソート順がロケールで変わらないよう `LC_ALL=C` を用いる
- 対象リポジトリに**書き込まない**（一時ファイルを作らない）

---

## 6. 使用例

```text
$ find-skills.sh --root ./tests/fixtures/repo
.github/skills/code-review/SKILL.md	code-review	コードレビューを実施する。Use when: reviewing code.
plugins/sample-plugin/skills/sample-skill/SKILL.md	sample-skill	サンプル処理。Use when: running samples.
```

```text
$ find-skills.sh --root ./tests/fixtures/repo --query review
.github/skills/code-review/SKILL.md	code-review	コードレビューを実施する。Use when: reviewing code.
```

```text
$ find-skills.sh --root ./tests/fixtures/repo --query zzz-not-found
（出力なし、exit 0）
```

```text
$ find-skills.sh --detect-conventions --root ./tests/fixtures/repo
skill	.github/skills/	yes
skill	plugins/*/skills/	yes
subagent	.claude/agents/	no
subagent	.github/agents/	no
```

（`--detect-conventions` の出力順は `layer` → `path` の昇順。`subagent` が `skill` より
後に来るのはこのため）

```text
$ find-skills.sh --root /nonexistent
（stderr に理由）
exit 3
```

---

## 7. 不変条件（テストで固定する）

| # | 不変条件 | 根拠 |
|---|---|---|
| F-1 | 出力の `path` は絶対パスにならない（先頭が `/` でない） | FR-020 |
| F-2 | 候補 0 件で exit 0、stdout が空 | FR-009 |
| F-3 | 同じ入力で 2 回実行したとき stdout が byte 単位で一致する | FR-008 |
| F-4 | `--detect-conventions` は常に 4 行出力する | data-model 1.7 |
| F-5 | `.github/skills/` 配下の `SKILL.md` が検出される（ドット始まりを除外しない） | FR-010 |
| F-6 | `.git` / `node_modules` / `tmp` 配下の `SKILL.md` が検出されない | R-7 |
| F-7 | `--root` を指定したとき、カレントディレクトリを変えても同じ結果になる | FR-010 |
| F-8 | 対象リポジトリの `git status` が実行前後で変化しない（書き込みがない） | FR-020 |
| F-9 | 出力のソート順が `LC_ALL` の値に依存しない | 憲章 VII |
