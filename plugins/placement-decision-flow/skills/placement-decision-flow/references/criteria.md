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
