#!/usr/bin/env bash
# test_manifest.sh — マニフェスト契約の検証（contracts/skill-frontmatter.md §1 / §4）
#
# Phase 2 の時点で対象ファイルが存在する規則のみを固定する:
#   P-1 〜 P-6 : plugins/placement-decision-flow/plugin.json
#   M-1 〜 M-2 : .github/plugin/marketplace.json の登録エントリ
# SKILL.md の規則（S-1 〜 S-3 / S-5）は SKILL.md が作られる T015 で追加する。
#
# jq などの追加依存を使わず、grep / awk / sed だけで JSON を読む（憲章 VII）。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$PLUGIN_DIR/../.." && pwd)

PLUGIN_JSON="$PLUGIN_DIR/plugin.json"
MARKETPLACE="$REPO_ROOT/.github/plugin/marketplace.json"
PLUGIN_NAME="placement-decision-flow"

pass=0
fail=0

ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

eq() { # $1=説明 $2=期待値 $3=実際値
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        ng "$1（期待: [$2] 実際: [$3]）"
    fi
}

present() { # $1=説明 $2=値
    if [ -n "$2" ]; then
        ok "$1"
    else
        ng "$1（空でした）"
    fi
}

# JSON の文字列値を 1 つ取り出す（任意のインデントに対応・最初の一致のみ）
# 使い方: json_value <key> < file
json_value() {
    awk -v key="$1" '
        index($0, "\"" key "\": \"") > 0 {
            line = $0
            p = index(line, "\"" key "\": \"")
            line = substr(line, p + length(key) + 5)
            sub(/",[ \t]*$/, "", line)
            sub(/"[ \t]*$/, "", line)
            print line
            exit
        }'
}

# トップレベルのキー名を列挙する（インデント 2 の行のみ）
top_level_keys() {
    awk '/^  "[^"]+":/ {
        line = $0
        sub(/^  "/, "", line)
        sub(/".*$/, "", line)
        print line
    }' "$1" | LC_ALL=C sort
}

echo "=== test_manifest.sh ==="

if [ ! -f "$PLUGIN_JSON" ]; then
    ng "plugin.json が存在する（$PLUGIN_JSON）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# ---------- P-1: \$schema の完全一致 ----------

eq "P-1 \$schema が公式スキーマ URL と完全一致" \
    "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json" \
    "$(json_value '$schema' < "$PLUGIN_JSON")"

# ---------- P-2: name のパターンと長さ ----------

name_value=$(json_value 'name' < "$PLUGIN_JSON")
name_len=${#name_value}

if [ "$name_len" -ge 1 ] && [ "$name_len" -le 64 ]; then
    ok "P-2 name の長さが 1〜64 文字（$name_len）"
else
    ng "P-2 name の長さが 1〜64 文字（実際: $name_len）"
fi

if [ "$name_len" -eq 1 ]; then
    if printf '%s' "$name_value" | grep -Eq '^[a-z0-9]$'; then
        ok "P-2 name の文字種（先頭末尾は英数字・小文字のみ）"
    else
        ng "P-2 name の文字種（実際: $name_value）"
    fi
elif printf '%s' "$name_value" | grep -Eq '^[a-z0-9][a-z0-9.-]*[a-z0-9]$'; then
    ok "P-2 name の文字種（先頭末尾は英数字・小文字のみ）"
else
    ng "P-2 name の文字種（実際: $name_value）"
fi

case "$name_value" in
    *--*) ng "P-2 name に '--' を含まない（実際: $name_value）" ;;
    *..*) ng "P-2 name に '..' を含まない（実際: $name_value）" ;;
    *) ok "P-2 name に '--' / '..' を含まない" ;;
esac

# ---------- P-3: version は SemVer ----------

version_value=$(json_value 'version' < "$PLUGIN_JSON")
if printf '%s' "$version_value" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'; then
    ok "P-3 version が SemVer（$version_value）"
else
    ng "P-3 version が SemVer（実際: $version_value）"
fi

# ---------- P-4: description は空でない ----------

present "P-4 description が空でない" "$(json_value 'description' < "$PLUGIN_JSON")"

# ---------- P-5: author は name + url（既存プラグインと同形式） ----------

author_block=$(awk '/^  "author": \{/,/^  \}/' "$PLUGIN_JSON")
author_name=$(printf '%s\n' "$author_block" | json_value 'name')
author_url=$(printf '%s\n' "$author_block" | json_value 'url')

present "P-5 author.name が空でない" "$author_name"
if printf '%s' "$author_url" | grep -Eq '^https?://'; then
    ok "P-5 author.url が URL 形式（$author_url）"
else
    ng "P-5 author.url が URL 形式（実際: $author_url）"
fi

# ---------- P-6: 定義済みキー以外を含まない（閉じたスキーマ） ----------

expected_keys=$(printf '%s\n' '$schema' 'name' 'version' 'description' 'author' | LC_ALL=C sort)
actual_keys=$(top_level_keys "$PLUGIN_JSON")
eq "P-6 トップレベルキーが定義済みの 5 つだけ" "$expected_keys" "$actual_keys"

# ---------- M-1 / M-2: marketplace.json との整合 ----------

if [ ! -f "$MARKETPLACE" ]; then
    ng "M-1 marketplace.json が存在する（$MARKETPLACE）"
else
    entry_block=$(grep -A4 "\"name\": \"$PLUGIN_NAME\"" "$MARKETPLACE" || true)
    if [ -z "$entry_block" ]; then
        ng "M-1 marketplace.json に $PLUGIN_NAME のエントリがある"
    else
        ok "M-1 marketplace.json に $PLUGIN_NAME のエントリがある"

        market_name=$(printf '%s\n' "$entry_block" | json_value 'name')
        market_version=$(printf '%s\n' "$entry_block" | json_value 'version')
        market_source=$(printf '%s\n' "$entry_block" | json_value 'source')

        eq "M-1 source が plugins/<name>" "plugins/$PLUGIN_NAME" "$market_source"

        if [ -f "$REPO_ROOT/$market_source/plugin.json" ]; then
            ok "M-1 source の plugin.json が実在する（$market_source/plugin.json）"
        else
            ng "M-1 source の plugin.json が実在する（未検出: $market_source/plugin.json）"
        fi

        eq "M-2 marketplace の name が plugin.json と一致" "$name_value" "$market_name"
        eq "M-2 marketplace の version が plugin.json と一致" "$version_value" "$market_version"
    fi
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
