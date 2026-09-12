# 配置判断の基準

このドキュメントは、スキルとエージェントの配置判断における**判断基準の単一の真実源**です。
判定コード（`scripts/decide.sh`）はこの表と同じ規則を実装しており、
`tests/test_criteria_sync.sh` が両者の一致を強制します。

## 判断表

| governance | orchestration | reusable | needs_code | target | reason |
|---|---|---|---|---|---|
| yes | * | * | * | subagent-definition | governance |
| no | yes | * | * | orchestrator | orchestration |
| no | no | yes | yes | skill-scripts | reusable-with-code |
| no | no | yes | no | skill-instructions | reusable-instructions |
| no | no | no | * | subagent-definition | not-reusable |

`*` は「その列を評価しない」を意味します。評価順序による短絡（先行するゲートで確定したら
後続を評価しない）を表します。

- 列は左から順に評価します。評価順序は `governance` → `orchestration` → `reusable` →
  `needs_code` です
- 上から順に、最初に一致した行が適用されます
- `target` は配置先、`reason` は配置先を確定させた規則の識別子です
- `governance` が `yes` のときは、`reusable` が `yes` でも `subagent-definition` に確定します

## ガバナンス項目はサブエージェント定義に置く

`governance=yes` の判定対象になるのは、次の 3 分類です。

| 分類 | 具体例 | 回答 |
|---|---|---|
| 実行前検証 | 実行前に秘密情報が含まれていないか検査する | `yes` |
| 権限 | ツール実行やファイル変更の許可を扱う | `yes` |
| 外部接続 | 外部 API の呼び出しや認証を伴う | `yes` |

いずれも、他のサブエージェントでも使い回したい処理です。しかし**使い回せることを理由に
スキルへ流してはなりません**（FR-022）。判断表の 1 行目の `reusable` が `*` なのは、この
規則を表しています。

### なぜ定義側なのか

ガバナンスは「いつ発火するか」の保証を必要とします。サブエージェント定義は起動条件・
利用可能なツール・権限を構造として持つため、**必ず通る**ことを保証できます。一方スキルは
呼び出し側の裁量で発火するため、発火しない経路が残ります。実行前検証や権限確認が
「たまたま実行された」ことに依存してしまうため、ガバナンスは定義側に置きます。

これは「どちらが便利か」ではなく「発火の保証があるか」で決まります。したがって
`reusable` / `needs_code` の値は結論を変えません。

### 手順とガバナンスの両方を持つ処理

1 つの処理が「使い回せる手順」と「ガバナンス」の両方を持つ場合は、**分割**して扱います。
手順の部分はスキル（`skill-instructions` / `skill-scripts`）に、検証・権限・接続の部分は
サブエージェント定義に置き、定義側からスキルを呼び出す構造にします。
