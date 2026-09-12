#!/usr/bin/env bash
# test_conventions.sh — 慣習検出モードの契約テスト（US3）
#
# 対象契約: contracts/find-skills-cli.md §3.2 / §5 / §7 の不変条件 F-4 / F-7 / F-8
# 対象要件: FR-007 / FR-010 / FR-020
#
# 実装（T023: find-skills.sh の --detect-conventions）より先に書き、失敗することを
# 確認してから実装する。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)
FIND="$PLUGIN_DIR/skills/placement-decision-flow/scripts/find-skills.sh"
FIXTURE="$PLUGIN_DIR/tests/fixtures/repo"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_conventions.sh ==="

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

# ---------- F-4: フィクスチャに対して常に 4 行を出力する ----------

out=$(bash "$FIND" --detect-conventions --root "$FIXTURE" 2>/dev/null)
status=$?

if [ "$status" -eq 0 ]; then
    ok "慣習検出モードが exit 0 で終了する"
else
    ng "慣習検出モードが exit 0 で終了しない（実際: $status）"
fi

line_count=$(printf '%s\n' "$out" | grep -c . || true)
if [ "$line_count" -eq 4 ]; then
    ok "F-4 常に 4 行出力する"
else
    ng "F-4 出力が 4 行でない（実際: $line_count 行）"
fi

# ---------- §3.2: 各行が layer<TAB>path<TAB>exists ----------

bad_fields=$(printf '%s\n' "$out" | awk -F'\t' 'NF && NF != 3 { n++ } END { print n + 0 }')
if [ "$bad_fields" -eq 0 ]; then
    ok "各行がタブ区切りの 3 列（layer / path / exists）"
else
    ng "3 列でない行がある（$bad_fields 行）"
fi

bad_exists=$(printf '%s\n' "$out" | awk -F'\t' 'NF == 3 && $3 != "yes" && $3 != "no" { n++ } END { print n + 0 }')
if [ "$bad_exists" -eq 0 ]; then
    ok "exists はすべて yes か no"
else
    ng "exists が yes / no でない行がある（$bad_exists 行）"
fi

bad_layer=$(printf '%s\n' "$out" | awk -F'\t' 'NF == 3 && $1 != "skill" && $1 != "subagent" { n++ } END { print n + 0 }')
if [ "$bad_layer" -eq 0 ]; then
    ok "layer はすべて skill か subagent"
else
    ng "layer が skill / subagent でない行がある（$bad_layer 行）"
fi

absolute_count=$(printf '%s\n' "$out" | awk -F'\t' '$2 ~ /^\//' | grep -c . || true)
if [ "$absolute_count" -eq 0 ]; then
    ok "path は絶対パスにならない（FR-007 / FR-020）"
else
    ng "path に絶対パスが含まれる（$absolute_count 行）"
fi

# ---------- §3.2: layer → path の昇順 ----------

sorted_out=$(printf '%s\n' "$out" | LC_ALL=C sort)
if [ -n "$out" ] && [ "$out" = "$sorted_out" ]; then
    ok "layer → path の昇順で出力される"
else
    ng "出力が layer → path の昇順でない（実際: [$(printf '%s' "$out" | tr '\n' '|')]）"
fi

# ---------- §3.2: 契約どおりの 4 候補が過不足なく出る ----------

expected=$(
    printf 'skill\t%s\tyes\n' '.github/skills/'
    printf 'skill\t%s\tyes\n' 'plugins/*/skills/'
    printf 'subagent\t%s\tno\n' '.claude/agents/'
    printf 'subagent\t%s\tno\n' '.github/agents/'
)

if [ "$out" = "$expected" ]; then
    ok "契約どおりの 4 候補の exists を報告する"
else
    ng "4 候補の exists が契約と一致しない（実際: [$(printf '%s' "$out" | tr '\n' '|')]）"
fi

# ---------- F-4: 存在しない候補も no として報告する（存在しないことも情報） ----------

no_count=$(printf '%s\n' "$out" | awk -F'\t' '$3 == "no"' | grep -c . || true)
if [ "$no_count" -eq 2 ]; then
    ok "F-4 存在しない候補も no として出力する（$no_count 行）"
else
    ng "F-4 存在しない候補の no 行が 2 行でない（実際: $no_count 行）"
fi

# ---------- F-4: 空のルートでも 4 行を出す（すべて no） ----------

EMPTY_ROOT=$(mktemp -d)
TMP_DIRS="$TMP_DIRS $EMPTY_ROOT"

empty_out=$(bash "$FIND" --detect-conventions --root "$EMPTY_ROOT" 2>/dev/null)
empty_lines=$(printf '%s\n' "$empty_out" | grep -c . || true)
empty_yes=$(printf '%s\n' "$empty_out" | awk -F'\t' '$3 == "yes"' | grep -c . || true)

if [ "$empty_lines" -eq 4 ] && [ "$empty_yes" -eq 0 ]; then
    ok "空のルートでも 4 行を出力し、exists はすべて no"
else
    ng "空のルートの出力が 4 行かつ no のみでない（$empty_lines 行 / yes $empty_yes 行）"
fi

# ---------- F-7: カレントディレクトリを変えても同じ結果 ----------

WORK_CWD=$(mktemp -d)
TMP_DIRS="$TMP_DIRS $WORK_CWD"

from_root=$(cd "$REPO_ROOT" && bash "$FIND" --detect-conventions --root "$FIXTURE" 2>/dev/null)
from_tmp=$(cd "$WORK_CWD" && bash "$FIND" --detect-conventions --root "$FIXTURE" 2>/dev/null)
from_plugin=$(cd "$PLUGIN_DIR" && bash "$FIND" --detect-conventions --root "$FIXTURE" 2>/dev/null)

if [ "$out" = "$from_root" ] && [ "$out" = "$from_tmp" ] && [ "$out" = "$from_plugin" ]; then
    ok "F-7 --root を指定すればカレントディレクトリを変えても同じ結果になる"
else
    ng "F-7 カレントディレクトリによって結果が変わる"
fi

# ---------- F-8: 対象リポジトリに書き込まない（FR-020） ----------

COPY_ROOT=$(mktemp -d)
TMP_DIRS="$TMP_DIRS $COPY_ROOT"
cp -R "$FIXTURE/." "$COPY_ROOT/"

tree_hash() { # $1=ディレクトリ
    find "$1" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum
}

copy_hash_before=$(tree_hash "$COPY_ROOT")
bash "$FIND" --detect-conventions --root "$COPY_ROOT" >/dev/null 2>&1
bash "$FIND" --root "$COPY_ROOT" >/dev/null 2>&1
copy_hash_after=$(tree_hash "$COPY_ROOT")

if [ "$copy_hash_before" = "$copy_hash_after" ]; then
    ok "F-8 探索対象のファイルツリーが実行前後で変化しない"
else
    ng "F-8 探索対象のファイルツリーが変化した（$copy_hash_before → $copy_hash_after）"
fi

copy_files_before=$(find "$COPY_ROOT" -type f | grep -c . || true)
bash "$FIND" --detect-conventions --root "$COPY_ROOT" >/dev/null 2>&1
copy_files_after=$(find "$COPY_ROOT" -type f | grep -c . || true)

if [ "$copy_files_before" -eq "$copy_files_after" ]; then
    ok "F-8 一時ファイルを残さない（ファイル数 $copy_files_after のまま）"
else
    ng "F-8 ファイル数が変化した（$copy_files_before → $copy_files_after）"
fi

# 実リポジトリの git status が変化しないこと（FR-020）
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    status_before=$(git -C "$REPO_ROOT" status --porcelain)
    bash "$FIND" --detect-conventions --root "$REPO_ROOT" >/dev/null 2>&1
    bash "$FIND" --root "$REPO_ROOT" >/dev/null 2>&1
    status_after=$(git -C "$REPO_ROOT" status --porcelain)

    if [ "$status_before" = "$status_after" ]; then
        ok "F-8 実リポジトリの git status が実行前後で変化しない"
    else
        ng "F-8 git status が変化した"
    fi
else
    ng "F-8 実リポジトリが git リポジトリとして認識されない"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
