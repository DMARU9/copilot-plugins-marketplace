#!/usr/bin/env bash
# decide.sh — 配置判定コード
#
# 4 つの質問への回答（governance / orchestration / reusable / needs_code）を受け取り、
# 配置先と適用した分岐を機械可読な key=value 形式で返す（FR-016）。
# 判断基準の正は references/criteria.md であり、このスクリプトと同じ規則を実装している
# （同期は tests/test_criteria_sync.sh が強制する）。
#
# 設計上の制約（憲章 VII / plan.md）:
#   - bash 3.2 以上で動作させるため declare -A（連想配列）を使わない。分岐は case 文で表す
#   - 出力は ASCII の識別子のみ。ロケール・カレントディレクトリ・時刻に依存しない
#   - 追加依存なし（ネットワーク不要）
#
# 終了コード: 0 = 判定または問い返し / 2 = 入力が不正

set -uo pipefail

# 自身の位置を基準にパスを解決する（憲章 I: カレントディレクトリに依存しない）
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

governance="unknown"
orchestration="unknown"
reusable="unknown"
needs_code="unknown"

governance_set=0
orchestration_set=0
reusable_set=0
needs_code_set=0

usage() {
    cat <<USAGE
decide.sh — 配置判定コード（$SCRIPT_DIR/decide.sh）

Usage: decide.sh [OPTIONS]

Options:
  --governance <yes|no|unknown>      実行前検証・権限・外部接続を伴うか
  --orchestration <yes|no|unknown>   タスクの分解・委任・統合か
  --reusable <yes|no|unknown>        他のサブエージェントでも使いそうか
  --needs-code <yes|no|unknown>      決定論的な実行コードが必要か
  -h, --help                         この使用方法を表示する

省略したオプションは unknown と同義です。値は小文字のみ受理します。
USAGE
}

# 不正な入力は fail-closed で拒否する（憲章 III）。理由は stderr に出し、stdout は空にする
die() {
    printf '%s\n' "decide.sh: $1" >&2
    exit 2
}

validate_value() { # $1=オプション名 $2=値
    case "$2" in
        yes|no|unknown) ;;
        *) die "$1 の値が不正です: '$2'（yes / no / unknown のいずれかを指定してください）" ;;
    esac
}

# ---------- 引数の解析 ----------

while [ $# -gt 0 ]; do
    case "$1" in
        --governance)
            [ $# -ge 2 ] || die "--governance には値が必要です"
            validate_value "--governance" "$2"
            [ "$governance_set" -eq 0 ] || die "--governance が重複して指定されました"
            governance="$2"
            governance_set=1
            shift 2
            ;;
        --orchestration)
            [ $# -ge 2 ] || die "--orchestration には値が必要です"
            validate_value "--orchestration" "$2"
            [ "$orchestration_set" -eq 0 ] || die "--orchestration が重複して指定されました"
            orchestration="$2"
            orchestration_set=1
            shift 2
            ;;
        --reusable)
            [ $# -ge 2 ] || die "--reusable には値が必要です"
            validate_value "--reusable" "$2"
            [ "$reusable_set" -eq 0 ] || die "--reusable が重複して指定されました"
            reusable="$2"
            reusable_set=1
            shift 2
            ;;
        --needs-code)
            [ $# -ge 2 ] || die "--needs-code には値が必要です"
            validate_value "--needs-code" "$2"
            [ "$needs_code_set" -eq 0 ] || die "--needs-code が重複して指定されました"
            needs_code="$2"
            needs_code_set=1
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "不明なオプションです: '$1'"
            ;;
    esac
done

# ---------- 評価（FR-021: この順序を変えてはならない） ----------

# 1. ガバナンス該当性（最初のゲート。該当すれば reusable を評価しない: FR-022）
case "$governance" in
    unknown)
        printf 'result=ask\nmissing=governance\n'
        exit 0
        ;;
    yes)
        printf 'result=decision\ntarget=subagent-definition\nreason=governance\nbranches=governance=yes\n'
        exit 0
        ;;
esac

# 2. タスクの分解・委任・統合か
case "$orchestration" in
    unknown)
        printf 'result=ask\nmissing=orchestration\n'
        exit 0
        ;;
    yes)
        printf 'result=decision\ntarget=orchestrator\nreason=orchestration\nbranches=governance=no,orchestration=yes\n'
        exit 0
        ;;
esac

# 3. 他のサブエージェントでも使うか
case "$reusable" in
    unknown)
        printf 'result=ask\nmissing=reusable\n'
        exit 0
        ;;
    no)
        printf 'result=decision\ntarget=subagent-definition\nreason=not-reusable\nbranches=governance=no,orchestration=no,reusable=no\n'
        exit 0
        ;;
esac

# 4. 決定論的な実行コードが必要か（reusable=yes のときのみ到達する）
case "$needs_code" in
    unknown)
        printf 'result=ask\nmissing=needs_code\n'
        ;;
    yes)
        printf 'result=decision\ntarget=skill-scripts\nreason=reusable-with-code\nbranches=governance=no,orchestration=no,reusable=yes,needs_code=yes\n'
        ;;
    no)
        printf 'result=decision\ntarget=skill-instructions\nreason=reusable-instructions\nbranches=governance=no,orchestration=no,reusable=yes,needs_code=no\n'
        ;;
esac

exit 0
