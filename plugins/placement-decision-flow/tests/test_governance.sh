#!/usr/bin/env bash
# test_governance.sh — ガバナンス判定の契約テスト（US2）
#
# 対象契約: contracts/decide-cli.md §7 の不変条件 C-3 / C-4 / C-5
# 対象要件: FR-005（ガバナンス項目はサブエージェント定義側）/ FR-021（評価順序の固定）/
#           FR-022（再利用できることを理由にスキルへ流さない）
# 対象成功基準: SC-002（スキルへの誤判定 0 件）/ SC-010（順序依存のぶれ 0 件）
#
# ケースは tests/fixtures/governance-cases.tsv に外出ししてある（T017）。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DECIDE="$PLUGIN_DIR/skills/placement-decision-flow/scripts/decide.sh"
CASES="$SCRIPT_DIR/fixtures/governance-cases.tsv"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

# 出力から 1 キーの値を取り出す（無ければ空）
value_of() { # $1=出力 $2=キー
    printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

has_key() { # $1=出力 $2=キー
    printf '%s\n' "$1" | grep -q "^$2=" && echo yes || echo no
}

echo "=== test_governance.sh ==="

if [ ! -f "$DECIDE" ]; then
    ng "decide.sh が存在する（$DECIDE）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

if [ ! -f "$CASES" ]; then
    ng "ケース表が存在する（$CASES）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# ---------- ケース表の構造（タブ区切り 9 列） ----------

bad_fields=$(awk -F'\t' 'NF > 0 && $0 !~ /^#/ && NF != 9 { n++ } END { print n + 0 }' "$CASES")
if [ "$bad_fields" -eq 0 ]; then
    ok "ケース表の全データ行がタブ区切り 9 列"
else
    ng "ケース表に列数が 9 でない行がある（$bad_fields 行）"
fi

fixture_rows=$(awk -F'\t' 'NF > 0 && $0 !~ /^#/ { n++ } END { print n + 0 }' "$CASES")
if [ "$fixture_rows" -ge 12 ]; then
    ok "ケース表のデータ行数（$fixture_rows 行）"
else
    ng "ケース表のデータ行数が少なすぎる（実際: $fixture_rows 行）"
fi

# ---------- 全ケースを decide.sh に流す ----------

total=0
gov_yes=0
gov_unknown=0
skill_leak=0
shortcut_violation=0
branch_order_violation=0

while IFS=$'\t' read -r gov orc reu needs exp_result exp_target exp_reason exp_missing note; do
    case "$gov" in
        ''|'#'*) continue ;;
    esac
    total=$((total + 1))
    label="[$gov/$orc/$reu/$needs]"

    out=$(bash "$DECIDE" --governance "$gov" --orchestration "$orc" \
        --reusable "$reu" --needs-code "$needs" 2>/dev/null)
    status=$?
    result=$(value_of "$out" 'result')
    target=$(value_of "$out" 'target')
    reason=$(value_of "$out" 'reason')
    branches=$(value_of "$out" 'branches')
    missing=$(value_of "$out" 'missing')

    if [ "$status" -ne 0 ]; then
        ng "全ケースが exit 0 $label（実際: $status）"
        continue
    fi

    if [ "$result" = "$exp_result" ]; then
        ok "result $label → $exp_result"
    else
        ng "result $label（期待: $exp_result 実際: $result）"
    fi

    if [ "$exp_result" = "decision" ]; then
        if [ "$target" = "$exp_target" ] && [ "$reason" = "$exp_reason" ]; then
            ok "target/reason $label → $exp_target / $exp_reason（$note）"
        else
            ng "target/reason $label（期待: $exp_target / $exp_reason 実際: $target / $reason）"
        fi

        if [ "$(has_key "$out" 'missing')" = "no" ]; then
            ok "確定時は missing を出さない $label"
        else
            ng "確定時に missing が出た $label（$out）"
        fi
    else
        if [ "$missing" = "$exp_missing" ]; then
            ok "missing $label → $exp_missing（$note）"
        else
            ng "missing $label（期待: $exp_missing 実際: $missing）"
        fi

        if [ "$(has_key "$out" 'target')" = "no" ] && [ "$(has_key "$out" 'reason')" = "no" ]; then
            ok "問い返し時は target / reason を出さない $label"
        else
            ng "問い返し時に target / reason が出た $label（$out）"
        fi
    fi

    # 評価順序（C-4）: branches は governance から始まる
    if [ -z "$branches" ] || printf '%s' "$branches" | grep -q '^governance='; then
        :
    else
        branch_order_violation=$((branch_order_violation + 1))
    fi

    # governance=yes の短絡（C-3 / FR-022）: reusable / needs_code を評価しない
    if [ "$gov" = "yes" ]; then
        gov_yes=$((gov_yes + 1))

        if [ "$branches" = "governance=yes" ]; then
            ok "governance=yes は短絡する（branches=$branches）$label"
        else
            shortcut_violation=$((shortcut_violation + 1))
            ng "governance=yes の branches が短絡していない $label（実際: $branches）"
        fi

        if printf '%s' "$branches" | grep -Eq 'reusable=|needs_code='; then
            shortcut_violation=$((shortcut_violation + 1))
            ng "governance=yes なのに reusable / needs_code を評価した $label（$branches）"
        else
            ok "governance=yes の branches に reusable / needs_code が現れない $label"
        fi

        # SC-002: ガバナンス該当がスキル側（skill-*）と判定される経路が存在しない
        case "$target" in
            skill-instructions|skill-scripts)
                skill_leak=$((skill_leak + 1))
                ng "SC-002 ガバナンス該当がスキルに誤判定された $label（$target）"
                ;;
        esac
    fi

    if [ "$gov" = "unknown" ]; then
        gov_unknown=$((gov_unknown + 1))
    fi
done < "$CASES"

if [ "$total" -eq "$fixture_rows" ]; then
    ok "ケース表の全 $total 行を実行した"
else
    ng "ケース表の行数と実行数が一致しない（表: $fixture_rows 実行: $total）"
fi

if [ "$gov_yes" -ge 7 ]; then
    ok "governance=yes のケースを $gov_yes 件実行した"
else
    ng "governance=yes のケースが少なすぎる（実際: $gov_yes 件）"
fi

if [ "$gov_unknown" -ge 2 ]; then
    ok "governance=unknown のケースを $gov_unknown 件実行した"
else
    ng "governance=unknown のケースが少なすぎる（実際: $gov_unknown 件）"
fi

# ---------- SC-002（スキルへの誤判定 0 件） ----------

if [ "$skill_leak" -eq 0 ]; then
    ok "SC-002 ガバナンス該当がスキルに誤判定された件数は 0"
else
    ng "SC-002 ガバナンス該当がスキルに誤判定された（$skill_leak 件）"
fi

if [ "$shortcut_violation" -eq 0 ]; then
    ok "C-3 短絡の破れは 0 件"
else
    ng "C-3 短絡が破れた（$shortcut_violation 件）"
fi

if [ "$branch_order_violation" -eq 0 ]; then
    ok "C-4 branches が常に governance から始まる"
else
    ng "C-4 branches の先頭が governance でない（$branch_order_violation 件）"
fi

# ---------- FR-021: 最初の不明を評価順どおりに問い返す ----------

check_missing() { # $1=説明 $2=期待missing $3...=decide.sh の引数
    local label="$1" expected="$2"
    shift 2
    local out actual
    out=$(bash "$DECIDE" "$@" 2>/dev/null)
    actual=$(value_of "$out" 'missing')
    if [ "$actual" = "$expected" ]; then
        ok "FR-021 最初の不明を問い返す: $label → $expected"
    else
        ng "FR-021 最初の不明を問い返す: $label（期待: $expected 実際: $actual）"
    fi
}

check_missing "governance が不明" "governance" --governance unknown --orchestration unknown --reusable unknown --needs-code unknown
check_missing "governance 確定後の orchestration が不明" "orchestration" --governance no --orchestration unknown --reusable unknown --needs-code unknown
check_missing "governance / orchestration 確定後の reusable が不明" "reusable" --governance no --orchestration no --reusable unknown --needs-code unknown
check_missing "governance / orchestration / reusable 確定後の needs_code が不明" "needs_code" --governance no --orchestration no --reusable yes --needs-code unknown
check_missing "governance=unknown は後続が確定していても最初" "governance" --governance unknown --orchestration no --reusable no --needs-code no

# 判断表 5 行目の needs_code 列は `*`（短絡）なので、reusable=no では needs_code を評価しない
star_out=$(bash "$DECIDE" --governance no --orchestration no --reusable no --needs-code unknown 2>/dev/null)
star_target=$(value_of "$star_out" 'target')
star_branches=$(value_of "$star_out" 'branches')
if [ "$star_target" = "subagent-definition" ] && [ "$star_branches" = "governance=no,orchestration=no,reusable=no" ]; then
    ok "FR-021 reusable=no では needs_code（列が \`*\`）を評価しない"
else
    ng "FR-021 reusable=no でも needs_code を評価した（target=$star_target branches=$star_branches）"
fi

# ---------- SC-010（順序依存のぶれ 0 件） ----------

drift=0
while IFS=$'\t' read -r gov orc reu needs exp_result exp_target exp_reason exp_missing note; do
    case "$gov" in
        ''|'#'*) continue ;;
    esac
    args=(--governance "$gov" --orchestration "$orc" --reusable "$reu" --needs-code "$needs")

    first=$(bash "$DECIDE" "${args[@]}" 2>/dev/null)
    second=$(bash "$DECIDE" "${args[@]}" 2>/dev/null)
    third=$(bash "$DECIDE" "${args[@]}" 2>/dev/null)

    if [ "$first" != "$second" ] || [ "$first" != "$third" ]; then
        drift=$((drift + 1))
        ng "SC-010 同じ入力で出力がぶれた（$gov/$orc/$reu/$needs）"
    fi
done < "$CASES"

if [ "$drift" -eq 0 ]; then
    ok "SC-010 同じ入力の繰り返し実行で出力がぶれない（$total ケース × 3 回）"
else
    ng "SC-010 出力がぶれたケースがある（$drift 件）"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
