# Specification Quality Checklist: スキルとエージェントの配置判断フロー

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Items marked incomplete require spec updates before `/speckit.clarify` or `/speckit.plan`

### 検証メモ（2026-09-12）

- 「スキル」「サブエージェント」「オーケストレーター」は、本機能が判断する**対象そのもの**であり
  実装手段ではないため、Content Quality の「実装詳細なし」に抵触しないと判断した。理由: 成果物の
  利用者が「どこに置くか」を決めるための語彙であり、技術スタックや API を指定していない。
- FR-008 / SC-006（同じ入力で同じ判断）は、判断が属人的にならないことを求める要件であり、
  実装方式（スクリプトか文書か）を指定していない。
- Assumptions で成果物の形態をスキルと決めている根拠は、Agent Plugins 1.0.0 の移植可能な中核が
  `skills/` と `mcp.json` に限られる点、および配置サマリーで「手順」がスキル側に分類されている点。
  この判断を変更する場合は User Story の Independent Test は変わらないが、Assumptions と
  プラグイン構造の再検討が必要。

### Clarify 後の再検証（2026-09-12）

- 5 問の明確化により、判定方式（AI 判断＋機械検証）、再利用探索、起動条件、成果物の形態、
  配置先の範囲、評価順序が確定。FR 22 件 / SC 10 件 / 受入シナリオ 14 件。
- **FR-014 / FR-016 / FR-017（判定コードの入出力契約と同期）の受入基準は、ユーザー受入
  シナリオではなく契約テストで担保する**。理由: 判定コードの入出力（構造化入力・機械可読な
  出力・手順記述との同期）は利用者から見た振る舞いではなく、内部インタフェースの契約で
  あるため。テストでは出荷コードを直接実行して駆動し、変異で失敗することを実測する
  （憲章 IV / V）。
- **FR-015（矛盾の提示）は判定コードの契約では担保できない**。矛盾を検出して提示するのは
  AI 側の振る舞いであり、`decide.sh` は AI の判断を受け取らないため矛盾を知り得ない。
  したがって FR-015 / SC-008 は `SKILL.md` の手順記述（T015）と `quickstart.md` の検証 13 に
  よる人手確認で担保する。
- FR-018 / FR-019（起動条件）は User Story 1 の受入シナリオ 8 で、FR-021 / FR-022（評価順序）は
  User Story 2 の受入シナリオ 4 と SC-010 で裏付けた。ただし FR-018 / FR-019 / SC-009 は
  機械的なテストが無いため、`quickstart.md` の検証 12 による人手確認を併せて必要とする。

### Deferred（質問枠超過により未確定）

質問は 5 問（＋1 問の読み替え）で上限に達したため、以下は未確定。影響の大きい順。

| # | 論点 | 影響 | 先送り先 |
|---|---|---|---|
| D-1 | FR-009 の「重なる既存スキル」の判定基準（名前一致のみか、説明の類似まで見るか） | 高（SC-003 の測定方法が定まらない） | clarify（新セッション） |
| D-2 | FR-016 の構造化入力のスキーマと「不明」の扱い（2値か3値か、不明時の分岐） | 高（判定コードの契約テストが書けない） | clarify（新セッション） |
| D-3 | FR-013/014 の実行順序（AI 判断 → コード検証か、コード → AI 補足か） | 高（FR-015 の矛盾提示の流れが変わる） | clarify（新セッション） |
| D-4 | 判断結果の提示フォーマット（表か文章か） | 中（SC-005 は形式自由でも測定可能） | plan |
| D-5 | 複数処理をまとめて相談した場合の扱い（1 件ずつか一括か） | 中（FR-001 は単数形を想定） | plan |
| D-6 | オーケストレーター層の「ファイル」の実体（エージェント定義か、tool 呼び出し設定か） | 中（FR-020 の具体パス提示に必要） | plan |
| D-7 | 既存スキル探索の深さと除外（`.git`、`node_modules`、`tmp` など） | 中（誤検出と探索コスト） | plan |
| D-8 | SC-004 の測定方法（停止時間 5 分未満の測り方） | 中（観測が難しい指標） | plan（測定方法を再定義） |
| D-9 | 判定コードの実装言語と実行形態 | 低（憲章 VII の範囲内で plan が決定） | plan |
| D-10 | プラグイン名（憲章 II の命名制約に適合する名前） | 低（plan で決定） | plan |
| D-11 | 判断結果の出力言語 | 低（憲章 II は `description` の英語トリガーのみ要求） | plan |

### 検証メモ（初回）

- 「スキル」「サブエージェント」「オーケストレーター」は、本機能が判断する**対象そのもの**であり
  実装手段ではないため、Content Quality の「実装詳細なし」に抵触しないと判断した。理由: 成果物の
  利用者が「どこに置くか」を決めるための語彙であり、技術スタックや API を指定していない。
- FR-008 / SC-006（同じ入力で同じ判断）は、判断が属人的にならないことを求める要件であり、
  実装方式（スクリプトか文書か）を指定していない。
- Assumptions で成果物の形態をスキルと決めている根拠は、Agent Plugins 1.0.0 の移植可能な中核が
  `skills/` と `mcp.json` に限られる点、および配置サマリーで「手順」がスキル側に分類されている点。
  この判断を変更する場合は User Story の Independent Test は変わらないが、Assumptions と
  プラグイン構造の再検討が必要。
