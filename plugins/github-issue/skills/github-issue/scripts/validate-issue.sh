#!/usr/bin/env bash
set -euo pipefail

# github-issue バリデーションスクリプト
# Issue ファイルが定められたフォーマットに従っているかをチェックします
# エラーが1件でもあれば終了コード 1 を返します（登録を拒否）

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- フォーマット定義（SKILL.md と必ず同期する） ----------

# 種別 → ラベル
declare -A TYPE_LABEL=(
    ["企画"]="article"
    ["改善"]="enhancement"
    ["バグ"]="bug"
    ["タスク"]="task"
    ["質問"]="question"
)

# 種別 → 必須セクション（順序もこの通り）
declare -A TYPE_SECTIONS=(
    ["企画"]="概要 方針 タスク 完了条件"
    ["改善"]="概要 現状の課題 改善案 完了条件"
    ["バグ"]="概要 再現手順 期待する動作 実際の動作"
    ["タスク"]="概要 タスク 完了条件"
    ["質問"]="概要 質問内容"
)

# チェックリスト（- [ ]）を必須とする種別
CHECKLIST_TYPES="企画 タスク"

# 使用可能なラベル
VALID_LABELS="article enhancement bug task question"

# タイトルの最大文字数
MAX_TITLE_LEN=60
WARN_TITLE_LEN=40

# 本文の最小文字数
MIN_BODY_LEN=100

# ---------- メイン処理 ----------

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  GitHub Issue フォーマット検証${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 引数の確認
if [ $# -eq 0 ]; then
    echo -e "${RED}エラー: Issue ファイルのパスを指定してください${NC}"
    echo "使用方法: $0 <issue-file>"
    exit 1
fi

ISSUE_FILE="$1"

# ファイルの存在確認
if [ ! -f "$ISSUE_FILE" ]; then
    echo -e "${RED}エラー: ファイルが見つかりません: $ISSUE_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}チェック対象:${NC} $ISSUE_FILE"
echo ""

ERRORS=0
WARNINGS=0

# ---------- フロントマターの抽出 ----------

# ファイルが --- で始まるか
if [ "$(head -1 "$ISSUE_FILE")" != "---" ]; then
    echo -e "${RED}✗ フロントマター（---）で始まっていません${NC}"
    ((ERRORS++)) || true
fi

# 2つ目の --- の行番号を探す
SECOND_DASH=$(grep -n '^---$' "$ISSUE_FILE" | sed -n '2p' | cut -d: -f1 || true)
if [ -z "$SECOND_DASH" ]; then
    echo -e "${RED}✗ フロントマターの終端（---）が見つかりません${NC}"
    ((ERRORS++)) || true
    SECOND_DASH=0
fi

FRONTMATTER=""
BODY=""
if [ "$SECOND_DASH" -gt 1 ]; then
    FRONTMATTER=$(sed -n "2,$((SECOND_DASH-1))p" "$ISSUE_FILE")
    BODY=$(sed -n "$((SECOND_DASH+1)),\$p" "$ISSUE_FILE")
fi

# ---------- タイトルの抽出 ----------

TITLE=""
if [ -n "$FRONTMATTER" ]; then
    TITLE=$(echo "$FRONTMATTER" | grep '^title:' | head -1 | sed 's/^title:[[:space:]]*//; s/^"//; s/"$//')
fi

# ---------- ラベルの抽出 ----------

LABELS=""
if [ -n "$FRONTMATTER" ]; then
    LABELS=$(echo "$FRONTMATTER" | grep '^[[:space:]]*- ' | sed 's/^[[:space:]]*-[[:space:]]*//')
fi

echo -e "${CYAN}----------------------------------------${NC}"
echo -e "${CYAN}  タイトルチェック${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

# --- タイトルの存在 ---
if [ -z "$TITLE" ]; then
    echo -e "${RED}✗ title が設定されていません${NC}"
    ((ERRORS++)) || true
else
    echo -e "${YELLOW}タイトル:${NC} $TITLE"

    # --- 種別（接頭辞）のチェック ---
    TYPE=$(echo "$TITLE" | sed -n 's/^\[\([^]]*\)\].*/\1/p')

    if [ -z "$TYPE" ]; then
        echo -e "${RED}✗ タイトル先頭に種別がありません（[企画] / [改善] / [バグ] / [タスク] / [質問]）${NC}"
        ((ERRORS++)) || true
    elif [ -z "${TYPE_LABEL[$TYPE]:-}" ]; then
        echo -e "${RED}✗ 種別が不正です: $TYPE（[企画] / [改善] / [バグ] / [タスク] / [質問] のみ）${NC}"
        ((ERRORS++)) || true
    else
        echo -e "${GREEN}✓ 種別 [$TYPE] は有効です${NC}"
    fi

    # --- タイトルの長さ ---
    LEN=${#TITLE}
    if [ "$LEN" -gt "$MAX_TITLE_LEN" ]; then
        echo -e "${RED}✗ タイトルが長すぎます ($LEN/$MAX_TITLE_LEN 文字)${NC}"
        ((ERRORS++)) || true
    elif [ "$LEN" -gt "$WARN_TITLE_LEN" ]; then
        echo -e "${YELLOW}⚠ タイトルが長めです ($LEN/$MAX_TITLE_LEN 文字)${NC}"
        ((WARNINGS++)) || true
    else
        echo -e "${GREEN}✓ タイトルの長さは適切です ($LEN 文字)${NC}"
    fi

    # --- タイトル末尾の句点 ---
    if [[ "$TITLE" =~ [。.]$ ]]; then
        echo -e "${RED}✗ タイトルの末尾に句点（。.）を付けないでください${NC}"
        ((ERRORS++)) || true
    fi

    # --- タイトル内のプレースホルダー ---
    if echo "$TITLE" | grep -q '{{'; then
        echo -e "${RED}✗ タイトルにプレースホルダーが残っています${NC}"
        ((ERRORS++)) || true
    fi
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo -e "${CYAN}  ラベルチェック${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

# --- ラベルの存在 ---
if [ -z "$LABELS" ]; then
    echo -e "${RED}✗ labels が設定されていません${NC}"
    ((ERRORS++)) || true
else
    # --- ラベルの妥当性 ---
    LABEL_OK=1
    for L in $LABELS; do
        if echo "$VALID_LABELS" | grep -qw "$L"; then
            echo -e "${GREEN}✓ ラベル: $L${NC}"
        else
            echo -e "${RED}✗ ラベルが不正です: $L（article / enhancement / bug / task / question のみ）${NC}"
            ((ERRORS++)) || true
            LABEL_OK=0
        fi
    done

    # --- 種別とラベルの整合性 ---
    if [ -n "$TYPE" ] && [ -n "${TYPE_LABEL[$TYPE]:-}" ]; then
        EXPECTED="${TYPE_LABEL[$TYPE]}"
        if echo "$LABELS" | grep -qw "$EXPECTED"; then
            echo -e "${GREEN}✓ 種別 [$TYPE] に対応するラベル ($EXPECTED) が含まれています${NC}"
        else
            echo -e "${RED}✗ 種別 [$TYPE] に対応するラベル ($EXPECTED) が含まれていません${NC}"
            ((ERRORS++)) || true
        fi
    fi
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo -e "${CYAN}  本文チェック${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

# --- 必須セクション ---
if [ -n "$TYPE" ] && [ -n "${TYPE_SECTIONS[$TYPE]:-}" ]; then
    echo -e "${YELLOW}必須セクション (種別 [$TYPE]):${NC}"
    for SECTION in ${TYPE_SECTIONS[$TYPE]}; do
        if echo "$BODY" | grep -q "^## ${SECTION}$"; then
            echo -e "${GREEN}  ✓ ## $SECTION${NC}"
        else
            echo -e "${RED}  ✗ ## $SECTION がありません${NC}"
            ((ERRORS++)) || true
        fi
    done
fi

# --- H1 見出しの禁止 ---
if echo "$BODY" | grep -q '^# '; then
    echo -e "${RED}✗ 本文に H1 見出し（# ）が含まれています（タイトルは frontmatter で指定します）${NC}"
    ((ERRORS++)) || true
fi

# --- チェックリスト ---
if [ -n "$TYPE" ] && echo " $CHECKLIST_TYPES " | grep -q " $TYPE "; then
    CHECK_COUNT=$(echo "$BODY" | grep -c '^- \[ \]' || true)
    if [ "$CHECK_COUNT" -ge 1 ]; then
        echo -e "${GREEN}✓ チェックリスト（- [ ]）が ${CHECK_COUNT} 項目あります${NC}"
    else
        echo -e "${RED}✗ チェックリスト（- [ ]）がありません（種別 [$TYPE] では必須です）${NC}"
        ((ERRORS++)) || true
    fi
fi

# --- プレースホルダー ---
if echo "$BODY" | grep -q '{{\|TODO'; then
    echo -e "${RED}✗ 本文にプレースホルダー（{{...}} や TODO）が残っています${NC}"
    ((ERRORS++)) || true
else
    echo -e "${GREEN}✓ プレースホルダーは残っていません${NC}"
fi

# --- 本文の分量 ---
BODY_LEN=$(echo -n "$BODY" | wc -m)
if [ -z "$BODY" ]; then
    echo -e "${RED}✗ 本文が空です${NC}"
    ((ERRORS++)) || true
elif [ "$BODY_LEN" -lt "$MIN_BODY_LEN" ]; then
    echo -e "${RED}✗ 本文が短すぎます ($BODY_LEN/$MIN_BODY_LEN 文字)。必要な情報を記入してください${NC}"
    ((ERRORS++)) || true
else
    echo -e "${GREEN}✓ 本文の分量は十分です ($BODY_LEN 文字)${NC}"
fi

# --- フロントマターのキー ---
if [ -n "$FRONTMATTER" ]; then
    UNKNOWN_KEYS=$(echo "$FRONTMATTER" | grep -E '^[a-zA-Z_-]+:' | grep -v '^title:' | grep -v '^labels:' || true)
    if [ -n "$UNKNOWN_KEYS" ]; then
        echo -e "${RED}✗ 不明なフロントマターキーがあります: $(echo "$UNKNOWN_KEYS" | tr '\n' ' ')${NC}"
        ((ERRORS++)) || true
    fi
fi

# ---------- 結果 ----------

echo ""
echo -e "${CYAN}========================================${NC}"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ すべてのチェックに合格しました${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ 警告: ${WARNINGS} 件${NC}"
    echo -e "${GREEN}✓ エラーはありません（登録可能です）${NC}"
else
    echo -e "${RED}✗ エラー: ${ERRORS} 件${NC}"
    [ "$WARNINGS" -gt 0 ] && echo -e "${YELLOW}⚠ 警告: ${WARNINGS} 件${NC}"
    echo -e "${RED}エラーを修正してから再実行してください${NC}"
fi

echo -e "${CYAN}========================================${NC}"

# エラーがあれば終了コード 1（登録を拒否）
if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
