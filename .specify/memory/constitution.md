<!--
Sync Impact Report
==================
Version change: N/A（初回制定）→ 1.0.0

Modified principles:
  - （新規）I. Plugin-First Isolation（NON-NEGOTIABLE）
  - （新規）II. Manifest & Trigger Contract
  - （新規）III. Fail-Closed Validation
  - （新規）IV. Evidence-Based Verification
  - （新規）V. Test-First & Non-Vacuous Tests
  - （新規）VI. Marketplace Sync & Semantic Versioning
  - （新規）VII. Portability & Dependency Minimalism

Added sections:
  - Additional Constraints（リポジトリ構造・ツール制約）
  - Development Workflow（SDD フローと品質ゲート）
  - Governance

Removed sections: なし

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md（Constitution Check は汎用記述のため変更不要と確認）
  - ✅ .specify/templates/spec-template.md（変更不要と確認）
  - ✅ .specify/templates/tasks-template.md（テスト任意の記述を原則 V に整合させるため更新）
  - ✅ .specify/templates/checklist-template.md（変更不要と確認）
  - ✅ .github/copilot-instructions.md（SPECKIT ブロックは拡張機能が管理するため未変更）

Follow-up TODOs:
  - TODO(RUNTIME_GUIDANCE): README.md が削除済みのルート `marketplace.json` を現在も
    記載している（正は `.github/plugin/marketplace.json`）。原則 VI に従い Issue を起票して
    齟齬を解消すること。
-->

# copilot-plugins-marketplace Constitution

## Core Principles

### I. Plugin-First Isolation（NON-NEGOTIABLE）

すべてのスキル・エージェントは `plugins/<plugin-name>/` 配下の**自己完結したプラグイン**として
開発しなければならない（MUST）。プラグインは単独でコピー・削除・配布でき、他プラグインや
リポジトリルートのファイルに依存してはならない（MUST NOT）。

- 共有したいロジックは「プラグインの外に置く」のではなく、利用側プラグインへ複製するか、
  依存先を明示的な前提条件として文書化する。
- プラグイン境界を越える相対参照（`../../` 等）を禁止する。
- プラグイン内スクリプトは自身の位置を基準にパスを解決しなければならない（MUST）。
  実行時のカレントディレクトリに依存してはならない（MUST NOT）。

**Rationale**: 本リポジトリの存在意義は、散在するスキルを共有元に集約し、各プロジェクトが
コピーせず追従できるようにすることにある。境界が曖昧なプラグインは配布単位として成立せず、
マーケットプレイス経由の参照という目的そのものを破壊する。

### II. Manifest & Trigger Contract

各プラグインの `plugin.json`、および各スキルの `SKILL.md` YAML フロントマターは
**唯一の機械可読な契約**であり、実装と常に一致していなければならない（MUST）。

- `plugin.json` は `name` / `version` / `description` / `author` を持ち、`$schema` に
  Agent Plugins の公式スキーマ URL を指定する。
- `SKILL.md` の `name` はディレクトリ名と完全一致させる（MUST）。
- `description` は「何をするか」に加えて `Use when:` 形式の**起動トリガー**を英語で
  含めなければならない（MUST）。トリガーの無い説明はスキルが発見されない原因になる。
- `argument-hint` など任意フィールドは、ユーザー入力を実際に期待する場合のみ記載する。

**Rationale**: スキルは説明文の一致度で発見・起動される。frontmatter は人間向けの飾りではなく
ルーティングの入力であり、陳腐化は「スキルが使われない」という無言の障害を生む。

### III. Fail-Closed Validation

外部へ副作用を及ぼす操作（Issue 登録、コミット、ファイルの削除・上書きなど）の前には、
**決定的な検証スクリプトを必ず実行**しなければならない（MUST）。検証は「エラーが 1 件でも
あれば終了コード非 0 で拒否する」フェイルクローズド方式とする。

- 破壊的操作を行うスクリプトは、内部で検証を**再実行**しなければならない（MUST）。
  呼び出し側が検証を省略しても危険な操作に到達できない構造にする。
- 検証は `--dry-run` 等のプレビュー手段を提供し、ユーザーが結果を確認してから確定できるようにする。
- AI の判断のみを根拠に副作用を実行してはならない（MUST NOT）。判断はスクリプトの終了コードで
  再現可能に裏付ける。

**Rationale**: 本リポジトリの成果物は AI エージェントが直接実行する。人間のレビューが挟まれない
経路では「通してしまう既定」が致命的であり、明示的な拒否を既定動作にする必要がある。

### IV. Evidence-Based Verification

主張は推測ではなく**実測**で裏付ける。仕様・計画・タスク・README に「動作する」「準拠している」
「再現しない」と書く場合、それを示す再現可能なコマンドと観測結果を併記しなければならない（MUST）。

- スクリプトの入出力契約（標準出力・標準エラー・終了コード）を明記し、テストで固定する。
- 「環境依存で再現しない」という結論は、環境差の原因を特定できた場合に限り許容する。原因未特定の
  まま誤指摘と断定してはならない（MUST NOT）。未特定なら保留とし、解決条件を残す。
- ロケール・`stdin` の TTY 有無・上流ツールのキャッシュなど、環境で分岐する要因を疑う。
- 観測に使ったコマンドは、第三者が同条件で再実行できる形で記録する。

**Rationale**: このリポジトリの欠陥は「静かに何も起きない」形で現れやすい（検証をすり抜けた
登録、起動しないスキル）。実測の記録が唯一の再発防止策になる。

### V. Test-First & Non-Vacuous Tests

実行可能なロジック（シェルスクリプト・検証処理・変換処理）にはテストを伴わなければならない（MUST）。
テストは「書いたつもり」ではなく、**欠陥を実際に検出できること**を確認する。

- テスト作成後、対象コードに意図的な変異（削除・改変）を加え、テストが失敗することを確認する
  （MUST）。失敗しないテストは存在しないものとして扱う。
- 欠陥クラスごとに最小の反例を設計し、指摘をそのまま流用せず自分で再現する。
- テストが実装のコピーを固定していないか確認する。テストは出荷コードを直接実行して駆動する。
- テストはランナーの収集対象に配置しなければならない（MUST）。収集対象外のテストは存在しないのと
  等しい。

**Rationale**: 「テストは green だが欠陥を見ていない」状態は、検証済みという誤った安心を生む。
変異による確認だけがテストの非空虚性を保証する。

### VI. Marketplace Sync & Semantic Versioning

`.github/plugin/marketplace.json` と各 `plugin.json` の `name` / `description` / `version` は
同期していなければならない（MUST）。バージョンは Semantic Versioning に従う。

- 破壊的変更（スキルの削除、frontmatter 契約の変更、必須引数の変更）は MAJOR を上げる。
- 後方互換な機能追加は MINOR、文言修正・ドキュメントのみの変更は PATCH を上げる。
- プラグイン名とディレクトリ名を一致させ、`source` のパスを実在するディレクトリに保つ。
- マーケットプレイス定義は配布の入口であるため、説明文の変更も配布物の変更として扱う。

**Rationale**: 追従する各プロジェクトはバージョンと説明だけを見て導入可否を判断する。同期漏れは
「更新したのに届かない」という静かな破損として現れる。

### VII. Portability & Dependency Minimalism

プラグインの実行時依存は標準的なシェル環境（bash、git、`gh` など）に留めなければならない（MUST）。
追加の依存を導入する場合は、理由と前提条件をプラグインの `README.md` に明記する。

- スクリプトは `set -euo pipefail` を宣言し、`SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`
  方式で自身の位置を解決する。
- 出力は UTF-8 で行い、ロケール設定によって壊れてはならない（MUST NOT）。
- 対話的入力を前提とせず、非対話環境（CI・エージェント実行）で完結できるようにする。
- 環境固有の絶対パスを埋め込んではならない（MUST NOT）。

**Rationale**: スキルは複数のプロジェクト・複数の実行環境で呼ばれる。前提が暗黙なスクリプトは
特定環境でのみ動き、他プロジェクトで「使えないスキル」になる。


## Additional Constraints

### リポジトリ構造

```text
copilot-plugins-marketplace/
├── .github/
│   ├── plugin/marketplace.json      # マーケットプレイス定義（配布の入口）
│   └── copilot-instructions.md
├── plugins/
│   └── <plugin-name>/
│       ├── plugin.json              # 必須。プラグイン契約
│       ├── README.md                # 必須。利用者向け説明・前提条件
│       └── skills/
│           └── <skill-name>/
│               ├── SKILL.md         # 必須。name / description / Use when:
│               ├── scripts/         # 検証・実行スクリプト
│               └── assets/          # テンプレート等（旧称 templates）
└── .specify/                        # Spec-Driven 開発の成果物
```

- スキルの資材ディレクトリは `assets/` に統一する（`templates/` は使用しない）。
- `SKILL.md` のフォーマット定義（種別・必須セクション・制約値）は、対応する検証スクリプト内の定義と
  **必ず同期**する。片方のみの変更を認めない。
- 生成物（`tmp/` 配下の下書き等）を成果物としてコミットしてはならない（MUST NOT）。

### ツールと実行環境

- スキル実行用スクリプトは bash を標準とする。
- 検証は原則「終了コード」で機械判定できるようにする。
- ネットワークを要する操作（`gh`、パッケージ取得）は、事前に前提条件を確認し、失敗時は次の操作に
  進まない。

## Development Workflow
<!-- Example: Development Workflow, Review Process, Quality Gates, etc. -->

[SECTION_3_CONTENT]
本リポジトリの開発は Spec-Driven Development（SDD）に従う。

1. **Specify**: 追加・改修するプラグインの意図を `/speckit.specify` で仕様化する。仕様は
   「利用者がどう使うか」を起点にする。
2. **Plan**: `/speckit.plan` で技術方針を決め、**Constitution Check**（本憲章 7 原則）を
   通過させる。違反が必要な場合は Complexity Tracking に正当化を記載する。
3. **Tasks**: `/speckit.tasks` でユーザーストーリー単位のタスクに分解する。
4. **Implement**: `/speckit.implement` で実装する。テストは原則 V に従い必須とする。
5. **Review**: 変更はプラグイン単位の diff として確認し、原則ごとに逸脱の有無を点検する。

### 品質ゲート

以下を満たさない変更をマージしてはならない（MUST NOT）。

- 検証スクリプトが対象ファイルで終了コード 0 を返し、かつ**不正入力で非 0 を返す**ことの実測がある。
- `plugin.json` / `SKILL.md` / `marketplace.json` / `README.md` の記述が相互に矛盾しない。
- 原則 V に従い、追加したテストが変異を検出できることの実測がある。
- バージョンが原則 VI に従って更新されている。

## Governance

本憲章は、リポジトリ内の他の慣習・テンプレート・ドキュメントに優先する。矛盾が生じた場合は
本憲章を正とし、下位文書を修正する。

### 改正手続き

- 改正は `/speckit.constitution` を通じて行い、変更内容と理由をコミットメッセージに残す。
- 改正時は憲章冒頭の Sync Impact Report を更新し、影響を受けるテンプレート・ランタイムガイダンス
  （`.github/copilot-instructions.md`、各プラグイン `README.md`）を同一変更内で同期させる。
- 原則の追加・削除・再定義は実測可能な形で記述する。「〜すべき」のみの曖昧な原則を残さない。

### バージョン方針

- **MAJOR**: 原則の削除・後方非互換な再定義、ガバナンス手続きの不整合な変更。
- **MINOR**: 原則・節の追加、または実質的に拡張されたガイダンス。
- **PATCH**: 文言修正、誤字修正、意味を変えない明確化。

### 準拠レビュー

- すべてのレビューは本憲章の 7 原則に対する逸脱の有無を確認する。
- 逸脱は Complexity Tracking に記録された正当化なしに許容されない。
- 検証不能な主張（実測の裏付けがない記述）は、原則 IV により不合格とする。

**Version**: 1.0.0 | **Ratified**: 2026-09-12 | **Last Amended**: 2026-09-12
