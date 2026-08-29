#!/usr/bin/env bash
set -euo pipefail

# github-issue 登録スクリプト
# バリデーションを実行し、合格した場合のみ gh で Issue を登録します
# バリデーションでエラーがあれば登録を拒否します

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-issue.sh"

# ---------- 引数の確認 ----------

if [ $# -eq 0 ]; then
    echo -e "${RED}エラー: Issue ファイルのパスを指定してください${NC}"
    echo "使用方法: $0 <issue-file> [--dry-run]"
    exit 1
fi

ISSUE_FILE="$1"
shift

DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        *)
            echo -e "${RED}エラー: 不明なオプションです: $1${NC}"
            echo "使用方法: $0 <issue-file> [--dry-run]"
            exit 1
            ;;
    esac
    shift
done

if [ ! -f "$ISSUE_FILE" ]; then
    echo -e "${RED}エラー: ファイルが見つかりません: $ISSUE_FILE${NC}"
    exit 1
fi

# ---------- バリデーション（必須） ----------

echo -e "${CYAN}--- バリデーション ---${NC}"
if ! bash "$VALIDATE_SCRIPT" "$ISSUE_FILE"; then
    echo ""
    echo -e "${RED}✗ バリデーションに失敗したため、Issue を登録しません${NC}"
    echo -e "${RED}  フォーマットを修正してから再実行してください${NC}"
    exit 1
fi
echo -e "${GREEN}✓ バリデーション合格${NC}"
echo ""

# ---------- 前提条件の確認 ----------

# gh のインストール確認
if ! command -v gh &>/dev/null; then
    echo -e "${RED}✗ GitHub CLI (gh) がインストールされていません${NC}"
    echo "  インストール: https://cli.github.com/"
    exit 1
fi

# gh の認証確認
if ! gh auth status &>/dev/null; then
    echo -e "${RED}✗ gh の認証が完了していません${NC}"
    echo "  gh auth login を実行してください"
    exit 1
fi

# リポジトリルートへ移動
if ! REPO_ROOT=$(git rev-parse --show-toplevel); then
    echo -e "${RED}✗ Git リポジトリ内で実行してください${NC}"
    exit 1
fi
cd "$REPO_ROOT"

# ---------- フロントマターの抽出 ----------

SECOND_DASH=$(grep -n '^---$' "$ISSUE_FILE" | sed -n '2p' | cut -d: -f1)

# タイトル・ラベルの抽出
FRONTMATTER=$(sed -n "2,$((SECOND_DASH-1))p" "$ISSUE_FILE")
TITLE=$(echo "$FRONTMATTER" | grep '^title:' | head -1 | sed 's/^title:[[:space:]]*//; s/^"//; s/"$//')
LABELS=$(echo "$FRONTMATTER" | grep '^[[:space:]]*- ' | sed 's/^[[:space:]]*-[[:space:]]*//' | tr '\n' ',' | sed 's/,$//')

# 本文（frontmatter を除く）を一時ファイルへ
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT
sed -n "$((SECOND_DASH+1)),\$p" "$ISSUE_FILE" > "$BODY_FILE"

# ---------- ラベルの存在確認と自動作成 ----------

# ラベルごとの色定義（既存ラベルと衝突しないようにスキル専用色を使用）
declare -A LABEL_COLOR=(
    ["article"]="0e8a16"
    ["enhancement"]="a2eeef"
    ["bug"]="d73a4a"
    ["task"]="1d76db"
    ["question"]="d876e3"
)

if [ -n "$LABELS" ]; then
    echo -e "${CYAN}--- ラベル確認 ---${NC}"
    # リポジトリの既存ラベルを取得
    EXISTING_LABELS=$(gh label list --json name -q '.[].name' 2>/dev/null || true)

    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    for L in "${LABEL_ARRAY[@]}"; do
        L=$(echo "$L" | xargs) # 前後スペース除去
        if echo "$EXISTING_LABELS" | grep -qx "$L"; then
            echo -e "${GREEN}✓ ラベルは既に存在します: $L${NC}"
        else
            COLOR="${LABEL_COLOR[$L]:-5319e7}"
            echo -e "${YELLOW}⚠ ラベルが存在しないため作成します: $L${NC}"
            gh label create "$L" --color "$COLOR" --description "github-issueスキルにより自動作成" || {
                echo -e "${RED}✗ ラベルの作成に失敗しました: $L${NC}"
                exit 1
            }
        fi
    done
    echo ""
fi

# ---------- 登録内容の表示 ----------

echo -e "${CYAN}--- 登録内容 ---${NC}"
echo -e "${YELLOW}Title:${NC}  $TITLE"
echo -e "${YELLOW}Labels:${NC} $LABELS"
echo -e "${YELLOW}Body:${NC}"
echo "----------------------------------------"
cat "$BODY_FILE"
echo "----------------------------------------"
echo ""

# ---------- Issue の登録 ----------

# --dry-run の場合は登録せずに終了
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${YELLOW}--dry-run のため、Issue は登録しません（プレビュー結果は上記の通りです）${NC}"
    exit 0
fi

echo -e "${CYAN}--- Issue を登録します ---${NC}"
gh issue create \
    --title "$TITLE" \
    --label "$LABELS" \
    --body-file "$BODY_FILE"

echo ""
echo -e "${GREEN}✓ Issue を登録しました${NC}"
