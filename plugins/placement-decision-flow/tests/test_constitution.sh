#!/usr/bin/env bash
# test_constitution.sh — 憲章 I / VII の実装規律を機械的に固定する（T033）
#
# 対象契約: contracts/skill-frontmatter.md（プラグイン境界）
# 対象要件: 憲章 I（スキルは自身のルートからの相対参照で完結する）
#           憲章 VII（bash 3.2 互換・追加依存なし・環境固有の絶対パスを持たない）
#
# 対象は**配布スクリプト**（skills/<name>/scripts/*.sh）のみ。
# tests/ 配下のテストはリポジトリ内の位置を計算するために `..` を使うため対象外
# （配布物ではないので境界越えの規律はかからない）。
#
# 注意: 対象スクリプトはコメントで「declare -A を使わない」と説明しているため、
# **コメント行を除いたコード行**に対して検査する。素朴に全文を grep すると
# 常に NG になる（このフィルタが効いていることは C-B で確かめる）。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SKILL_DIR="$PLUGIN_DIR/skills/placement-decision-flow"
SCRIPTS_DIR="$SKILL_DIR/scripts"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_constitution.sh ==="

if [ ! -d "$SCRIPTS_DIR" ]; then
    ng "配布スクリプトのディレクトリが存在する（$SCRIPTS_DIR）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# 出荷スクリプトを動的に列挙する（新しいスクリプトも自動で検査対象になる）
script_list=$(find "$SCRIPTS_DIR" -type f -name '*.sh' | LC_ALL=C sort)
script_count=$(printf '%s\n' "$script_list" | grep -c . || true)

# ---------- C-A: 発見が空振りしていないこと（テストが空虚でないことの前提） ----------

if [ "$script_count" -ge 1 ]; then
    ok "C-A 配布スクリプトを 1 件以上発見した（$script_count 件）"
else
    ng "C-A 配布スクリプトを発見できなかった（検査が空振りしている）"
fi

# ---------- C-B: コメント除去が意味を持っていること ----------

# コメント行に declare -A を含むスクリプトが実在しないと、C-1 は
# 「そもそも declare -A という文字列が無いだけ」で成立し、フィルタの有無を測れない。
commented=0
while IFS= read -r script; do
    [ -n "$script" ] || continue
    if grep -Eq '^[[:space:]]*#' "$script" && grep -q 'declare -A' "$script"; then
        commented=$((commented + 1))
    fi
done <<EOF
$script_list
EOF

if [ "$commented" -ge 1 ]; then
    ok "C-B コメント行に declare -A を含むスクリプトが実在する（$commented 件・フィルタが必要）"
else
    ng "C-B コメント行に declare -A を含むスクリプトが無く、コメント除去の必要性を測れない"
fi

# ---------- C-1〜C-4: スクリプト 1 件ごとの規律 ----------

while IFS= read -r script; do
    [ -n "$script" ] || continue
    name=$(basename "$script")

    # コメント行を除いた「実際に実行される行」
    code=$(grep -v '^[[:space:]]*#' "$script" || true)

    # C-1: bash 3.2 互換（連想配列を使わない）
    if printf '%s\n' "$code" | grep -Eq 'declare[[:space:]]+-A'; then
        ng "C-1 $name のコード行に declare -A がある（bash 3.2 では動かない）"
    else
        ok "C-1 $name のコード行に declare -A が無い"
    fi

    # C-2: プラグイン境界を越える親ディレクトリ参照が無い
    if printf '%s\n' "$code" | grep -Eq '\.\./'; then
        ng "C-2 $name に ../ による親ディレクトリ参照がある（憲章 I 違反）"
    else
        ok "C-2 $name に ../ による親ディレクトリ参照が無い"
    fi

    # C-3: 環境固有の絶対パスが埋め込まれていない（shebang の /usr/bin/env は許容）
    hits=$(printf '%s\n' "$code" | grep -Ec '/home/|/Users/|C:/Users/' || true)
    if [ "$hits" -eq 0 ]; then
        ok "C-3 $name に環境固有の絶対パスが無い"
    else
        ng "C-3 $name に環境固有の絶対パスが $hits 箇所ある"
    fi

    # C-4: 自身の位置は SCRIPT_DIR（BASH_SOURCE 基準）で解決している
    if printf '%s\n' "$code" | grep -Eq 'SCRIPT_DIR=.*BASH_SOURCE.*pwd'; then
        ok "C-4 $name が SCRIPT_DIR 基準で自身の位置を解決している"
    else
        ng "C-4 $name が SCRIPT_DIR 基準で自身の位置を解決していない（憲章 I 違反）"
    fi
done <<EOF
$script_list
EOF

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
