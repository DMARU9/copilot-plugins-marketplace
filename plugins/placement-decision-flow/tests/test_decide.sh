#!/usr/bin/env bash
# test_decide.sh — 判定コード decide.sh の契約テスト
#
# 対象契約: contracts/decide-cli.md §7 の不変条件 C-1 〜 C-8
# 対象要件: FR-002 / FR-006 / FR-008 / FR-012 / FR-016 / FR-021
# 対象成功基準: SC-001 / SC-004a / SC-006 / SC-007
#
# 非ガバナンスのケースでは --governance no を明示的に渡す（US2 の追加に影響されないため）。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DECIDE="$PLUGIN_DIR/skills/placement-decision-flow/scripts/decide.sh"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_decide.sh ==="

if [ ! -f "$DECIDE" ]; then
    ng "decide.sh が存在する（$DECIDE）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

DECIDE_OUT=""
DECIDE_ERR=""
DECIDE_STATUS=0

run_decide() {
    local err_file
    err_file=$(mktemp)
    DECIDE_OUT=$(bash "$DECIDE" "$@" 2>"$err_file")
    DECIDE_STATUS=$?
    DECIDE_ERR=$(cat "$err_file")
    rm -f "$err_file"
}

field_of() { # $1=出力 $2=キー
    printf '%s\n' "$1" | sed -n "s/^$2=//p"
}

assert_eq() { # $1=説明 $2=期待 $3=実際
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        ng "$1（期待: [$2] 実際: [$3]）"
    fi
}

# ---------- 代表的な 4 分類が 1 回の回答で確定する（SC-001 / SC-004a） ----------

decide_case() { # $1=説明 $2=期待target $3=期待reason $4=期待branches $5...=引数
    local desc="$1" want_target="$2" want_reason="$3" want_branches="$4"
    shift 4
    run_decide "$@"
    if [ "$DECIDE_STATUS" -ne 0 ]; then
        ng "$desc（exit=$DECIDE_STATUS stderr=$DECIDE_ERR）"
        return
    fi
    assert_eq "$desc: result" "decision" "$(field_of "$DECIDE_OUT" result)"
    assert_eq "$desc: target" "$want_target" "$(field_of "$DECIDE_OUT" target)"
    assert_eq "$desc: reason" "$want_reason" "$(field_of "$DECIDE_OUT" reason)"
    assert_eq "$desc: branches" "$want_branches" "$(field_of "$DECIDE_OUT" branches)"
}

decide_case "ガバナンス該当 → サブエージェント定義" \
    "subagent-definition" "governance" "governance=yes" --governance yes

decide_case "分解・委任・統合 → オーケストレーター" \
    "orchestrator" "orchestration" "governance=no,orchestration=yes" \
    --governance no --orchestration yes

decide_case "使い回す + 実行コード要 → スキルの実行コード" \
    "skill-scripts" "reusable-with-code" \
    "governance=no,orchestration=no,reusable=yes,needs_code=yes" \
    --governance no --orchestration no --reusable yes --needs-code yes

decide_case "使い回す + 実行コード不要 → スキルの手順" \
    "skill-instructions" "reusable-instructions" \
    "governance=no,orchestration=no,reusable=yes,needs_code=no" \
    --governance no --orchestration no --reusable yes --needs-code no

decide_case "使い回さない → サブエージェント定義" \
    "subagent-definition" "not-reusable" \
    "governance=no,orchestration=no,reusable=no" \
    --governance no --orchestration no --reusable no

# ---------- C-3 / FR-022: ガバナンスは reusable を評価せず短絡する ----------

run_decide --governance yes --reusable yes --needs-code yes
assert_eq "C-3 governance=yes は reusable を評価しない: target" \
    "subagent-definition" "$(field_of "$DECIDE_OUT" target)"
assert_eq "C-3 governance=yes は reusable を評価しない: reason" \
    "governance" "$(field_of "$DECIDE_OUT" reason)"
assert_eq "C-3 governance=yes は reusable を評価しない: branches" \
    "governance=yes" "$(field_of "$DECIDE_OUT" branches)"

# ---------- FR-006 / SC-007: 情報不足なら問い返す ----------

ask_case() { # $1=説明 $2=期待missing $3...=引数
    local desc="$1" want_missing="$2"
    shift 2
    run_decide "$@"
    if [ "$DECIDE_STATUS" -ne 0 ]; then
        ng "$desc（exit=$DECIDE_STATUS）"
        return
    fi
    assert_eq "$desc: result" "ask" "$(field_of "$DECIDE_OUT" result)"
    assert_eq "$desc: missing" "$want_missing" "$(field_of "$DECIDE_OUT" missing)"
}

ask_case "引数なし → governance を問い返す" "governance"
ask_case "orchestration が unknown → 次を問い返す" "orchestration" \
    --governance no --orchestration unknown
ask_case "reusable が未回答 → 次を問い返す" "reusable" \
    --governance no --orchestration no
ask_case "needs_code が未回答 → 次を問い返す" "needs_code" \
    --governance no --orchestration no --reusable yes

run_decide --governance no --orchestration no --reusable yes --needs-code unknown
assert_eq "needs_code=unknown も問い返しになる: missing" \
    "needs_code" "$(field_of "$DECIDE_OUT" missing)"

# ---------- C-5: missing は評価順で最初の unknown ----------

run_decide --orchestration yes
assert_eq "C-5 先行ゲートが未回答なら後続を問い返さない: missing" \
    "governance" "$(field_of "$DECIDE_OUT" missing)"

# ---------- C-1 / FR-012: 81 通りの組合せでクラッシュせず、必ず判断か問い返しを返す ----------

combo_fail=0
combo_total=0
combo_non_result=0
for g in yes no unknown; do
    for o in yes no unknown; do
        for r in yes no unknown; do
            for n in yes no unknown; do
                combo_total=$((combo_total + 1))
                run_decide --governance "$g" --orchestration "$o" \
                    --reusable "$r" --needs-code "$n"
                if [ "$DECIDE_STATUS" -ne 0 ]; then
                    combo_fail=$((combo_fail + 1))
                    continue
                fi
                first_line=$(printf '%s\n' "$DECIDE_OUT" | head -1)
                case "$first_line" in
                    result=decision|result=ask) ;;
                    *) combo_non_result=$((combo_non_result + 1)) ;;
                esac
            done
        done
    done
done

assert_eq "C-1 81 通りすべてが exit 0" "0" "$combo_fail"
assert_eq "FR-012 81 通りすべてが decision か ask を返す" "0" "$combo_non_result"
assert_eq "C-1 組合せの総数" "81" "$combo_total"

# ---------- C-6 / FR-002: target / reason / missing の値域 ----------

bad_target=0
bad_reason=0
bad_missing=0
for g in yes no unknown; do
    for o in yes no unknown; do
        for r in yes no unknown; do
            for n in yes no unknown; do
                run_decide --governance "$g" --orchestration "$o" \
                    --reusable "$r" --needs-code "$n"
                if printf '%s\n' "$DECIDE_OUT" | grep -q '^result=decision$'; then
                    case "$(field_of "$DECIDE_OUT" target)" in
                        orchestrator|subagent-definition|skill-instructions|skill-scripts) ;;
                        *) bad_target=$((bad_target + 1)) ;;
                    esac
                    case "$(field_of "$DECIDE_OUT" reason)" in
                        governance|orchestration|reusable-with-code|reusable-instructions|not-reusable) ;;
                        *) bad_reason=$((bad_reason + 1)) ;;
                    esac
                else
                    case "$(field_of "$DECIDE_OUT" missing)" in
                        governance|orchestration|reusable|needs_code) ;;
                        *) bad_missing=$((bad_missing + 1)) ;;
                    esac
                fi
            done
        done
    done
done

assert_eq "C-6 target は 4 値に限る" "0" "$bad_target"
assert_eq "C-6 reason は 5 値に限る" "0" "$bad_reason"
assert_eq "C-6 missing は 4 値に限る" "0" "$bad_missing"

# ---------- C-4: branches の順序が評価順と一致する ----------

run_decide --governance no --orchestration no --reusable yes --needs-code yes
assert_eq "C-4 branches は評価順（governance→orchestration→reusable→needs_code）" \
    "governance=no,orchestration=no,reusable=yes,needs_code=yes" \
    "$(field_of "$DECIDE_OUT" branches)"

# ---------- C-7 / FR-008: 決定性（同じ入力で byte 一致） ----------

run_decide --governance no --orchestration no --reusable yes --needs-code no
first_output="$DECIDE_OUT"
run_decide --governance no --orchestration no --reusable yes --needs-code no
assert_eq "C-7 同じ入力で stdout が byte 一致（評価順 3 のケース）" \
    "$first_output" "$DECIDE_OUT"

run_decide --governance no --orchestration yes
first_output="$DECIDE_OUT"
run_decide --governance no --orchestration yes
assert_eq "C-7 同じ入力で stdout が byte 一致（評価順 2 のケース）" \
    "$first_output" "$DECIDE_OUT"

run_decide --governance yes
first_output="$DECIDE_OUT"
run_decide --governance yes
assert_eq "C-7 同じ入力で stdout が byte 一致（評価順 1 のケース）" \
    "$first_output" "$DECIDE_OUT"

run_decide
first_output="$DECIDE_OUT"
run_decide
assert_eq "C-7 同じ入力で stdout が byte 一致（問い返しのケース）" \
    "$first_output" "$DECIDE_OUT"

# ---------- SC-006: 実行ディレクトリを変えても同じ出力 ----------

from_repo=$(cd "$PLUGIN_DIR" && bash "$DECIDE" --governance no --orchestration no \
    --reusable yes --needs-code yes 2>/dev/null)
from_tmp=$(cd /tmp && bash "$DECIDE" --governance no --orchestration no \
    --reusable yes --needs-code yes 2>/dev/null)
from_home=$(cd "$HOME" && bash "$DECIDE" --governance no --orchestration no \
    --reusable yes --needs-code yes 2>/dev/null)

if [ "$from_repo" = "$from_tmp" ] && [ "$from_repo" = "$from_home" ]; then
    ok "SC-006 実行ディレクトリを変えても同じ出力になる"
else
    ng "SC-006 実行ディレクトリで出力が変わった"
fi

# ---------- C-8: 出力に ASCII 以外が含まれない ----------

run_decide --governance no --orchestration no --reusable yes --needs-code yes
total_bytes=$(printf '%s' "$DECIDE_OUT" | wc -c)
ascii_bytes=$(printf '%s' "$DECIDE_OUT" | LC_ALL=C tr -cd '\11\12\15\40-\176' | wc -c)
assert_eq "C-8 出力が ASCII のみ（$total_bytes bytes）" "$total_bytes" "$ascii_bytes"

run_decide
total_bytes=$(printf '%s' "$DECIDE_OUT" | wc -c)
ascii_bytes=$(printf '%s' "$DECIDE_OUT" | LC_ALL=C tr -cd '\11\12\15\40-\176' | wc -c)
assert_eq "C-8 問い返しの出力も ASCII のみ" "$total_bytes" "$ascii_bytes"

# ---------- FR-016: 出力は key=value の 1 行 1 フィールド ----------

run_decide --governance no --orchestration no --reusable yes --needs-code yes
assert_eq "FR-016 行数が 4（result/target/reason/branches）" "4" \
    "$(printf '%s\n' "$DECIDE_OUT" | wc -l)"
assert_eq "FR-016 1 行目が result" "result=decision" \
    "$(printf '%s\n' "$DECIDE_OUT" | head -1)"

run_decide
assert_eq "FR-016 問い返しは 2 行（result/missing）" "2" \
    "$(printf '%s\n' "$DECIDE_OUT" | wc -l)"

if printf '%s\n' "$DECIDE_OUT" | grep -qvE '^[a-z_]+=[a-z_-]+$'; then
    ng "FR-016 出力が key=value 形式のみ"
else
    ok "FR-016 出力が key=value 形式のみ"
fi

# ---------- 不正入力は exit 2 で拒否する（contracts §4 / 憲章 III） ----------

invalid_case() { # $1=説明 $2...=引数
    local desc="$1"
    shift
    run_decide "$@"
    if [ "$DECIDE_STATUS" -ne 2 ]; then
        ng "$desc: exit 2 で拒否する（実際: $DECIDE_STATUS）"
        return
    fi
    if [ -n "$DECIDE_OUT" ]; then
        ng "$desc: stdout が空（実際: [$DECIDE_OUT]）"
        return
    fi
    if [ -z "$DECIDE_ERR" ]; then
        ng "$desc: stderr に理由が出る"
        return
    fi
    ok "$desc: exit 2 / stdout 空 / stderr に理由"
}

invalid_case "不正な値（maybe）" --governance maybe
invalid_case "大文字の値（YES）" --governance YES
invalid_case "不明なオプション（--unknown-flag）" --unknown-flag yes
invalid_case "値の重複指定" --governance yes --governance no
invalid_case "値の欠落" --governance
invalid_case "空文字の値" --governance ""

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
