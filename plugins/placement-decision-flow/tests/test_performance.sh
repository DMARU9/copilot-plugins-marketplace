#!/usr/bin/env bash
# test_performance.sh — SC-004a / SC-004b を実測可能な形で固定する（T034）
#
# 対象要件: SC-004a（完全な回答を 1 回渡せば配置先が確定する＝追加の問い返し 0 回）
#           SC-004b（判定コードの実行時間が 1 秒未満）
#
# SC-004a の判定規則:
#   - 4 分類それぞれの**完全な入力**を 1 回だけ渡したとき、`result=decision` と
#     期待した `target` が 1 行ずつ返ること（`result=` の行が複数出たら 1 回で確定
#     していないとみなす）
#   - `result=ask` を許容するのは、渡した回答に `unknown` を含む場合だけ。
#     それ以外の入力（`yes` / `no` のみの全 16 通り）で `result=ask` が返れば失敗
#
# SC-004b の計測は bash の SECONDS（秒精度）で行う。追加の計測ツールを持ち込まない
# （憲章 VII: 追加依存なし）。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DECIDE="$PLUGIN_DIR/skills/placement-decision-flow/scripts/decide.sh"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_performance.sh ==="

if [ ! -x "$DECIDE" ]; then
    ng "decide.sh が実行可能ファイルとして存在する（$DECIDE）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi
ok "decide.sh が実行可能ファイルとして存在する"

# ---------- SC-004a: 4 分類が 1 回の入力で確定する ----------

targets_seen=""
case_no=0
while IFS='|' read -r label expected args; do
    [ -n "$label" ] || continue
    case_no=$((case_no + 1))

    out=$("$DECIDE" $args 2>/dev/null)
    status=$?

    result_lines=$(printf '%s\n' "$out" | grep -c '^result=' || true)
    got_result=$(printf '%s\n' "$out" | sed -n 's/^result=//p')
    got_target=$(printf '%s\n' "$out" | sed -n 's/^target=//p')

    if [ "$status" -eq 0 ] &&
       [ "$result_lines" -eq 1 ] &&
       [ "$got_result" = "decision" ] &&
       [ "$got_target" = "$expected" ]; then
        ok "PF-1.$case_no $label: 1 回の入力で result=decision / target=$expected"

        case " $targets_seen " in
        *" $got_target "*) : ;;
        *) targets_seen="$targets_seen $got_target" ;;
        esac
    else
        ng "PF-1.$case_no $label: 1 回の入力で確定しない（exit=$status result=${got_result:-なし}(${result_lines} 行) target=${got_target:-なし} 期待=$expected）"
    fi
done <<'CASES'
ガバナンス該当|subagent-definition|--governance yes
オーケストレーション|orchestrator|--governance no --orchestration yes
再利用（コード付き）|skill-scripts|--governance no --orchestration no --reusable yes --needs-code yes
再利用（手順のみ）|skill-instructions|--governance no --orchestration no --reusable yes --needs-code no
CASES

# 4 分類が実際に異なる target を生んでいること（フィクスチャが同じ答えに潰れていない）
distinct=$(printf '%s\n' $targets_seen | grep -c . || true)
if [ "$distinct" -eq 4 ]; then
    ok "PF-2 4 分類が互いに異なる target を返す（$targets_seen）"
else
    ng "PF-2 4 分類が互いに異なる target を返さない（${distinct} 種類: $targets_seen）"
fi

# ---------- SC-004a: unknown を含まない入力では ask を返さない ----------

checked=0
ask_count=0
ask_example=""
missing_count=0
missing_example=""

for governance in yes no; do
    for orchestration in yes no; do
        for reusable in yes no; do
            for needs_code in yes no; do
                checked=$((checked + 1))
                args="--governance $governance --orchestration $orchestration"
                args="$args --reusable $reusable --needs-code $needs_code"

                out=$("$DECIDE" $args 2>/dev/null)

                if printf '%s\n' "$out" | grep -q '^result=ask'; then
                    ask_count=$((ask_count + 1))
                    [ -n "$ask_example" ] || ask_example="$args"
                fi
                if printf '%s\n' "$out" | grep -q '^missing='; then
                    missing_count=$((missing_count + 1))
                    [ -n "$missing_example" ] || missing_example="$args"
                fi
            done
        done
    done
done

if [ "$checked" -eq 16 ] && [ "$ask_count" -eq 0 ]; then
    ok "PF-3 unknown を含まない 16 通りの入力すべてで result=ask を返さない"
else
    ng "PF-3 unknown を含まない入力で result=ask を返した（$ask_count/$checked 件・例: $ask_example）"
fi

if [ "$missing_count" -eq 0 ]; then
    ok "PF-4 unknown を含まない入力では missing= を返さない（問い返し 0 回）"
else
    ng "PF-4 unknown を含まない入力で missing= を返した（$missing_count 件・例: $missing_example）"
fi

# ---------- SC-004a: unknown を含む入力では ask が許容される ----------

ask_out=$("$DECIDE" --governance unknown 2>/dev/null)
ask_status=$?
if [ "$ask_status" -eq 0 ] && printf '%s\n' "$ask_out" | grep -q '^result=ask' &&
   printf '%s\n' "$ask_out" | grep -q '^missing=governance$'; then
    ok "PF-5 unknown を含む入力では result=ask + missing=<項目> を返す（許容側の確認）"
else
    ng "PF-5 unknown を含む入力で result=ask が返らない（exit=$ask_status 出力: $ask_out）"
fi

# ---------- SC-004b: 実行時間が 1 秒未満 ----------

start=$SECONDS
"$DECIDE" --governance no --orchestration no --reusable yes --needs-code yes >/dev/null 2>&1
elapsed=$((SECONDS - start))

if [ "$elapsed" -lt 1 ]; then
    ok "PF-6 1 回の判定が 1 秒未満（秒精度で計測: ${elapsed}s）"
else
    ng "PF-6 1 回の判定が 1 秒以上かかった（秒精度で計測: ${elapsed}s）"
fi

# 連続実行でも劣化しないこと（1 回だけ測ると秒精度では差が出にくいため、
# 8 通り連続の合計にも余裕を持った上限を置く）
start=$SECONDS
for governance in yes no; do
    for orchestration in yes no; do
        for reusable in yes no; do
            "$DECIDE" --governance "$governance" --orchestration "$orchestration" \
                --reusable "$reusable" --needs-code yes >/dev/null 2>&1
        done
    done
done
elapsed=$((SECONDS - start))

if [ "$elapsed" -lt 5 ]; then
    ok "PF-7 8 通りを連続実行して 5 秒未満（秒精度で計測: ${elapsed}s）"
else
    ng "PF-7 8 通りの連続実行に 5 秒以上かかった（秒精度で計測: ${elapsed}s）"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
