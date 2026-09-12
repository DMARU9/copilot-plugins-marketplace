#!/usr/bin/env bash
# placement-decision-flow テストランナー
#
# tests/test_*.sh をディレクトリ探索で自動収集し、ファイル名の昇順に実行する。
# 成功・失敗件数を集計し、失敗が 1 件でもあれば非ゼロで終了する。
#
# 追加の依存を持ち込まない（憲章 VII）。bash 3.2 以上で動作する。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  placement-decision-flow テスト${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 探索順を環境に依存させないため LC_ALL=C でソートする（憲章 VII）
test_files=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name 'test_*.sh' | LC_ALL=C sort)

if [ -z "$test_files" ]; then
    echo -e "${RED}エラー: テストファイル（tests/test_*.sh）が見つかりません${NC}"
    exit 1
fi

pass_count=0
fail_count=0
failed_names=""

while IFS= read -r test_file; do
    [ -n "$test_file" ] || continue
    test_name=$(basename "$test_file")

    # 実行ビットの確認（README の chmod +x が守られているか）
    if [ ! -x "$test_file" ]; then
        echo -e "${RED}FAIL${NC} $test_name （実行ビットがありません。chmod +x してください）"
        fail_count=$((fail_count + 1))
        failed_names="${failed_names}
  - ${test_name}（実行ビットなし）"
        continue
    fi

    if bash "$test_file"; then
        echo -e "${GREEN}PASS${NC} $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}FAIL${NC} $test_name"
        fail_count=$((fail_count + 1))
        failed_names="${failed_names}
  - ${test_name}"
    fi
done <<< "$test_files"

echo ""
echo "----------------------------------------"
echo "PASS: $pass_count  FAIL: $fail_count"
echo "----------------------------------------"

if [ "$fail_count" -gt 0 ]; then
    echo -e "${RED}失敗したテスト:${NC}${failed_names}"
    exit 1
fi

echo -e "${GREEN}すべてのテストが pass しました${NC}"
exit 0
