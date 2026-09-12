#!/usr/bin/env bash
# test_criteria_sync.sh — 判断表と判定コードの同期テスト（FR-017）
#
# references/criteria.md の判断表を「判断基準の単一の真実源」として読み取り、
# 各行を decide.sh に流して target / reason を照合する。
#
# 列構成はヘッダ行から動的に読み取るため、列が増えてもテスト本体の修正は不要。
# `*` の列には yes / no / unknown の 3 値を流し込み、target が変わらないことを確認する。
# 判断表を書き換えると（decide.sh を変えていなければ）このテストが失敗する。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
CRITERIA="$PLUGIN_DIR/skills/placement-decision-flow/references/criteria.md"
DECIDE="$PLUGIN_DIR/skills/placement-decision-flow/scripts/decide.sh"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_criteria_sync.sh ==="

if [ ! -f "$CRITERIA" ]; then
    ng "criteria.md が存在する（$CRITERIA）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

if [ ! -f "$DECIDE" ]; then
    ng "decide.sh が存在する（$DECIDE）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# ---------- 判断表のヘッダ行を探す ----------

header_line=$(grep -n -E '^\|[[:space:]]*(governance|orchestration|reusable|needs_code)[[:space:]]*\|.*\|[[:space:]]*target[[:space:]]*\|[[:space:]]*reason[[:space:]]*\|[[:space:]]*$' "$CRITERIA" | head -1 | cut -d: -f1)

if [ -z "$header_line" ]; then
    ng "criteria.md に 6 列の判断表（... target | reason）が見つかる"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi
ok "判断表のヘッダ行を検出（$header_line 行目）"

# ---------- 行をセルに分割する（前後の空白を除去） ----------

ROW_CELLS=()
parse_row() {
    ROW_CELLS=()
    local cell
    while IFS= read -r cell; do
        ROW_CELLS=("${ROW_CELLS[@]}" "$cell")
    done < <(printf '%s\n' "$1" | sed 's/^|//; s/|$//' | tr '|' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
}

# 列名 → CLI オプション（snake_case を kebab-case に直すだけの汎用変換）
option_for() {
    printf '%s' "--$1" | tr '_' '-'
}

field_of() { # $1=出力 $2=キー
    printf '%s\n' "$1" | sed -n "s/^$2=//p"
}

# ---------- ヘッダとデータ行を読み取る ----------

COL_NAMES=()
TARGET_IDX=-1
REASON_IDX=-1

row_index=0
table_rows=0
data_fail=0

while IFS= read -r line; do
    case "$line" in
        \|*) ;;
        *) break ;;
    esac

    if [ "$row_index" -eq 0 ]; then
        # ヘッダ行
        parse_row "$line"
        i=0
        while [ "$i" -lt "${#ROW_CELLS[@]}" ]; do
            COL_NAMES=("${COL_NAMES[@]}" "${ROW_CELLS[$i]}")
            case "${ROW_CELLS[$i]}" in
                target) TARGET_IDX=$i ;;
                reason) REASON_IDX=$i ;;
            esac
            i=$((i + 1))
        done
        row_index=$((row_index + 1))
        continue
    fi

    if [ "$row_index" -eq 1 ]; then
        # 区切り行（|---|---|）はスキップ
        row_index=$((row_index + 1))
        continue
    fi

    row_index=$((row_index + 1))
    table_rows=$((table_rows + 1))

    parse_row "$line"
    cells=("${ROW_CELLS[@]}")

    if [ "${#cells[@]}" -ne "${#COL_NAMES[@]}" ]; then
        ng "判断表 ${table_rows} 行目のセル数がヘッダと一致（ヘッダ: ${#COL_NAMES[@]} 実際: ${#cells[@]}）"
        data_fail=$((data_fail + 1))
        continue
    fi

    want_target="${cells[$TARGET_IDX]}"
    want_reason="${cells[$REASON_IDX]}"
    row_fail=0

    # ワイルドカード列（値が `*`）を集める
    wildcard_indices=()
    pow3=()
    p=1
    i=0
    while [ "$i" -lt "${#COL_NAMES[@]}" ]; do
        pow3=("${pow3[@]}" "$p")
        p=$((p * 3))
        i=$((i + 1))
    done

    i=0
    wc_count=0
    while [ "$i" -lt "${#COL_NAMES[@]}" ]; do
        if [ "${cells[$i]}" = "*" ]; then
            wildcard_indices=("${wildcard_indices[@]}" "$i")
            wc_count=$((wc_count + 1))
        fi
        i=$((i + 1))
    done

    combos=1
    j=0
    while [ "$j" -lt "$wc_count" ]; do
        combos=$((combos * 3))
        j=$((j + 1))
    done

    combo=0
    while [ "$combo" -lt "$combos" ]; do
        args=()
        i=0
        while [ "$i" -lt "${#COL_NAMES[@]}" ]; do
            name="${COL_NAMES[$i]}"
            if [ "$name" != "target" ] && [ "$name" != "reason" ]; then
                if [ "${cells[$i]}" = "*" ]; then
                    # ワイルドカード列の順位から base-3 の桁を取り出す
                    rank=0
                    k=0
                    while [ "$k" -lt "$wc_count" ]; do
                        if [ "${wildcard_indices[$k]}" -eq "$i" ]; then
                            rank=$k
                            break
                        fi
                        k=$((k + 1))
                    done
                    digit=$(( (combo / pow3[rank]) % 3 ))
                    case "$digit" in
                        0) value=yes ;;
                        1) value=no ;;
                        *) value=unknown ;;
                    esac
                else
                    value="${cells[$i]}"
                fi
                args=("${args[@]}" "$(option_for "$name")" "$value")
            fi
            i=$((i + 1))
        done

        out=$(bash "$DECIDE" ${args[@]+"${args[@]}"} 2>/dev/null)
        status=$?

        if [ "$status" -ne 0 ]; then
            row_fail=1
            break
        fi

        got_target=$(field_of "$out" target)
        got_reason=$(field_of "$out" reason)

        if [ "$got_target" != "$want_target" ] || [ "$got_reason" != "$want_reason" ]; then
            row_fail=1
            break
        fi

        combo=$((combo + 1))
    done

    if [ "$row_fail" -eq 0 ]; then
        ok "判断表 ${table_rows} 行目: ${want_target} / ${want_reason}（${combos} 通りで一致）"
    else
        ng "判断表 ${table_rows} 行目: ${want_target} / ${want_reason} に一致しない"
        data_fail=$((data_fail + 1))
    fi
done < <(awk -v start="$header_line" 'NR >= start { if ($0 !~ /^\|/) exit; print }' "$CRITERIA")

if [ "$table_rows" -eq 0 ]; then
    ng "判断表にデータ行がある"
fi

if [ "$data_fail" -eq 0 ] && [ "$table_rows" -gt 0 ]; then
    ok "判断表の全行が decide.sh の出力と一致する（$table_rows 行）"
fi

if [ "$table_rows" -eq 5 ]; then
    ok "判断表のデータ行が 5 行ある"
else
    ng "判断表のデータ行が 5 行ある（実際: $table_rows）"
fi

if [ "$TARGET_IDX" -ge 0 ] && [ "$REASON_IDX" -ge 0 ]; then
    ok "target / reason 列がヘッダから見つかる"
else
    ng "target / reason 列がヘッダから見つからない"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
