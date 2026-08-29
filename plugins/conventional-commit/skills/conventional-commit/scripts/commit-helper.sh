#!/usr/bin/env bash
set -euo pipefail

# conventional-commit ヘルパースクリプト
# コミット対象の変更内容を可視化します

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  コミット準備 - 変更内容の確認${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# リポジトリ状態の確認
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}エラー: Git リポジトリ内で実行してください${NC}"
    exit 1
fi

# ブランチ名
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "(detached HEAD)")
echo -e "${YELLOW}ブランチ:${NC} $BRANCH"
echo ""

# 未追跡ファイルを含む変更状況
echo -e "${YELLOW}変更状態:${NC}"
git status --short 2>/dev/null || echo "  変更はありません"
echo ""

# ステージング済みの差分（統計）
if git diff --cached --stat 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}ステージング済みの変更:${NC}"
    git diff --cached --stat
    echo ""
fi

# ステージング前の差分（統計）
if git diff --stat 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}ステージング前の変更:${NC}"
    git diff --stat
    echo ""
fi

# 直近のコミット
echo -e "${YELLOW}直近のコミット:${NC}"
git log --oneline -3 2>/dev/null || echo "  コミット履歴がありません"
echo ""

# 本ブランチの未プッシュコミット
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)
if [ -n "$UPSTREAM" ]; then
    AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
    if [ "$AHEAD" -gt 0 ]; then
        echo -e "${YELLOW}未プッシュのコミット:${NC} ${AHEAD}件"
        git log --oneline @{upstream}..HEAD 2>/dev/null
        echo ""
    fi
fi

# コミットメッセージの参考例
echo -e "${CYAN}----------------------------------------${NC}"
echo -e "${CYAN}  コミットメッセージの例${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo ""
echo -e "  ${GREEN}feat${NC}: ユーザー検索機能を追加"
echo -e "  ${GREEN}fix${NC}: ログアウト時のエラーを修正"
echo -e "  ${GREEN}docs${NC}(readme): セットアップ手順を更新"
echo -e "  ${GREEN}refactor${NC}: ユーザー取得処理を関数化"
echo -e "  ${GREEN}style${NC}: インデントを修正"
echo ""
echo -e "  type 一覧: feat fix docs style refactor perf test build ci chore revert"
echo ""
