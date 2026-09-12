#!/usr/bin/env bash
# test_find_skills.sh — 既存スキル探索 find-skills.sh の契約テスト
#
# 対象契約: contracts/find-skills-cli.md §7 の不変条件 F-1 〜 F-3 / F-5 〜 F-6 / F-9
# 対象要件: FR-009 / FR-010 / FR-020 / 憲章 VII
# 対象成功基準: SC-003（重複配置 0 件）を「候補を見逃さない」ことで支える
#
# 除外ディレクトリの検証は、リポジトリを汚さないよう一時ディレクトリへ複製して行う。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
FIND="$PLUGIN_DIR/skills/placement-decision-flow/scripts/find-skills.sh"
FIXTURE="$PLUGIN_DIR/tests/fixtures/repo"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_find_skills.sh ==="

if [ ! -f "$FIND" ]; then
    ng "find-skills.sh が存在する（$FIND）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

TMP_DIRS=""
cleanup() {
    for d in $TMP_DIRS; do
        rm -rf "$d"
    done
}
trap cleanup EXIT

run_find() { # $1=出力変数名に格納するため、呼び出し側で捕捉する
    bash "$FIND" "$@" 2>/dev/null
}

# ---------- 基本: 2 件がタブ区切りのリポジトリ相対パスでパス昇順に並ぶ（FR-009 / SC-003） ----------

out=$(run_find --root "$FIXTURE")
status=$?

expected="$(
    printf '%s\t%s\t%s\n' '.github/skills/code-review/SKILL.md' 'code-review' 'コードレビューを実施する。Use when: reviewing code.'
    printf '%s\t%s\t%s\n' 'plugins/sample-plugin/skills/sample-skill/SKILL.md' 'sample-skill' 'サンプル処理。Use when: running samples.'
)"

if [ "$status" -eq 0 ]; then
    ok "フィクスチャ探索が exit 0 で終了する"
else
    ng "フィクスチャ探索が exit 0 で終了する（実際: $status）"
fi

if [ "$out" = "$expected" ]; then
    ok "2 件がタブ区切り・パス昇順で出力される"
else
    ng "2 件がタブ区切り・パス昇順で出力される（実際: [$out]）"
fi

line_count=$(printf '%s\n' "$out" | grep -c . || true)
if [ "$line_count" -eq 2 ]; then
    ok "候補は 2 件（ヘッダ行を出さない）"
else
    ng "候補は 2 件（実際: $line_count）"
fi

# ---------- F-1 / FR-020: 出力は絶対パスにならない ----------

absolute_count=$(printf '%s\n' "$out" | awk -F'\t' '$1 ~ /^\//' | grep -c . || true)
if [ "$absolute_count" -eq 0 ]; then
    ok "F-1 出力パスが絶対パスにならない"
else
    ng "F-1 出力パスに絶対パスが含まれる（$absolute_count 件）"
fi

# ---------- FR-010 / F-5 / SC-003: 両方の慣習ディレクトリから候補が出る ----------

if printf '%s\n' "$out" | grep -q '^\.github/skills/'; then
    ok "F-5 FR-010 .github/skills/ 配下の SKILL.md が検出される"
else
    ng "F-5 .github/skills/ 配下の SKILL.md が検出されない"
fi

if printf '%s\n' "$out" | grep -q '^plugins/.*/skills/'; then
    ok "SC-003 plugins/*/skills/ 配下の候補も列挙される"
else
    ng "SC-003 plugins/*/skills/ 配下の候補が列挙されない"
fi

# ---------- --query の部分一致フィルタ（FR-009） ----------

filtered=$(run_find --root "$FIXTURE" --query review)
if [ "$filtered" = "$(printf '%s\t%s\t%s' '.github/skills/code-review/SKILL.md' 'code-review' 'コードレビューを実施する。Use when: reviewing code.')" ]; then
    ok "--query review で code-review の 1 件に絞られる"
else
    ng "--query review の結果が期待と異なる（実際: [$filtered]）"
fi

filtered_upper=$(run_find --root "$FIXTURE" --query REVIEW)
if [ "$filtered" = "$filtered_upper" ]; then
    ok "--query は大文字小文字を区別しない"
else
    ng "--query が大文字小文字を区別する（実際: [$filtered_upper]）"
fi

filtered_sub=$(run_find --root "$FIXTURE" --query sample-skill)
if printf '%s\n' "$filtered_sub" | grep -q 'sample-skill'; then
    ok "--query は name にも部分一致する"
else
    ng "--query が name に部分一致しない"
fi

# ---------- F-2: 候補 0 件は正常終了（exit 0・stdout 空） ----------

empty_out=$(run_find --root "$FIXTURE" --query zzz-not-found)
empty_status=$?

if [ "$empty_status" -eq 0 ]; then
    ok "F-2 候補 0 件で exit 0"
else
    ng "F-2 候補 0 件で exit 0 にならない（実際: $empty_status）"
fi

if [ -z "$empty_out" ]; then
    ok "F-2 候補 0 件で stdout が空（空行も出さない）"
else
    ng "F-2 候補 0 件で stdout に出力がある（実際: [$empty_out]）"
fi

# ---------- F-3: 同じ入力で stdout が byte 一致 ----------

first=$(run_find --root "$FIXTURE")
second=$(run_find --root "$FIXTURE")
if [ "$first" = "$second" ]; then
    ok "F-3 同じ入力で stdout が byte 一致"
else
    ng "F-3 同じ入力で stdout が一致しない"
fi

# ---------- F-6: 除外ディレクトリを走査しない ----------

WORK=$(mktemp -d)
TMP_DIRS="$TMP_DIRS $WORK"
cp -R "$FIXTURE/." "$WORK/"

for excluded in .git node_modules tmp dist build vendor .venv venv __pycache__; do
    mkdir -p "$WORK/$excluded"
    printf -- '---\nname: %s\n---\n' "hidden-in-$excluded" > "$WORK/$excluded/SKILL.md"
done

excluded_out=$(run_find --root "$WORK")

excluded_hits=0
for excluded in .git node_modules tmp dist build vendor .venv venv __pycache__; do
    if printf '%s\n' "$excluded_out" | grep -q "$excluded/SKILL.md"; then
        excluded_hits=$((excluded_hits + 1))
    fi
done

if [ "$excluded_hits" -eq 0 ]; then
    ok "F-6 除外ディレクトリ（.git / node_modules / tmp 等）の SKILL.md を検出しない"
else
    ng "F-6 除外ディレクトリの SKILL.md を検出した（$excluded_hits 種）"
fi

# ドット始まりのディレクトリを一律に除外していないこと（.github は残る）
if printf '%s\n' "$excluded_out" | grep -q '^\.github/skills/'; then
    ok "F-6 ドット始まりでも .github/ は除外しない"
else
    ng "F-6 .github/ が除外されてしまった"
fi

# --exclude で追加除外できること
custom_out=$(run_find --root "$WORK" --exclude 'sample-plugin')
if printf '%s\n' "$custom_out" | grep -q 'sample-plugin'; then
    ng "--exclude で指定したディレクトリが除外されない"
else
    ok "--exclude で追加の除外ディレクトリを指定できる"
fi

# ---------- F-9: ソート順が LC_ALL に依存しない（憲章 VII） ----------

sort_a=$(LC_ALL=C bash "$FIND" --root "$FIXTURE" 2>/dev/null)
sort_b=$(LC_ALL=en_US.UTF-8 bash "$FIND" --root "$FIXTURE" 2>/dev/null)
sort_c=$(LC_ALL=ja_JP.UTF-8 bash "$FIND" --root "$FIXTURE" 2>/dev/null)
sort_d=$(LC_ALL=POSIX bash "$FIND" --root "$FIXTURE" 2>/dev/null)

if [ "$sort_a" = "$sort_b" ] && [ "$sort_a" = "$sort_c" ] && [ "$sort_a" = "$sort_d" ]; then
    ok "F-9 ソート順が LC_ALL の値に依存しない"
else
    ng "F-9 LC_ALL によってソート順が変わった"
fi

# ---------- 存在しない --root は exit 3 ----------

bash "$FIND" --root /nonexistent-placement-root >/dev/null 2>&1
missing_status=$?
if [ "$missing_status" -eq 3 ]; then
    ok "存在しない --root は exit 3"
else
    ng "存在しない --root の exit コードが 3 でない（実際: $missing_status）"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
