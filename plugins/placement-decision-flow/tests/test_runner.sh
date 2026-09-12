#!/usr/bin/env bash
# test_runner.sh — テストランナーの探索を固定する自己検証（憲章 V）
#
# tests/ に一時的なテストファイル（test_zz_probe.sh）を作り、run.sh が
# 新規に追加されたテストを探索して実行することを確認する。探索されなければ失敗する。
# 検証後は一時ファイルを削除して元の状態に戻す。
#
# 注意 1: このファイル自身も run.sh の収集対象（tests/test_*.sh）であるため、
#         入れ子実行の無限再帰を避けるためのガードを先頭に置く。
# 注意 2: スイート全体の合否に依存させないため、「run.sh の FAIL 件数の差分」で
#         一時テストの寄与を測る。

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

# run.sh の集計行（最後に出力される PASS/FAIL 行）から FAIL 件数を取り出す
runner_fail_count() {
    printf '%s\n' "$1" | sed -n 's/^PASS: [0-9][0-9]*  FAIL: \([0-9][0-9]*\)$/\1/p' | tail -1
}

run_runner() {
    PLACEMENT_DF_TEST_NESTED=1 bash "$RUNNER" 2>&1
}

echo "=== test_runner.sh ==="

if [ ! -f "$RUNNER" ]; then
    ng "run.sh が存在する（$RUNNER）"
    echo "PASS: $pass  FAIL: $fail"
    exit 1
fi

# ---------- 0. ベースライン（一時テストなし） ----------

baseline_output=$(run_runner)
baseline_fail=$(runner_fail_count "$baseline_output")

if [ -n "$baseline_fail" ]; then
    ok "run.sh の集計行から FAIL 件数を取得できる（ベースライン: $baseline_fail）"
else
    ng "run.sh の集計行を解析できない"
    baseline_fail=0
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
passing_output=$(run_runner)
passing_fail=$(runner_fail_count "$passing_output")

if printf '%s' "$passing_output" | grep -qE 'PASS.*test_zz_probe\.sh'; then
    ok "run.sh が新規テストを探索して PASS として報告する"
else
    ng "run.sh が新規テストを探索していない"
fi

if [ -s "$MARKER" ]; then
    ok "新規テストの本体が実際に実行された（マーカーを検出）"
else
    ng "新規テストの本体が実行されていない"
fi

if [ "$passing_fail" = "$baseline_fail" ]; then
    ok "pass する新規テストは FAIL 件数を増やさない"
else
    ng "pass する新規テストが FAIL 件数を変えた（$baseline_fail → $passing_fail）"
fi

# ---------- 2. 失敗する新規テストを検出すること ----------

cat > "$PROBE" <<'PROBE_EOF'
#!/usr/bin/env bash
exit 1
PROBE_EOF
chmod +x "$PROBE"

failing_output=$(run_runner)
failing_fail=$(runner_fail_count "$failing_output")

if printf '%s' "$failing_output" | grep -qE 'FAIL.*test_zz_probe\.sh'; then
    ok "失敗する新規テストを FAIL として報告する"
else
    ng "失敗する新規テストが FAIL として報告されない"
fi

expected_fail=$((baseline_fail + 1))
if [ "$failing_fail" = "$expected_fail" ]; then
    ok "失敗する新規テストは FAIL 件数を 1 増やす（$baseline_fail → $failing_fail）"
else
    ng "FAIL 件数の増分が 1 でない（$baseline_fail → $failing_fail、期待 $expected_fail）"
fi

# ---------- 3. 実行ビットの無いテストを検出すること ----------

cat > "$PROBE" <<'PROBE_EOF'
#!/usr/bin/env bash
exit 0
PROBE_EOF
chmod -x "$PROBE"

noexec_output=$(run_runner)
noexec_fail=$(runner_fail_count "$noexec_output")

if printf '%s' "$noexec_output" | grep -qE 'FAIL.*test_zz_probe\.sh' &&
   printf '%s' "$noexec_output" | grep -q '実行ビット'; then
    ok "実行ビットの無いテストを検出する"
else
    ng "実行ビットの無いテストが検出されない"
fi

if [ "$noexec_fail" = "$expected_fail" ]; then
    ok "実行ビットの無いテストも FAIL として集計される（$noexec_fail）"
else
    ng "実行ビットの無いテストの集計が想定と異なる（$noexec_fail、期待 $expected_fail）"
fi

# ---------- 4. 後始末（元の状態に戻す） ----------

rm -f "$PROBE"

if [ ! -f "$PROBE" ]; then
    ok "一時テストファイルを削除して元に戻した"
else
    ng "一時テストファイルが残っている"
fi

final_output=$(run_runner)
final_fail=$(runner_fail_count "$final_output")

if printf '%s' "$final_output" | grep -q 'test_zz_probe\.sh'; then
    ng "後始末後も一時テストが探索されている"
else
    ok "後始末後は一時テストが探索されない"
fi

if [ "$final_fail" = "$baseline_fail" ]; then
    ok "後始末後の FAIL 件数がベースラインに戻る（$final_fail）"
else
    ng "後始末後の FAIL 件数が戻らない（$final_fail、期待 $baseline_fail）"
fi

echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
