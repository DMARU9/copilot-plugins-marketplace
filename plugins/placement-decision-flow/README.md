# placement-decision-flow

「新しい処理をどこに置くか」を、オーケストレーター／サブエージェント定義／スキルの3層から
決定的に判定する共通スキルです。

## 目的

オーケストレーター・サブエージェント・スキルの3層でエージェントを組み立てていると、
新しい処理を書き始めるたびに「これはどこに置くのか」で手が止まります。判断を誤ると、
同じスクリプトが複数のサブエージェント配下に重複して置かれ、修正が散らばります。

このプラグインは、その判断基準を**誰でも同じ結果になる形で呼び出せる**ようにします。
判断基準を文書（`references/criteria.md`）と判定コード（`scripts/decide.sh`）の両方で持ち、
両者をテストで同期させるため、担当者やセッションが変わっても同じ配置先が導かれます。

## 前提条件

| 項目 | 要件 |
|---|---|
| シェル | bash 3.2 以上（macOS 標準の bash でも動作します。配布スクリプトは `declare -A` を使いません） |
| コマンド | `git`、`find`、`sed`、`grep`、`sort` |
| 追加依存 | なし |
| ネットワーク | 不要（オフラインで完結します） |

## 構成

```text
plugins/placement-decision-flow/
├── plugin.json
├── README.md
├── tests/                                  # 配布元での検証
│   ├── run.sh                              # テストランナー（tests/test_*.sh を探索して実行）
│   └── test_*.sh
└── skills/
    └── placement-decision-flow/
        ├── SKILL.md                        # 手順と起動トリガー
        ├── scripts/
        │   ├── decide.sh                   # 判定コード
        │   └── find-skills.sh              # 既存スキル探索
        └── references/
            └── criteria.md                 # 判断表（判断基準の単一の真実源）
```

## 使い方

### 1. スキルとして使う（通常の使い方）

`SKILL.md` を読んだクライアント（AI エージェント）が手順を実行します。

```bash
# 判定コードで配置先を確定する
bash skills/placement-decision-flow/scripts/decide.sh \
  --governance no --orchestration no --reusable yes --needs-code yes

# 明示的に指名されたときだけ起動する（FR-018 / FR-019）
```

**このスキルは明示指名でのみ起動します。** 文脈から判断が必要そうに見えても、利用者や
上位のエージェントから指名されない限り自動起動しません。他の作業の途中に判断が割り込むと、
「判断で止まる時間を減らす」という目的に逆行するためです。

### 2. 判定コードだけを使う

`scripts/decide.sh` は単体でも使えます。4 つの質問に `yes` / `no` / `unknown` で答え、
配置先を機械可読な `key=value` で受け取ります。

```bash
bash skills/placement-decision-flow/scripts/decide.sh \
  --governance yes --orchestration no --reusable yes --needs-code no
# result=decision
# target=subagent-definition
# reason=governance
# branches=governance=yes
```

回答が足りない場合は、評価順で最初の不明な質問を `result=ask` / `missing=<質問名>` として
返します。推測で断定しません（FR-006 / FR-012）。

### 3. 既存スキルを探す

`scripts/find-skills.sh` は、対象リポジトリの `SKILL.md` を探索して**再利用候補**を列挙します。

```bash
bash skills/placement-decision-flow/scripts/find-skills.sh --query review
# <リポジトリ相対パス>\t<name>\t<description>

# 慣習ディレクトリの実在確認（常に 4 行）
bash skills/placement-decision-flow/scripts/find-skills.sh --detect-conventions
# skill    .github/skills/     yes
# skill    plugins/*/skills/   yes
# subagent .claude/agents/     no
# subagent .github/agents/     no
```

読み取り専用です。対象リポジトリに一切書き込みません（FR-020）。

## 役割の分担

| 成果物 | 役割 |
|---|---|
| `skills/placement-decision-flow/SKILL.md` | 手順と起動トリガー。起動は明示指名のみ |
| `skills/placement-decision-flow/scripts/decide.sh` | 判定コード。AI の判断を機械的に検証する |
| `skills/placement-decision-flow/scripts/find-skills.sh` | 既存スキル探索と慣習ディレクトリの実在確認 |
| `skills/placement-decision-flow/references/criteria.md` | **判断基準の正**（単一の真実源） |

判断基準の**正は `references/criteria.md`**（と、それを実装した `decide.sh`）です。
`SKILL.md` や README の記述と食い違った場合は、`criteria.md` と `decide.sh` の結論を
採用してください。両者が食い違っていること自体は `tests/test_criteria_sync.sh` が
検出します（FR-017）。

## テストの実行

テストを実行する前に、実行ビットを立ててください。

```bash
chmod +x plugins/placement-decision-flow/tests/run.sh \
         plugins/placement-decision-flow/tests/test_*.sh \
         plugins/placement-decision-flow/skills/placement-decision-flow/scripts/*.sh
```

プラグインのルートから次のコマンドで実行します。

```bash
bash plugins/placement-decision-flow/tests/run.sh
```

`tests/run.sh` は `tests/test_*.sh` をディレクトリ探索で自動収集して順に実行し、
成功・失敗件数を集計します。失敗が 1 件でもあれば非ゼロで終了します。

> `chmod +x` は必須です。テストランナーは実行ビットの有無も確認します。
