---
description: "Task list for スキルとエージェントの配置判断フロー"
---

# Tasks: スキルとエージェントの配置判断フロー

**Feature**: `001-placement-decision-flow`

**Input**: Design documents from `/specs/001-placement-decision-flow/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: 本リポジトリの憲章「V. Test-First & Non-Vacuous Tests」により、実行可能なロジック
（シェルスクリプト・判定コード・探索処理）のテストは**必須**です。各ストーリーで、テストは
実装より先に書き、**失敗することを確認**してから実装します。実装後は対象コードに変異を加えて
テストが失敗することを実測してください（原則 V）。

**Organization**: タスクはユーザーストーリー単位で構成し、各ストーリーを独立して実装・
テストできるようにします。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（別ファイル・未完了タスクへの依存なし）
- **[Story]**: 対応するユーザーストーリー（US1 / US2 / US3）
- すべてのタスクに具体的なファイルパスを記載

## Path Conventions

本機能は単一プラグイン構成です（[plan.md](./plan.md) の Structure Decision）。

- 配布物: `plugins/placement-decision-flow/`
- スキル資材: `plugins/placement-decision-flow/skills/placement-decision-flow/`
- 検証: `plugins/placement-decision-flow/tests/`
- 設計文書: `specs/001-placement-decision-flow/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: プラグインの骨格と契約ファイルを作成する

- [X] T001 `plugins/placement-decision-flow/` 配下のディレクトリ構造を作成する（`skills/placement-decision-flow/scripts/`、`skills/placement-decision-flow/references/`、`tests/fixtures/repo/.github/skills/code-review/`、`tests/fixtures/repo/plugins/sample-plugin/skills/sample-skill/`）
- [X] T002 [P] `plugins/placement-decision-flow/plugin.json` を作成する（`contracts/skill-frontmatter.md` §1 と完全一致させる。`$schema` / `name: placement-decision-flow` / `version: 1.0.0` / `description` / `author` のみ。閉じたスキーマのため他キーを追加しない）
- [X] T003 [P] `plugins/placement-decision-flow/README.md` を作成する（プラグインの目的、前提条件（bash 3.2+ / `git` / `find`・`sed`・`grep`・`sort`、追加依存なし・ネットワーク不要）、`tests/run.sh` の実行方法、`chmod +x` の必要性を記載）
- [X] T004 `.github/plugin/marketplace.json` の `plugins` 配列に `placement-decision-flow` のエントリを追加する（`source: plugins/placement-decision-flow`、`version: 1.0.0`。既存 2 エントリは変更せず、`name` 昇順の並びを保つ）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: すべてのストーリーが依存するテスト基盤。**このフェーズが完了するまでストーリー実装を開始しない**

- [X] T005 `plugins/placement-decision-flow/tests/run.sh` を作成する（`tests/test_*.sh` をディレクトリ探索で自動収集して順に実行し、成功・失敗件数を集計。失敗があれば非ゼロで終了。テスト実行ビットの確認も行う）
- [X] T006 [P] 探索テスト用のフィクスチャを作成する。`plugins/placement-decision-flow/tests/fixtures/repo/.github/skills/code-review/SKILL.md`（`name: code-review`）と `plugins/placement-decision-flow/tests/fixtures/repo/plugins/sample-plugin/skills/sample-skill/SKILL.md`（`name: sample-skill`）。両方の `description` に `Use when:` トリガーを含め、`--query` フィルタのテストで片方だけが一致する語（例: `review`）を入れる
- [X] T007 [P] `plugins/placement-decision-flow/tests/test_manifest.sh` を作成する（`contracts/skill-frontmatter.md` の検証規則のうち、**Phase 2 の時点で対象ファイルが存在するものだけ**を固定する。`plugin.json` の `$schema` 完全一致・`name` パターン・必須キーのみの構成（P-1〜P-6）、`plugin.json` と `marketplace.json` の `name`/`version` 一致と `source` の実在（M-1〜M-2）。**`SKILL.md` の検証（S-1〜S-3 / S-5）はここに含めず T015 で追加する**（`SKILL.md` は Phase 3 で作られるため、ここで書くと Phase 2 の Checkpoint が満たせなくなる））
- [X] T008 `plugins/placement-decision-flow/tests/test_runner.sh` を作成する（`tests/` に一時的な `test_zz_probe.sh` を作成して `run.sh` を実行し、**新規に追加したテストファイルが探索されて実行される**ことを固定する。探索されない場合に失敗する。検証は一時ファイルを削除して元に戻す）

**Checkpoint**: `bash plugins/placement-decision-flow/tests/run.sh` が動作し、T007/T008 が pass する。**Phase 2 のテストは Phase 1・2 の成果物だけで pass できること**（Phase 3 以降の成果物に依存しないこと）を確認し、ストーリー実装を開始できる

---

## Phase 3: User Story 1 - 新しい処理の置き場所を一度の相談で決める (Priority: P1) 🎯 MVP

**Goal**: 追加しようとしている処理を自然文で伝えると、4 分類（オーケストレーター／
サブエージェント定義／スキルの手順／スキルの実行コード）のいずれかが理由つきで確定し、
情報が足りなければ問い返し、既存スキルに重なるものがあれば再利用候補が示される。

**Independent Test**: `spec.md` US1 の受入シナリオ 1〜8 を個別に実行して確認する。特に
「代表的な 4 種類の処理で期待する配置先が返る」「情報不足で `result=ask` が返る」
「`.github/skills/` 配下も `plugins/` 配下も再利用候補として拾える」「指名なしでは起動しない」
の 4 点が単独で成立すること。

### Tests for User Story 1

> **NOTE: 実装より先に書き、失敗することを確認する**

- [X] T009 [P] [US1] `plugins/placement-decision-flow/tests/test_decide.sh` を作成する（`contracts/decide-cli.md` §7 の不変条件 C-1〜C-8 を固定する。対象は **FR-002**（選択肢が 4 値に限る）/ **FR-006**（不足時は問い返す）/ **FR-008**（同じ入力なら同じ判断）/ **FR-012**（保留のまま終わらない）/ **FR-016**（構造化入力と機械可読出力）。ガバナンス以外の 4 分類、`result=ask` と `missing`、不正な値・不明なオプション・重複指定で exit 2 と stdout 空、同じ入力の 2 回実行で stdout が byte 一致、出力に ASCII 以外が含まれないこと。**非ガバナンスのケースでは `--governance no` を明示的に渡す**。加えて、4 分類それぞれについて**完全な回答を 1 回渡すだけで `result=decision` が返る**こと（`result=ask` を経由せずに配置先が確定すること）も固定する（**SC-004a**: 1 往復で確定する）。同一のテストで **SC-001**（4/4 が 1 回で確定）/ **SC-006**（実行ディレクトリを変えても同じ出力）/ **SC-007**（不足時に推測で断定せず `result=ask` を返す）もあわせて測定する）
- [X] T010 [P] [US1] `plugins/placement-decision-flow/tests/test_criteria_sync.sh` を作成する（`references/criteria.md` の判断表を**ヘッダ行から列構成を動的に読み取り**、各行を `decide.sh` に流して `target` / `reason` を照合する。`*` の列には `yes` / `no` / `unknown` の 3 値を流し込み `target` が変わらないことを確認。**列が増えてもテスト本体の修正が不要な構造**にすること。これが FR-017 の強制手段になる）
- [X] T011 [P] [US1] `plugins/placement-decision-flow/tests/test_find_skills.sh` を作成する（`contracts/find-skills-cli.md` §7 の不変条件 F-1〜F-3 / F-5〜F-6 / F-9 を固定する。対象は **FR-009**（再利用候補の列挙）/ **FR-010**（特定のディレクトリ構成に依存しない）。フィクスチャの 2 件がタブ区切りの**リポジトリ相対パス**でパス昇順に出力される、`--query` の部分一致で絞り込まれる、0 件で exit 0 かつ stdout が空、`.github/skills/` が検出される、`.git` / `node_modules` / `tmp` が除外される、`LC_ALL` を変えてもソート順が変わらない。**SC-003**（重複配置 0 件）は「重なる既存スキルを候補として必ず列挙し、見逃さないこと」で支えるため、`.github/skills/` と `plugins/*/skills/` の両方から候補が出ることも固定する）

### Implementation for User Story 1

- [X] T012 [US1] `plugins/placement-decision-flow/skills/placement-decision-flow/references/criteria.md` に**判断表**を固定書式で作成する（[plan.md](./plan.md) の 6 列 `governance | orchestration | reusable | needs_code | target | reason` と 5 行。`*` の意味を明記。この表は T010 がパースするため書式を変えない）
- [X] T013 [US1] `plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh` を実装する（`contracts/decide-cli.md` §1〜§6 に従う。**FR-001 / FR-016** の実装本体。`--governance` / `--orchestration` / `--reusable` / `--needs-code` の 4 オプション、`yes`/`no`/`unknown` の 3 値検証、評価順序 `governance → orchestration → reusable → needs_code` の短絡、`result=decision`（`target` / `reason` / `branches`）と `result=ask`（`missing`）の 2 分岐出力、不正入力は exit 2。**`declare -A` を使わず `case` 文で実装**し、パスは `SCRIPT_DIR` 基準で解決する。`chmod +x` する）
- [X] T014 [US1] `plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh` を実装する（`contracts/find-skills-cli.md` §1〜§6 の**通常モードのみ**（`--detect-conventions` は T023）。`--root` / `--query` / `--exclude` の解決、リポジトリルートの決定（`git rev-parse --show-toplevel` → カレントディレクトリ）、除外ディレクトリの `-prune`、ドット始まりを除外しない扱い、フロントマターの `name`/`description` 抽出、`description` のタブ・改行の正規化、パス昇順ソート。`chmod +x` する）
- [X] T015 [US1] `plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md` を作成する（フロントマターは `contracts/skill-frontmatter.md` §2 と一致させ、`name` を親ディレクトリ名と一致させる。本文に実行手順を書く: 起動は**明示指名のみ**・文脈による自動起動をしない（FR-018 / FR-019）、自然文から 4 分岐の回答を抽出する（FR-013）、`decide.sh` を実行して AI の判断を検証し食い違えば**矛盾として提示**する（FR-014 / FR-015、基準の正はコード側）、`find-skills.sh` の候補がある場合のみ再利用を提案する（FR-009）、**複数の処理がまとめて提示された場合は 1 件ずつ `decide.sh` を実行し、独立した判断結果を返す**（`research.md` R-5。1 つの配置先に丸めない）、判断を保留したまま終わらない（FR-012）。500 行未満に収める。**あわせて `tests/test_manifest.sh` に `SKILL.md` の検証（S-1: `name` が親ディレクトリ名と一致、S-2: 名前の文字種と長さ、S-3: `description` の長さ、S-5: `Use when:` トリガーの有無）を追記して pass させる** — T007 は Phase 2 の成果物だけを検証するため、`SKILL.md` の検証はここで追加する）
- [X] T016 [US1] 変異探針でテストの非空虚性を実測する（`decide.sh` のガバナンス短絡を外す / `find-skills.sh` のソートを外す / `criteria.md` の 1 行を書き換える の 3 種を順に適用し、それぞれで T009〜T011 が**失敗する**ことを確認する。各変異は `/tmp` に退避して復元し、**復元後にフルスイートを再実行して全 pass に戻る**ことまでを 1 セットとする）

**Checkpoint**: `bash plugins/placement-decision-flow/tests/run.sh` が全 pass。`quickstart.md` の検証 1・3・4・5・6 が期待どおりの結果になる。US1 単独で MVP として成立する

---

## Phase 4: User Story 2 - ガバナンス項目をスキルに紛れ込ませない (Priority: P2)

**Goal**: 実行前検証・権限・外部接続を追加するとき、使い回せるかどうかに関係なく
サブエージェント定義側だと判断され、その理由（発火の保証がない）が示される。

**Independent Test**: ガバナンス 3 項目（実行前検証・権限・外部接続）をそれぞれ提示し、いずれも
スキルではなくサブエージェント定義側だと返ることを確認する。加えて「全サブエージェントで
使い回したい実行前検証」を提示し、**再利用できることを理由にスキルへ流れない**
（FR-022）ことを確認する。

> **依存の注記**: 判定エンジン（`decide.sh` の評価順序）は US1 の T013 で完成する。US2 の
> 成果は「ガバナンスの判定が**保証として文書化され、網羅的に検証される**」ことにあり、
> これが無い状態では SC-002 / SC-010 が偶然の一致に依存する。

### Tests for User Story 2

- [X] T017 [P] [US2] `plugins/placement-decision-flow/tests/fixtures/governance-cases.tsv` を作成する（`入力(TSV)\t期待target\t期待reason` の形式。ガバナンス 3 項目それぞれの代表ケース、`governance=yes` × `reusable` の 3 値、`governance=yes` × `needs_code` の 3 値、`governance=unknown` で `result=ask` になるケースを含める）
- [X] T018 [US2] `plugins/placement-decision-flow/tests/test_governance.sh` を作成する（**実装より先に書き、失敗することを確認**。対象は **FR-005** / **FR-021** / **FR-022**。T017 のケースを全件流し、`target` / `reason` が期待どおりであること、`governance=yes` のとき `branches` に `reusable` / `needs_code` が**現れない**こと（短絡の証明）、`missing=governance` が評価順の最初に現れることを検証。SC-002（スキルへの誤判定 0 件）と SC-010（順序依存のぶれ 0 件）を直接測る）

### Implementation for User Story 2

- [X] T019 [US2] `references/criteria.md` に**ガバナンスの節**を追記する（`contracts/skill-frontmatter.md` §3 の R-3。実行前検証・権限・外部接続の 3 分類、それぞれがサブエージェント定義側になる理由（エージェント定義の構造に属し、スキル側には発火の保証がない）、「使い回せるからスキル」と判断してはならないこと（FR-022）。**判断表の書式は変更しない**）
- [X] T020 [US2] `SKILL.md` に**ガバナンスの節**を追記する（ガバナンス該当時は `reusable` の結果にかかわらず定義側と確定することを明示。手順とガバナンスの両方の性質を持つ処理では**分割案**を示す（手順はスキル、検証・権限・接続は定義）。`spec.md` の Edge Case「複数の性質を併せ持つ処理」「ガバナンスにも該当し、かつ複数で使い回せる」に対応）
- [X] T021 [US2] 変異探針で T018 の非空虚性を実測する（`decide.sh` のガバナンスゲートを `orchestration` の**後ろ**に移動する、および `governance=yes` のときに `reusable` を評価するよう変更する。それぞれで T018 が**失敗する**ことを確認。復元後に**フルスイートを再実行して全 pass に戻る**ことまでを 1 セットとする）

**Checkpoint**: `tests/test_governance.sh` を含む全テストが pass。ガバナンス 3 項目が
スキルと判定される経路が存在しないことがテストで固定されている

---

## Phase 5: User Story 3 - 判断の根拠と次の一歩を得る (Priority: P3)

**Goal**: 判断結果に加えて、適用された分岐と、配置先で具体的に何をどこに書けばよいかが示される。

**Independent Test**: 任意の処理を提示し、(1) どの分岐をどの順で通ったかが示されること、
(2) 配置先がスキルのときに **手順は `SKILL.md`・実行コードは `scripts/`** という区別と、
対象リポジトリの慣習に沿った**リポジトリ相対パス**が示されること、を確認する。

### Tests for User Story 3

- [X] T022 [P] [US3] `plugins/placement-decision-flow/tests/test_conventions.sh` を作成する（**実装より先に書き、失敗することを確認**。`contracts/find-skills-cli.md` §7 の不変条件 F-4 / F-7 / F-8 を固定。常に 4 行を出力し、各行が `layer\tpath\texists` の形式であること、`exists` が `yes`/`no` のいずれかであること、`layer` → `path` の昇順であること、`--root` を一時ディレクトリに変えても結果が同じであること、実行前後で対象ツリーのハッシュが変わらないこと）

### Implementation for User Story 3

- [X] T023 [US3] `find-skills.sh` に `--detect-conventions` モードを実装する（`contracts/find-skills-cli.md` §3.2。`skill`: `.github/skills/`・`plugins/*/skills/`、`subagent`: `.github/agents/`・`.claude/agents/` の 4 件を実在確認して**常に 4 行**出力する。`layer` → `path` の昇順。T022 が pass することを確認）
- [ ] T024 [US3] `references/criteria.md` に**解説の節**を追記する（`contracts/skill-frontmatter.md` §3 の R-1 / R-5。評価順序がこの順である理由（ガバナンスを先に置くのは発火の保証を最優先にするため）、`*` が「その列を評価しない」を意味すること、主要な公式設計（Anthropic / OpenAI / Microsoft / Google ADK / LangGraph）の指針と矛盾しないことの説明（FR-011））
- [ ] T025 [US3] `SKILL.md` に**提示フォーマットの節**を追記する（`research.md` R-4。`decide.sh` の `key=value` を日本語の文章として提示し、**適用した分岐と理由**を含める（FR-004 / SC-005）、配置先がスキルのときは**手順は `SKILL.md`・実行コードは `scripts/`** の区別を明示する（FR-003）、`--detect-conventions` の結果に沿った**リポジトリ相対パス**を示し、検出できない場合は役割と目安を併記する（FR-007 / FR-020）。**リポジトリ外のパスを示さない**ことを明記する）
- [ ] T026 [US3] 変異探針で T022 の非空虚性を実測する（`plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh` の `--detect-conventions` について、(a) `exists` 判定を常に `yes` に固定する、(b) 出力を 3 行に減らす、の 2 種を順に適用し、それぞれで T022 が**失敗する**ことを確認する。各変異は `/tmp` に退避して復元し、**復元後にフルスイートを再実行して全 pass に戻る**ことまでを 1 セットとする）

**Checkpoint**: `quickstart.md` の検証 7 が期待どおりになり、US1・US2・US3 がそれぞれ独立に成立する

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 複数ストーリーにまたがる確認と仕上げ

- [ ] T027 [P] `plugins/placement-decision-flow/README.md` に利用方法を追記する（`SKILL.md` の起動が**明示指名のみ**であること、`decide.sh` / `find-skills.sh` の役割、`references/criteria.md` を判断基準の正とすることを記載）
- [ ] T028 `quickstart.md` の検証 1〜11 を順に実行し、各検証の実際の出力を記録する（期待結果と異なる箇所は、実装を直すか `quickstart.md` を直すかを判断して反映する）
- [ ] T029 `plugins/placement-decision-flow/tests/test_criteria_sync.sh` が**判断表の変更を実際に検出する**ことを最終確認する（`criteria.md` の `target` を 1 つ書き換えて失敗することを確認し、復元後にフルスイートが全 pass に戻ることを確認。FR-017 の実効性の最終的な裏付け）
- [ ] T030 `bash plugins/placement-decision-flow/tests/run.sh` でフルスイートを実行し、全テストが pass することを確認する（T016 / T021 / T026 / T029 / T033 の変異が残っていないことを `git status` と `git diff` で確認してから実行する）
- [ ] T031 [P] `SKILL.md` の最終確認を行う（500 行未満、資材への参照がスキルルートからの相対パスで 1 階層まで、`description` に `Use when:` トリガーがあること、`name` が親ディレクトリ名と一致することを確認。`tests/test_manifest.sh` が pass する）
- [ ] T032 [P] `plugin.json` と `.github/plugin/marketplace.json` の整合を最終確認する（`name` / `version` / `source` の一致。既存 2 プラグインのエントリが変更されていないことを `git diff` で確認）
- [ ] T033 `plugins/placement-decision-flow/tests/test_constitution.sh` を作成する（**憲章 I / VII の実装規律を機械的に固定する**。配布スクリプト `decide.sh` / `find-skills.sh` に `declare -A` が含まれないこと（bash 3.2 互換・憲章 VII）、`../../` によるプラグイン境界の越境参照が無いこと（憲章 I）、環境固有の絶対パス（`/home/` `/Users/` など）が埋め込まれていないこと（憲章 VII）、両スクリプトが `SCRIPT_DIR` 基準で自身の位置を解決していること（憲章 I）。**変異探針**: `decide.sh` に `declare -A` を 1 行挿入すると失敗することを実測し、復元後にフルスイートが全 pass に戻ることを確認する）
- [ ] T034 `plugins/placement-decision-flow/tests/test_performance.sh` を作成する（**SC-004a / SC-004b を実測可能な形で固定する**。SC-004b: `decide.sh` の実行時間を秒精度で計測し 1 秒未満であることを固定する。SC-004a: 4 分類それぞれの**完全な入力**を 1 回だけ渡したときに `result=decision` が返ること、すなわち追加の問い返し 0 回で配置先が確定することを固定する。`result=ask` を許容するのは回答に `unknown` を含むケースだけに限り、それ以外で `result=ask` が返れば失敗させる）

---

## Phase 7: 受け入れ確認（人手による検証）

**Purpose**: bash テストで駆動できない AI の挙動を人手で確認し、観測結果を記録する

> `spec.md` の FR-015 / FR-018 / FR-019 と SC-008 / SC-009 は、スキルとして起動したときの
> **AI の振る舞い**であり、シェルスクリプトのテストでは固定できない。`quickstart.md` の手順に
> 従って人手で確認し、観測結果を記録する（憲章 IV: 主張には観測結果を添える）。

- [ ] T035 `quickstart.md` の**検証 12** を実行する（**指名なしでは起動しない**。判断が必要そうな文脈を含む別の作業依頼を投げ、判断フローが自動起動せず作業が中断されないことを確認する。FR-018 / FR-019 / SC-009）
- [ ] T036 `quickstart.md` の**検証 13** を実行する（**矛盾が提示される**。`decide.sh` の結論と異なる配置先を AI が結論した状況を作り、黙って一方を採用せず矛盾として提示されることを確認する。FR-015 / SC-008）
- [ ] T037 [P] T035 / T036 の観測結果を `quickstart.md` の「人手確認の記録」に追記する（確認した入力・観測した挙動・判定を残す）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし。即時開始可能
- **Foundational (Phase 2)**: Setup の完了に依存（T005 は T001 のディレクトリを、T007 は T002 / T004 の成果物を参照する。**Phase 2 のテストは Phase 1・2 の成果物だけで pass できるようにする**。Phase 3 以降で作られる `SKILL.md` の検証は T007 に含めず T015 で追加する）
- **User Stories (Phase 3〜5)**: Foundational の完了に依存
- **Polish (Phase 6)**: 対象とする全ストーリーの完了に依存
- **受け入れ確認 (Phase 7)**: Phase 6 の完了に依存（配布物が確定し、機械的に検証できる範囲がすべて pass した状態で人手確認する）

### Within Each Story

- テストを先に書き、**失敗することを確認**してから実装する（憲章 V）
- 変異探針は実装直後に実施し、**復元後のフルスイート再実行**までを 1 セットとする

### Story Dependencies

- **US1 (P1)**: Foundational 完了後に開始可能。他ストーリーへの依存なし。**判定エンジン
  （`decide.sh`）と判断表（`criteria.md`）を完成させる**のはこのストーリー
- **US2 (P2)**: Foundational 完了後に開始可能。**判定エンジンは US1 の T013 で完成する**ため、
  US2 の実装（T019 / T020）とテスト実行（T018 / T021）は T013 の完了を待つ。US2 が加えるのは
  ガバナンスの**保証（網羅テスト）と説明（criteria.md / SKILL.md）**であり、US1 のテストは
  変更しない。US1 の `test_decide.sh` は非ガバナンスのケースで `--governance no` を明示的に
  渡すため、US2 の追加後も影響を受けない
- **US3 (P3)**: Foundational 完了後に開始可能。`--detect-conventions` は `find-skills.sh` への
  **追加モード**であり、US1 の `test_find_skills.sh` はこのモードを呼ばないため影響を受けない

> **US2 と US3 の直列化（重要）**: US2 と US3 は**同じ 2 ファイルに追記する**
> （`criteria.md`: T019 と T024、`SKILL.md`: T020 と T025）。ストーリーとしては独立だが
> **ファイルを共有するため同時に編集すると競合する**。US2 を完了させてから US3 に着手するか、
> 同一作業者が順に適用すること。T019 / T020 / T024 / T025 には `[P]` を付けない。

### Parallel Opportunities

- T002 / T003 は並列実行可能（別ファイル）
- T006 / T007 は T001 / T002 の完了後に並列実行可能（T007 は `plugin.json` / `marketplace.json` のみを対象にし、`SKILL.md` の検証は含めない）
- T009 / T010 / T011 は並列実行可能（別ファイル。ただし T009 / T010 の**実行**は T012 / T013 の後）
- T017 は T013 の完了後に単独で着手可能
- T022 は T014 の完了後に単独で着手可能
- T027 / T031 / T032 / T037 は並列実行可能（別ファイル）
- **T019 / T020 と T024 / T025 は並列にできない**（`criteria.md` と `SKILL.md` を共有する。`[P]` を付けていないのはこのため）

---

## Parallel Example: User Story 1

```bash
# US1 のテストを 3 本まとめて起案する（実装前に失敗を確認する）
Task: "T009 plugins/placement-decision-flow/tests/test_decide.sh を作成"
Task: "T010 plugins/placement-decision-flow/tests/test_criteria_sync.sh を作成"
Task: "T011 plugins/placement-decision-flow/tests/test_find_skills.sh を作成"

# 失敗を確認したあと、判定表と 2 本のスクリプトを実装する
# （T012 / T013 は criteria.md と decide.sh で別ファイル。T014 は決定後）
Task: "T012 references/criteria.md に判断表を作成"
Task: "T014 scripts/find-skills.sh を実装"
```

```bash
# US3 で find-skills.sh に追加モードを実装するときは、先にテストを起案して失敗を確認する
Task: "T022 plugins/placement-decision-flow/tests/test_conventions.sh を作成"
# 失敗を確認してから T023 で --detect-conventions を実装する
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup を完了する
2. Phase 2: Foundational を完了する（**全ストーリーをブロックする**）
3. Phase 3: User Story 1 を完了する
4. **STOP and VALIDATE**: `quickstart.md` の検証 1・3・4・5・6 で US1 を単独検証する
5. ここで「新しい処理の置き場所が 1 回の相談で決まる」という中心価値が成立する

### Incremental Delivery

1. Setup + Foundational → 基盤完成
2. US1 → 独立検証 → **MVP**（配置判断ができる）
3. US2 → 独立検証 → ガバナンスの安全が保証される
4. US3 → 独立検証 → 根拠と具体的な次の一歩が得られる
5. Polish → `quickstart.md` の全検証、憲章 I/VII の機械検証、性能計測で仕上げる
6. 受け入れ確認 → 指名なし起動と矛盾提示を人手で確認し記録する

### Notes

- タスク ID は実行順に連番。`[P]` は別ファイル・依存なしの並列可能タスク
- 各 Story の Checkpoint でフルスイートを通し、そのストーリーが独立に成立することを確認する
- 変異探針は必ず「`/tmp` に退避 → 変異 → テスト実行 → 復元 → **フルスイート再実行**」の順で行う
- **受け入れ確認（Phase 7）は必須**。SC-008 / SC-009 は機械的に測れないため、人手確認の
  記録が無い限り当該 Success Criterion は未検証として扱う（憲章 IV）
