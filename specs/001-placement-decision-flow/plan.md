# Implementation Plan: スキルとエージェントの配置判断フロー

**Branch**: `001-placement-decision-flow` | **Date**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-placement-decision-flow/spec.md`

## Summary

オーケストレーター／サブエージェント／スキルの3層でエージェントを組み立てるとき、
「新しい処理をどこに置くか」を決定的に判定する**スキル**を、新規プラグイン
`placement-decision-flow` として追加する。

技術的な核は 2 つ。**判定コード**（`scripts/decide.sh`）が 4 つの質問への回答から配置先を
機械的に導き、**判断表**（`references/criteria.md`）がその規則を人間向けに文書化する。判定は
**ガバナンス該当性を最初のゲート**とし、該当すれば後続の「使い回せるか」を評価せず
サブエージェント定義に確定する（FR-021 / FR-022）。

最大の設計判断は、**判断表を単一の真実源としてテストの入力に使う**こと。`references/criteria.md`
の表をテストが直接読み、`decide.sh` の出力と照合する。これにより手順記述と判定コードの乖離
（FR-017）がテストで検出される。

## Technical Context

**Language/Version**: Bash 3.2 以上（新規スクリプトは **`declare -A` を使わない**。
macOS 同梱の bash 3.2 で動作させるため。既存の `validate-issue.sh` は bash 4+ を要求しているが、
本プラグインはより広い環境で動かす）

**Primary Dependencies**: `git`（リポジトリルート検出）、`find` / `sed` / `grep` / `sort`
（標準コマンド）。**追加の依存を持ち込まない**（憲章 VII）

**Storage**: N/A — 状態を永続化しない。ファイルの読み取りと標準出力のみ

**Testing**: 自作の bash テストランナー `tests/run.sh`（`tests/test_*.sh` を自動探索して実行）。
外部のテストフレームワークを持ち込まない。非空虚性は変異探針で実測する（憲章 V）

**Target Platform**: Agent Plugins 1.0.0 対応クライアント（VS Code Copilot / Claude Code 等）

**Project Type**: プラグイン（Agent Plugins 1.0.0）。**同梱するのはスキルのみ**。
Agent Plugins 1.0.0 が定義する移植可能な部品は `skills/` と `mcp.json` の 2 種類だけで、
エージェントはクライアント固有として範囲外（§7 / Design Decisions）。上位エージェントは
利用側プロジェクトが用意するものとし、本機能の対象外とする

**Performance Goals**: 判定コードの実行が 1 回あたり 1 秒未満。既存スキル探索が
1 万ファイル規模のリポジトリで 2 秒未満

**Constraints**:
- ネットワークアクセス不要（オフラインで完結する）
- 対象リポジトリ内の**読み取りのみ**。ファイルの作成・変更は行わない（FR-020 / Assumptions）
- 出力は UTF-8 で、ロケール設定に依存しない（憲章 VII）
- 環境固有の絶対パスを埋め込まない。パスは `SCRIPT_DIR` 基準で解決する（憲章 VII）
- 非対話で完結する（`read` による入力待ちをしない）

**Scale/Scope**: プラグイン 1 件 / スキル 1 件 / スクリプト 2 件 / 参照ドキュメント 1 件 /
1 テストセット。4 つの質問の回答組合せは 3^4 = 81 通りだが、判定に関わる分岐は 5 行に集約される

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|---|---|---|
| I. Plugin-First Isolation | ✅ PASS | プラグインは `plugins/placement-decision-flow/` に自己完結。スクリプトは `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` で自身の位置を解決し、`../../` によるプラグイン境界の越境参照を持たない。他プラグインに依存しない |
| II. Manifest & Trigger Contract | ✅ PASS | `plugin.json` に `$schema` / `name` / `version` / `description` / `author` を設定。`SKILL.md` の `name` はディレクトリ名 `placement-decision-flow` と一致（Agent Skills 仕様の要求）。`description` に `Use when:` トリガーを含める |
| III. Fail-Closed Validation | ✅ PASS（一部対象外） | 本スキルは副作用を伴わない（判断の提示のみ）ため「副作用前の検証」は適用対象外。ただし判定コードは**不正入力を exit 2 で拒否**し、不明な引数を無視しない（fail-closed）。呼び出し側の判断に依存せず、コード自身が入力妥当性を強制する |
| IV. Evidence-Based Verification | ✅ PASS | `decide.sh` / `find-skills.sh` の終了コードと標準出力の契約を `contracts/` に明記し、テストで固定する。SC-004（停止時間）は観測が難しいため、測定可能な代理指標に置き換える（後述） |
| V. Test-First & Non-Vacuous Tests | ✅ PASS | `tests/run.sh` が `tests/test_*.sh` を自動探索して実行。テストには変異探針を実施し、失敗することを実測する。テストは出荷コードを直接実行して駆動する（コピーを作らない） |
| VI. Marketplace Sync & Semantic Versioning | ✅ PASS | `.github/plugin/marketplace.json` に `source: plugins/placement-decision-flow` を追加。初回リリースのため `version: 1.0.0` |
| VII. Portability & Dependency Minimalism | ✅ PASS | bash + `git` + 標準コマンドのみ。`declare -A` を使わず bash 3.2 互換。追加依存は `README.md` の前提条件に明記。絶対パス埋め込みなし |

**Gate 結果**: 7 原則すべて PASS。違反なしのため Complexity Tracking は空。

**Phase 1 設計後の再評価（2026-09-12）**: `research.md` / `data-model.md` / `contracts/` /
`quickstart.md` の生成後に再確認した。設計で確定した事項が原則に与える影響は次のとおり。

- `contracts/` に `decide.sh` / `find-skills.sh` の**終了コードと出力契約を明記**し、
  テストで固定する方針とした（原則 III・IV の充足を強化。新たな違反なし）
- テストを**プラグインルートの `tests/`** に置き、`tests/run.sh` が `tests/test_*.sh` を
  **探索して実行**する設計とした（原則 V の「収集対象に置く」を満たす）
- `find-skills.sh` は**読み取り専用**で、対象リポジトリに書き込まない契約とした（原則 I の
  境界遵守。越境参照なし）
- 新規スクリプトで **`declare -A` を使わない**方針を確定した（原則 VII。bash 3.2 互換）
- `criteria.md` を判断表の**単一の真実源**とし、テストが読む設計とした（原則 V の
  非空虚性を、文書と実装の同期という形で担保）

**再評価の結果: 7 原則すべて PASS を維持。追加の違反なし。**

### SC-004 の測定方法（原則 IV への対応）

SC-004「『どこに置くか』で停止する時間が1件あたり5分未満になる」は、第三者が再現できる形で
観測できない。原則 IV（実測で裏付ける）に従い、次の**測定可能な代理指標**に置き換える。

- **SC-004a**: 判断の相談が **1 往復で確定**する（追加の問い返しが 0 回）。ただし入力が不明な
  場合は問い返しが正当な結果であり、除外する
- **SC-004b**: 判定コードの実行が **1 秒未満**で完了する

いずれも `tests/` で測定する（**SC-004a は T009 と T034、SC-004b は T034** が固定する）。
元の「5 分未満」は利用者体験としての意図であり、上記 2 つが満たされれば同じ意図を満たす。

## Project Structure

### Documentation (this feature)

```text
specs/001-placement-decision-flow/
├── plan.md              # このファイル（/speckit.plan の出力）
├── research.md          # Phase 0 の出力
├── data-model.md        # Phase 1 の出力
├── quickstart.md        # Phase 1 の出力（検証ガイド）
├── contracts/           # Phase 1 の出力
│   ├── decide-cli.md          # 判定コードの CLI 契約
│   ├── find-skills-cli.md     # 既存スキル探索の CLI 契約
│   └── skill-frontmatter.md   # SKILL.md フロントマター契約
├── checklists/
│   └── requirements.md  # /speckit.specify の出力（＋ Deferred 一覧）
├── spec.md              # /speckit.specify の出力
└── tasks.md             # Phase 2 の出力（/speckit.tasks。このコマンドでは作らない）
```

### Source Code (repository root)

```text
plugins/placement-decision-flow/
├── plugin.json                          # プラグイン契約（$schema / name / version / ...）
├── README.md                            # 利用者向け説明・前提条件・導入方法
├── tests/                               # 配布元での検証（クライアントは探索しない位置）
│   ├── run.sh                           # テストランナー（tests/test_*.sh を探索して実行）
│   ├── test_decide.sh                   # 判定コードの契約テスト（C-1〜C-8・SC-004a）
│   ├── test_find_skills.sh              # 探索の契約テスト（F-1〜F-3 / F-5〜F-6 / F-9）
│   ├── test_criteria_sync.sh            # 判断表と判定コードの同期テスト（FR-017）
│   ├── test_manifest.sh                 # マニフェスト契約（P-1〜P-6 / S-1〜S-3 / S-5 / M-1〜M-2）
│   ├── test_runner.sh                   # ランナーの探索を固定する自己検証（憲章 V）
│   ├── test_governance.sh               # ガバナンス判定の網羅テスト（FR-021 / FR-022・SC-002 / SC-010）
│   ├── test_conventions.sh              # 慣習検出の契約テスト（F-4 / F-7 / F-8）
│   ├── test_constitution.sh             # 憲章 I / VII の実装規律（`declare -A` 不使用・越境参照なし・絶対パスなし）
│   ├── test_performance.sh              # SC-004a / SC-004b の計測
│   └── fixtures/
│       ├── governance-cases.tsv         # ガバナンス判定の期待値（入力・期待 target・期待 reason）
│       └── repo/                        # 探索テスト用の擬似リポジトリ
│           ├── .github/skills/code-review/SKILL.md
│           └── plugins/sample-plugin/skills/sample-skill/SKILL.md
└── skills/
    └── placement-decision-flow/
        ├── SKILL.md                     # 手順 + 起動トリガー（name はディレクトリ名と一致）
        ├── scripts/
        │   ├── decide.sh                # 判定コード（4 回答 → 配置先を機械的に導出）
        │   └── find-skills.sh           # 既存 SKILL.md の探索（候補の列挙）
        └── references/
            └── criteria.md              # 判断表・評価順序・公式設計との対応
```

**Structure Decision**: 単一プラグイン構成を採用する。スキルの資材は Agent Skills 仕様の
`scripts/` / `references/` に従う（`assets/` は今回使わない。配布するテンプレートがないため）。
テストは **プラグインルートの `tests/`** に置き、スキルディレクトリ内には置かない。理由は
2 点。(1) Agent Skills の Progressive Disclosure では `SKILL.md` とその参照だけが読み込まれる
ため、テストをスキル内に置いても配布物が増えるだけで実行時の価値がない。(2) `find-skills.sh` は
リポジトリ内の `SKILL.md` を探索するため、テスト用フィクスチャの `SKILL.md` は実探索の
邪魔になりにくい位置（`tests/fixtures/`）に隔離する。

**`criteria.md` を「判断表の単一の真実源」にする**: `references/criteria.md` の表を
`tests/test_criteria_sync.sh` が読み取り、`decide.sh` の出力と照合する。これにより FR-017
（手順記述と判定コードの同期）が**テストで強制**される。表の書式は次の固定形式とする。

| governance | orchestration | reusable | needs_code | target | reason |
|---|---|---|---|---|---|
| yes | * | * | * | subagent-definition | governance |
| no | yes | * | * | orchestrator | orchestration |
| no | no | yes | yes | skill-scripts | reusable-with-code |
| no | no | yes | no | skill-instructions | reusable-instructions |
| no | no | no | * | subagent-definition | not-reusable |

`*` は「その値を評価しない」を意味する（評価順序による短絡を表す）。テストは `*` の列に
複数の値を流し込んで同一の `target` が返ることを確認する。

> **表の位置づけ**: この節は**表の書式仕様**（列の並びと 5 行）を定めるもので、内容の正は
> `references/criteria.md` にある。`data-model.md` は列の型だけを定義し、表を再掲しない
> （二重定義を作らないため）。`references/criteria.md` と本節の書式が食い違う場合は
> `references/criteria.md` を正とし、本節を修正する。

## Complexity Tracking

> 憲章 Check に違反がないため、このセクションは空。

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| （なし） | — | — |
