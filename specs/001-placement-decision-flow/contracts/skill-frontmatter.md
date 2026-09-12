# Contract: スキルとプラグインのマニフェスト

**Feature**: `001-placement-decision-flow` | **Version**: 1.0.0

対象:
- `plugins/placement-decision-flow/plugin.json`
- `plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md`
- `.github/plugin/marketplace.json`（登録エントリ）

マニフェストとフロントマターは**唯一の機械可読な契約**である（憲章 II）。クライアントは
ここに書かれた内容だけでスキルを発見・起動する。

---

## 1. `plugin.json`

`plugin.json` は**閉じたスキーマ**（Agent Plugins 1.0.0 §5.5）。定義されたキー以外を
追加してはならない。

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "placement-decision-flow",
  "version": "1.0.0",
  "description": "「新しい処理をどこに置くか」を、オーケストレーター／サブエージェント定義／スキルの3層から決定的に判定する共通スキル。判断表と判定コードを同梱し、判定結果と適用した分岐を提示します。",
  "author": {
    "name": "DMARU9",
    "url": "https://github.com/DMARU9"
  }
}
```

### 検証規則

| # | 規則 | 根拠 |
|---|---|---|
| P-1 | `$schema` は `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` と完全一致 | Agent Plugins §5.5 |
| P-2 | `name` は `^(?!.*(?:--\|\.\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$` に一致し 1〜64 文字 | Agent Plugins §5.5 |
| P-3 | `version` は SemVer（初回は `1.0.0`） | 憲章 VI |
| P-4 | `description` は空でない文字列 | Agent Plugins §5.5 |
| P-5 | `author` は既存プラグイン（`github-issue`）と同形式（`name` + `url`） | リポジトリの慣習 |
| P-6 | 上記以外のトップレベルキーを含まない | Agent Plugins §5.5（閉じたスキーマ） |

---

## 2. `SKILL.md` フロントマター

```yaml
---
name: placement-decision-flow
description: '「新しい処理をどこに置くか」をオーケストレーター／サブエージェント定義／スキルの3層から決定的に判定します。判断表と判定コードを同梱し、判定結果・適用した分岐・再利用できる既存スキルの候補を提示します。Use when: deciding where to place a new process, choosing between agent and skill, placement decision, skill vs subagent, orchestrator design.'
argument-hint: '追加したい処理の内容を入力（例: 実行前に秘密情報が含まれていないか検証したい）'
---
```

### 検証規則

| # | 規則 | 根拠 |
|---|---|---|
| S-1 | `name` は**親ディレクトリ名と完全一致**（`placement-decision-flow`） | Agent Skills 仕様 |
| S-2 | `name` は小文字英数字とハイフンのみ。先頭末尾は英数字。`--` を含まない。1〜64 文字 | Agent Skills 仕様 |
| S-3 | `description` は 1〜1024 文字 | Agent Skills 仕様 |
| S-4 | `description` は「何をするか」と「いつ使うか」の両方を含む | Agent Skills 仕様 |
| S-5 | `description` に **`Use when:` で始まる英語トリガー**を含む | 憲章 II |
| S-6 | `argument-hint` は利用者に実際に入力を期待する場合のみ記載する | 憲章 II |
| S-7 | 本文は **500 行未満** | Agent Skills 仕様（Progressive Disclosure） |
| S-8 | 資材への参照は**スキルルートからの相対パス**、1 階層まで | Agent Skills 仕様 |
| S-9 | 配布する資材は `scripts/` と `references/` に置く（`assets/` は使わない） | 計画の Structure Decision |

### 本文が満たすべき内容（FR-001 〜 FR-007）

- 起動は**明示指名のみ**であることを明記する（FR-018 / FR-019。文脈による自動起動をしない）
- 実行手順: 自然文から 4 分岐の回答を抽出 → `decide.sh` を実行 → 結果を検証 → 提示（FR-013 / FR-014）
- `references/criteria.md` の判断表と `decide.sh` の出力が食い違ったら**矛盾として提示**する
  と明記する（FR-015）。基準の正は**コード側**（spec の Assumptions）
- 再利用候補が `find-skills.sh` の出力にある場合のみ提示する（FR-009）
- 同じリポジトリ内の相対パスで配置先を示す（FR-007 / FR-020）
- 判断を保留したまま終わらない（FR-012）

---

## 3. `references/criteria.md` の必須内容

| # | 内容 | 根拠 |
|---|---|---|
| R-1 | 4 分岐の質問文と評価順序（1 → 2 → 3 → 4） | FR-021 |
| R-2 | **固定書式の判断表**（`*` ワイルドカード付き 6 列・5 行。書式仕様は [plan.md](../plan.md) の Structure Decision） | FR-017 / R-9 |
| R-3 | ガバナンス項目の 3 分類と、それがサブエージェント定義に置かれる理由 | FR-005 / FR-022 |
| R-4 | スキル内訳（`SKILL.md` と `scripts/`）の使い分け | FR-003 |
| R-5 | **公式設計との対応**（Anthropic / OpenAI / Microsoft / Google ADK / LangGraph のいずれの設計とも矛盾しないことの説明） | FR-011 |

R-2 の表は `tests/test_criteria_sync.sh` がパースするため、**書式を変えてはならない**。
書式を変えるとテストが失敗し、FR-017（コードとの同期）が破れる。

---

## 4. `.github/plugin/marketplace.json` の登録エントリ

`plugins` 配列に次の 1 件を追加する（憲章 VI）。

```json
{
  "name": "placement-decision-flow",
  "source": "plugins/placement-decision-flow",
  "description": "「新しい処理をどこに置くか」をオーケストレーター／サブエージェント定義／スキルの3層から決定的に判定する共通スキル。",
  "version": "1.0.0"
}
```

### 検証規則

| # | 規則 | 根拠 |
|---|---|---|
| M-1 | `source` は `plugins/<name>` で、`plugins/<name>/plugin.json` が実在する | 憲章 VI |
| M-2 | `plugins[].name` と `plugins[].version` が `plugin.json` の値と一致する | 憲章 VI |
| M-3 | 既存エントリ（`conventional-commit` / `github-issue`）を変更しない | spec の Assumptions |
| M-4 | `plugins` 配列の並びは `name` の昇順を保つ（既存の並びに合わせる） | リポジトリの慣習 |

---

## 5. 整合性の確認コマンド（憲章 VI）

```bash
# plugin.json と marketplace.json の name/version 一致を確認
diff <(jq -S '{name,version}' plugins/placement-decision-flow/plugin.json) \
     <(jq -S '.plugins[] | select(.name=="placement-decision-flow") | {name,version}' \
        .github/plugin/marketplace.json)

# SKILL.md の name と親ディレクトリ名の一致を確認
diff <(grep -m1 '^name:' plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md | sed 's/^name: *//') \
     <(basename plugins/placement-decision-flow/skills/placement-decision-flow)
```

いずれも差分が出なければ整合している。**この確認はテストとして `tests/` に置く**
（憲章 V: 手動確認に依存しない）。
