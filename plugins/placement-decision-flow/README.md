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
