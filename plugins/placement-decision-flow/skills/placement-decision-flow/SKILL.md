---
name: placement-decision-flow
description: '「新しい処理をどこに置くか」をオーケストレーター／サブエージェント定義／スキルの3層から決定的に判定します。判断表と判定コードを同梱し、判定結果・適用した分岐・再利用できる既存スキルの候補を提示します。Use when: deciding where to place a new process, choosing between agent and skill, placement decision, skill vs subagent, orchestrator design.'
argument-hint: '追加したい処理の内容を入力（例: 実行前に秘密情報が含まれていないか検証したい）'
---

# Placement Decision Flow

「新しい処理をどこに置くか」を、オーケストレーター／サブエージェント定義／スキルの3層から
決定的に判定します。

## 起動条件（明示指名のみ）

このスキルは、利用者または上位のエージェントから**明示的に指名されたときだけ**起動します
（FR-018 / FR-019）。

- 起動の例: 「この処理をどこに置くべきか判断して」「配置を相談したい」
- 文脈から判断が必要そうに見えても、**指名なしに自動起動してはなりません**。他の作業の
  途中で判断が割り込むと、「判断で止まる時間を減らす」という目的に逆行します
- 指名がない限り、依頼された作業をそのまま続けます

## 実行手順

### 1. 対象を 1 件に定める

相談された処理が複数ある場合は、**1 件ずつ**判定します。複数をまとめて 1 つの配置先に
丸めてはなりません。性質の異なる処理を同じ場所に寄せることが、このスキルが防ごうと
している誤配置そのものだからです。

### 2. 自然文から 4 分岐の回答を抽出する（FR-013）

| 分岐 | 質問 | 取りうる値 |
|---|---|---|
| `governance` | 実行前検証・権限・外部接続を伴うか | `yes` / `no` / `unknown` |
| `orchestration` | タスクの分解・委任・統合か | `yes` / `no` / `unknown` |
| `reusable` | 他のサブエージェントでも使いそうか | `yes` / `no` / `unknown` |
| `needs_code` | 決定論的な実行コードが必要か | `yes` / `no` / `unknown` |

判断がつかない分岐は `unknown` とします。**推測で `yes` / `no` を埋めてはなりません**
（FR-006）。回答が `unknown` のままでも、先行するゲートで確定すれば判断は返せます。

### 3. AI としての結論を先に出す

抽出した回答から、自分自身の結論（配置先）を先に決めます。これは手順 5 でコードの結論と
比較するために必要です。コードの出力を先に見てしまうと、検証が常に成功して意味を失います。

### 4. 判定コードで機械的に検証する（FR-014）

同じ回答で `scripts/decide.sh` を実行し、コードの結論を得ます。

```bash
scripts/decide.sh --governance <yes|no|unknown> --orchestration <yes|no|unknown> \
  --reusable <yes|no|unknown> --needs-code <yes|no|unknown>
```

出力は `key=value` 形式です。

- `result=decision` — 配置先が確定した。`target` / `reason` / `branches` が返る
- `result=ask` — 判断に必要な回答が足りない。`missing` の分岐を利用者に問い返す
  （FR-006 / FR-012）
- 終了コード 2 — 値の指定が不正。値を正して再実行する

### 5. 食い違ったら矛盾として提示する（FR-015）

手順 3 の AI の結論と手順 4 のコードの結論が異なる場合は、**黙って一方を採用しません**。
両方の結論を並べ、**矛盾していること**を明示して提示します。採用する基準は**コード側**です。

### 6. 再利用候補を調べる（FR-009）

配置先がスキル（`skill-instructions` / `skill-scripts`）のときは、既存スキルを探索し、
重なるものがあれば新規作成ではなく再利用を提案します。

```bash
scripts/find-skills.sh --query <処理を表す語>
```

**候補が出力された場合のみ**再利用を提案します。候補が 0 件のときは「重なる既存スキルは
ない」と伝え、新規作成を妨げません。

## 判断基準

判断基準の正は `references/criteria.md` です。評価順序は
`governance` → `orchestration` → `reusable` → `needs_code` で固定されており、
`governance=yes` のときは `reusable` を評価せず `subagent-definition` に確定します。

## 参照

- `references/criteria.md` — 判断表と評価順序（判断基準の単一の真実源）
- `scripts/decide.sh` — 判定コード（AI の判断を検証する）
- `scripts/find-skills.sh` — 既存スキル探索（再利用候補の列挙）
