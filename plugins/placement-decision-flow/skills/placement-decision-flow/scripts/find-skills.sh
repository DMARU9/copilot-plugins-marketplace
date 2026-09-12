#!/usr/bin/env bash
# find-skills.sh — 既存スキル探索
#
# 対象リポジトリ内の SKILL.md を探索し、再利用候補を列挙する（FR-009）。
# 特定のディレクトリ構成に依存しない（FR-010）。読み取り専用で、対象リポジトリに
# 一切書き込まない（FR-020）。
#
# 設計上の制約（憲章 VII / plan.md）:
#   - bash 3.2 以上で動作させるため declare -A（連想配列）を使わない
#   - 出力のソート順をロケールに依存させない（LC_ALL=C を用いる）
#   - 追加依存なし（ネットワーク不要）
#
# 終了コード: 0 = 探索完了 / 2 = 入力が不正 / 3 = --root が読み取れない

set -uo pipefail

# 自身の位置を基準にパスを解決する（憲章 I: カレントディレクトリに依存しない）
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEFAULT_EXCLUDES=".git node_modules tmp dist build vendor .venv venv __pycache__"

root_opt=""
query=""
extra_excludes=""
detect_conventions=0

usage() {
    cat <<USAGE
find-skills.sh — 既存スキル探索（$SCRIPT_DIR/find-skills.sh）

Usage: find-skills.sh [OPTIONS]

Options:
  --root <dir>          探索の起点（既定: git リポジトリルート、git でなければカレントディレクトリ）
  --query <text>        name または description への部分一致フィルタ（大文字小文字を区別しない）
  --exclude <name>      追加の除外ディレクトリ名（複数回指定可）
  -h, --help            この使用方法を表示する
USAGE
}

die() { # $1=終了コード $2=理由
    printf '%s\n' "find-skills.sh: $2" >&2
    exit "$1"
}

# ---------- 引数の解析 ----------

while [ $# -gt 0 ]; do
    case "$1" in
        --root)
            [ $# -ge 2 ] || die 2 "--root には値が必要です"
            [ -z "$root_opt" ] || die 2 "--root が重複して指定されました"
            root_opt="$2"
            shift 2
            ;;
        --query)
            [ $# -ge 2 ] || die 2 "--query には値が必要です"
            [ -z "$query" ] || die 2 "--query が重複して指定されました"
            query="$2"
            shift 2
            ;;
        --exclude)
            [ $# -ge 2 ] || die 2 "--exclude には値が必要です"
            extra_excludes="$extra_excludes $2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die 2 "不明なオプションです: '$1'"
            ;;
    esac
done

# ---------- ルートの決定（--root > git リポジトリルート > カレントディレクトリ） ----------

if [ -n "$root_opt" ]; then
    root="$root_opt"
    if [ ! -d "$root" ] || [ ! -r "$root" ]; then
        die 3 "ルートディレクトリを読み取れません: $root"
    fi
else
    root=$(git rev-parse --show-toplevel 2>/dev/null) || root=""
    if [ -z "$root" ]; then
        root="$PWD"
    fi
fi

root_abs=$(CDPATH= cd -- "$root" && pwd) || die 3 "ルートディレクトリを解決できません: $root"

# ---------- フロントマターの読み取り ----------

frontmatter() { # $1=SKILL.md のパス
    awk 'NR == 1 && $0 == "---" { inblock = 1; next }
         inblock && $0 == "---" { exit }
         inblock { print }' "$1"
}

strip_quotes() { # $1=値
    local value="$1"
    case "$value" in
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
    esac
    printf '%s' "$value"
}

# ---------- 探索と出力 ----------

# 除外ディレクトリを -prune する式を組み立てる
find_args=("$root_abs" "(" )
first_exclude=1
for name in $DEFAULT_EXCLUDES $extra_excludes; do
    if [ "$first_exclude" -eq 1 ]; then
        first_exclude=0
    else
        find_args=("${find_args[@]}" "-o")
    fi
    find_args=("${find_args[@]}" "-name" "$name")
done
find_args=("${find_args[@]}" ")" "-prune" "-o" "-type" "f" "-name" "SKILL.md" "-print")

query_lower=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')

{
    while IFS= read -r skill_file; do
        [ -n "$skill_file" ] || continue

        name=$(frontmatter "$skill_file" | sed -n 's/^name:[[:space:]]*//p' | head -1)
        description=$(frontmatter "$skill_file" | sed -n 's/^description:[[:space:]]*//p' | head -1)
        name=$(strip_quotes "$name")
        description=$(strip_quotes "$description")
        # 列が崩れないよう、タブと改行を空白 1 個に置換する
        description=$(printf '%s' "$description" | tr '\t\n' '  ' | tr -s ' ')

        if [ -n "$query_lower" ]; then
            haystack=$(printf '%s\n%s' "$name" "$description" | tr '[:upper:]' '[:lower:]')
            if ! printf '%s\n' "$haystack" | grep -qF -- "$query_lower"; then
                continue
            fi
        fi

        rel_path="${skill_file#"$root_abs"/}"
        printf '%s\t%s\t%s\n' "$rel_path" "$name" "$description"
    done < <(find "${find_args[@]}" 2>/dev/null)
} | LC_ALL=C sort

exit 0
