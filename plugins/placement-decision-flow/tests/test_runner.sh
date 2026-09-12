#!/usr/bin/env bash
# test_runner.sh — テストランナーの探索を固定する自己検証（憲章 V）
#
# tests/ に一時的なテストファイル（test_zz_probe.sh）を作り、run.sh が
# 新規に追加されたテストを探索して実行することを確認する。探索されなければ失敗する。
# 検証後は一時ファイルを削除して元の状態に戻す。
#
# 注意: このファイル自身も run.sh の収集対象（tests/test_*.sh）であるため、
# 入れ子実行の無限再帰を避けるためのガードを先頭に置く。

set -uo pipefail

if [ "${PLACEMENT_DF_TEST_NESTED:-}" = "1" ]; then
    # 入れ子の run.sh から呼ばれた場合は自己検証をスキップする
    echo "  (nested: 探索の自己検証はスキップ)"
    exit 0
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUNNER="$SCRIPT_DIR/run.sh"
PROBE="$SCRIPT_DIR/test_zz_probe.sh"
MARKER=$(mktemp)

cleanup() {
    rm -f "$PROBE" "$MARKER"
}
trap cleanup EXIT

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ng() { echo "  NG: $1"; fail=$((fail + 1)); }

echo "=== test_runner.sh ==="

if [ ! -f "$RUNNER" ]; then
    ng "run.sh が存在する（$RUNNER）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# ---------- 1. 探索されて実行されること ----------

cat > "$PROBE" <<PROBE_EOF
#!/usr/bin/env bash
echo "probe-executed" >> "$MARKER"
exit 0
PROBE_EOF
chmod +x "$PROBE"

if [ -f "$PROBE" ]; then
    ok "一時テストファイルを追加した（test_zz_probe.sh）"
else
    ng "一時テストファイルを追加できなかった"
fi

rm -f "$MARKER"
runner_output=$(PLACEMENT_DF_TEST_NESTED=1 bash "$RUNNER" 2>&1)
runner_status=$?

if printf '%s' "$runner_output" | grep -qE 'PASS.*test_zz_probe\.sh'; then
    ok "run.sh が新規テストを探索して PASS として報告する"
else
    ng "run.sh が新規テストを探索していない"
fi

if [ -s "$MARKER" ]; then
    ok "新規テストの本体が実際に実行された（マーカーを検出）"
else
    ng "新規テストの本体が実行されていない"
fi

if [ "$runner_status" -eq 0 ]; then
    ok "新規テストを追加した run.sh は 0 で終了する"
else
    ng "run.sh が非ゼロで終了した（status=$runner_status）"
fi

# ---------- 2. 失敗する新規テストを検出すること ----------

cat > "$PROBE" <<'PROBE_EOF'
#!/usr/bin/env bash
exit 1
PROBE_EOF
chmod +x "$PROBE"

runner_output=$(PLACEMENT_DF_TEST_NESTED=1 bash "$RUNNER" 2>&1)
runner_status=$?

if printf '%s' "$runner_output" | grep -qE 'FAIL.*test_zz_probe\.sh'; then
    ok "失敗する新規テストを FAIL として報告する"
else
    ng "失敗する新規テストが FAIL として報告されない"
fi

if [ "$runner_status" -ne 0 ]; then
    ok "失敗する新規テストがあると run.sh は非ゼロで終了する（status=$runner_status）"
else
    ng "run.sh が非ゼロで終了しなかった"
fi

# ---------- 3. 実行ビットの無いテストを検出すること ----------

cat > "$PROBE" <<'PROBE_EOF'
#!/usr/bin/env bash
exit 0
PROBE_EOF
chmod -x "$PROBE"

runner_output=$(PLACEMENT_DF_TEST_NESTED=1 bash "$RUNNER" 2>&1)

if printf '%s' "$runner_output" | grep -qE 'FAIL.*test_zz_probe\.sh' &&
   printf '%s' "$runner_output" | grep -q '実行ビット'; then
    ok "実行ビットの無いテストを検出する"
else
    ng "実行ビットの無いテストが検出されない"
fi

# ---------- 4. 後始末（元の状態に戻す） ----------

rm -f "$PROBE"

if [ ! -f "$PROBE" ]; then
    ok "一時テストファイルを削除して元に戻した"
else
    ng "一時テストファイルが残っている"
fi

runner_output=$(PLACEMENT_DF_TEST_NESTED=1 bash "$RUNNER" 2>&1)
runner_status=$?

if [ "$runner_status" -eq 0 ]; then
    ok "後始末後の run.sh は 0 で終了する"
else
    ng "後始末後の run.sh が非ゼロで終了した（status=$runner_status）"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
