# Contract: `decide.sh`（配置判定コード）

**Feature**: `001-placement-decision-flow` | **Version**: 1.0.0

対象ファイル: `plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh`

判定コードは「配置対象」の性質を構造化入力として受け取り、**適用した分岐と配置先**を
機械可読な形で返す（FR-016）。AI の判断を検証する役割を持つ（FR-014）。

---

## 1. 呼び出し形式

```text
decide.sh [OPTIONS]
```

### オプション

| オプション | 値 | 対応する分岐 | 省略時 |
|---|---|---|---|
| `--governance` | `yes` \| `no` \| `unknown` | 実行前検証・権限・外部接続を伴うか | `unknown` |
| `--orchestration` | `yes` \| `no` \| `unknown` | タスクの分解・委任・統合か | `unknown` |
| `--reusable` | `yes` \| `no` \| `unknown` | 他のサブエージェントでも使いそうか | `unknown` |
| `--needs-code` | `yes` \| `no` \| `unknown` | 決定論的な実行コードが必要か | `unknown` |
| `-h`, `--help` | （なし） | — | — |

**制約**:

- 省略されたオプションは `unknown` と同義（エラーにしない）
- 各オプションは 1 回だけ指定できる
- 値は**小文字のみ**受理する（`YES` は不正）
- 上記以外のオプションを指定してはならない

---

## 2. 評価順序（FR-021）

```text
1. governance    == yes  → target=subagent-definition, reason=governance
2. orchestration == yes  → target=orchestrator,        reason=orchestration
3. reusable      == no   → target=subagent-definition, reason=not-reusable
4. needs_code    == yes  → target=skill-scripts,       reason=reusable-with-code
   needs_code    == no   → target=skill-instructions,  reason=reusable-instructions
```

各ステップで、判定に必要な値が `unknown` だった場合は**そこで評価を止めて `result=ask`** を返す。
確定した時点で後続のステップは評価しない（短絡）。

`governance=yes` のときは、`reusable` が `yes` でも `subagent-definition` に確定する（FR-022）。

---

## 3. 標準出力

`key=value` 形式の ASCII 行。**1 フィールド 1 行**。行の順序は固定。それ以外の行を
出力してはならない。

### 3.1 判定を返す場合（`result=decision`）

```text
result=decision
target=<orchestrator|subagent-definition|skill-instructions|skill-scripts>
reason=<governance|orchestration|reusable-with-code|reusable-instructions|not-reusable>
branches=<field>=<value>[,<field>=<value>...]
```

`branches` は**実際に評価した**分岐を評価順に並べたもの。短絡して評価しなかった分岐は
含めない（`unknown` も含めない）。

### 3.2 問い返しを返す場合（`result=ask`）

```text
result=ask
missing=<governance|orchestration|reusable|needs_code>
```

`missing` は評価順で最初に `unknown` に到達した分岐。

> **注**: これは「判断不能」ではなく**正当な結果の 1 つ**（FR-006 / FR-012）。
> 終了コードは `0`。

---

## 4. 終了コード

| コード | 条件 | stdout | stderr |
|---|---|---|---|
| `0` | 判定（`result=decision`）または問い返し（`result=ask`）を返した | `key=value` 行 | なし |
| `2` | 入力が不正（不明なオプション、不正な値、値の重複指定） | なし | 違反の理由を 1 行以上 |

- exit `1` は予約（予期しない内部エラー専用）。通常経路では返さない
- **不正入力を黙って既定値に置き換えてはならない**（憲章 III / fail-closed）

---

## 5. 決定性（FR-008 / SC-006 / SC-010）

同じ引数の組合せに対して、**常に同じ stdout と終了コード**を返す。

- 環境変数・カレントディレクトリ・時刻・ホスト名に依存してはならない
- 出力は UTF-8 かつロケール非依存（ASCII の識別子のみを出力する。憲章 VII）
- 乱数・並列処理・非決定的なソートを使ってはならない

---

## 6. 使用例

```text
$ decide.sh --governance yes
result=decision
target=subagent-definition
reason=governance
branches=governance=yes
```

```text
$ decide.sh --governance no --orchestration yes
result=decision
target=orchestrator
reason=orchestration
branches=governance=no,orchestration=yes
```

```text
$ decide.sh --governance no --orchestration no --reusable yes --needs-code yes
result=decision
target=skill-scripts
reason=reusable-with-code
branches=governance=no,orchestration=no,reusable=yes,needs_code=yes
```

```text
$ decide.sh --governance no --orchestration no --reusable no
result=decision
target=subagent-definition
reason=not-reusable
branches=governance=no,orchestration=no,reusable=no
```

```text
$ decide.sh --governance no --orchestration unknown
result=ask
missing=orchestration
```

```text
$ decide.sh --governance maybe
（stderr に理由、stdout なし）
exit 2
```

```text
$ decide.sh --governance yes --reusable yes --needs-code yes
result=decision
target=subagent-definition
reason=governance
branches=governance=yes
```

（最後の例は FR-022 の不変条件: ガバナンス該当時は `reusable` を評価しない）

---

## 7. 不変条件（テストで固定する）

| # | 不変条件 | 根拠 |
|---|---|---|
| C-1 | 4 オプションの全組合せ（3^4 = 81 通り）で exit 0 または exit 2 のいずれかを返し、クラッシュしない | 憲章 III |
| C-2 | `result=decision` のとき `reason` は 5 値のいずれかであり、`target` がその `reason` に一意に対応する | data-model 1.5.1 |
| C-3 | `governance=yes` かつ `reusable=yes` のとき、`target=subagent-definition` かつ `reason=governance` | FR-022 |
| C-4 | `result=decision` のとき、`branches` のフィールド順が評価順（`governance` → `orchestration` → `reusable` → `needs_code`）と一致する | FR-004 |
| C-5 | `result=ask` のとき、`missing` は `branches` に入っていない最初の分岐である | FR-006 |
| C-6 | `target` は 4 値、`reason` は 5 値、`missing` は 4 値のいずれかに限る | FR-002 / FR-003 |
| C-7 | 同じ引数で 2 回実行したとき、stdout が byte 単位で一致する | FR-008 |
| C-8 | 出力に ASCII 以外のバイトが含まれない | 憲章 VII |
