# Quickstart: スキルとエージェントの配置判断フロー

**Feature**: `001-placement-decision-flow` | **Date**: 2026-09-12

このドキュメントは、実装が完了したあとに**機能が動くことを確かめる手順**を示す。
契約の詳細は `contracts/`、データの形は `data-model.md` を参照する（ここには重複して書かない）。

---

## 前提条件

| 項目 | 要件 |
|---|---|
| シェル | bash 3.2 以上（**`declare -A` を使わない**ため macOS 標準の bash でも動く） |
| コマンド | `git`、`find`、`sed`、`grep`、`sort` |
| 追加依存 | なし（ネットワークアクセス不要） |
| 対象 | 作業ディレクトリは `copilot-plugins-marketplace` のルート |

---

## セットアップ

```bash
cd /home/takumi/github/copilot-plugins-marketplace

# 実行ビットを立てる
chmod +x plugins/placement-decision-flow/skills/placement-decision-flow/scripts/*.sh
chmod +x plugins/placement-decision-flow/tests/run.sh plugins/placement-decision-flow/tests/test_*.sh
```

---

## 検証 1: 判定コードが 4 分類を正しく返す（FR-001 / FR-002 / FR-003 / SC-001 / SC-005）

`decide.sh` を代表的な入力で実行し、`target` と `reason` を確認する。

```bash
D=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh

$D --governance yes
$D --governance no --orchestration yes
$D --governance no --orchestration no --reusable yes --needs-code yes
$D --governance no --orchestration no --reusable yes --needs-code no
$D --governance no --orchestration no --reusable no
```

**期待される結果**: 終了コードはすべて `0` で、`target` が順に
`subagent-definition` / `orchestrator` / `skill-scripts` / `skill-instructions` /
`subagent-definition` になる。`branches` には**評価した分岐だけ**が評価順で並ぶ
（1 番目の入力では `branches=governance=yes` のみ）。

4 回とも**完全な回答を 1 回渡すだけで配置先が確定する**（`result=ask` を経由しない）
ことが **SC-001**（代表的な4種類の処理すべてで 1 回の相談で確定）の測定になる。
`result=ask` を許容するのは回答に `unknown` を含む入力だけである。

---

## 検証 2: ガバナンスが最初のゲートになる（FR-005 / FR-021 / FR-022 / SC-002 / SC-010）

「使い回せる」かつ「実行コードが必要」でも、ガバナンスに該当すればサブエージェント定義に
確定することを確認する。

```bash
D=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh

$D --governance yes --reusable yes --needs-code yes
```

**期待される結果**: `target=subagent-definition`、`reason=governance`、
`branches=governance=yes`。`reusable` と `needs_code` は `branches` に現れない（短絡した証拠）。

---

## 検証 3: 情報が不足したら問い返す（FR-006 / FR-012 / SC-007）

```bash
D=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh

$D
$D --governance no --orchestration unknown
```

**期待される結果**: どちらも `result=ask`、`missing=governance` / `missing=orchestration`。
**終了コードは `0`**（判断の保留ではなく正当な結果）。推測した配置先を返してはならない。

---

## 検証 4: 不正な入力は fail-closed で拒否する（憲章 III）

```bash
D=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh

$D --governance maybe     ; echo "exit=$?"
$D --governance YES       ; echo "exit=$?"
$D --unknown-flag yes     ; echo "exit=$?"
$D --governance yes --governance no ; echo "exit=$?"
```

**期待される結果**: すべて `exit=2`、stdout は空、stderr に理由が出る。
**不正な値が黙って既定値に置き換わってはならない**。

---

## 検証 5: 既存スキルの再利用候補を列挙する（FR-009 / FR-010 / SC-003）

```bash
F=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh

$F --root plugins/placement-decision-flow/tests/fixtures/repo
$F --root plugins/placement-decision-flow/tests/fixtures/repo --query review
$F --root plugins/placement-decision-flow/tests/fixtures/repo --query zzz-not-found ; echo "exit=$?"
```

**期待される結果**:
- 1 番目: フィクスチャ内の 2 件が**タブ区切りのリポジトリ相対パス**で、パスの昇順に出力される
- 2 番目: `code-review` の 1 件のみ
- 3 番目: 出力なし（空行も出さない）で `exit=0`

`.github/skills/` 配下が検出されること（ドット始まりを除外していないこと）を確認する。

---

## 検証 6: 対象リポジトリを書き換えない（FR-020）

フィクスチャを一時ディレクトリへ複製し、実行前後でツリーのハッシュを比較する。
（フィクスチャ内で `git init` するとネストしたリポジトリができ、親リポジトリの状態を
汚すため使わない。）

```bash
cd /home/takumi/github/copilot-plugins-marketplace
F="$PWD/plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh"
WORK=$(mktemp -d)
cp -R plugins/placement-decision-flow/tests/fixtures/repo/. "$WORK/"

BEFORE=$(cd "$WORK" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)

"$F" --root "$WORK" --query sample >/dev/null

AFTER=$(cd "$WORK" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)
[ "$BEFORE" = "$AFTER" ] && echo "OK: 書き込みなし" || echo "NG: 書き込まれた"
rm -rf "$WORK"
```

**期待される結果**: `OK: 書き込みなし`。出力パスが絶対パスになっていないことも併せて確認する。

---

## 検証 7: 慣習ディレクトリの実在を報告する（FR-007 / FR-020）

```bash
F=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/find-skills.sh

$F --detect-conventions --root plugins/placement-decision-flow/tests/fixtures/repo
```

**期待される結果**: 常に 4 行（`skill` 2 件、`subagent` 2 件）。`exists` は `yes` / `no`。
`layer` → `path` の昇順。

---

## 検証 8: 判断表と判定コードが同期している（FR-008 / FR-017 / SC-006）

```bash
cd /home/takumi/github/copilot-plugins-marketplace
bash plugins/placement-decision-flow/tests/run.sh
```

**期待される結果**: すべてのテストが pass。特に `test_criteria_sync.sh` が
`references/criteria.md` の表を読み取り、各行を `decide.sh` に流して `target` / `reason` を
照合している。`*` の列には `yes` / `no` / `unknown` の 3 値を流し込む。

**この検証の意味**: 判断表の行を書き換えたり削除したりすると、`decide.sh` を変えていなければ
テストが失敗する。これが FR-017（手順記述とコードの同期）の強制手段になっている。
この実効性は、判断表の `target` を 1 つ書き換える探針で確かめられる（T029 で実測済み）。

```bash
cd /home/takumi/github/copilot-plugins-marketplace
C=plugins/placement-decision-flow/skills/placement-decision-flow/references/criteria.md
cp "$C" /tmp/criteria.bak
sha_before=$(sha256sum "$C" | cut -d' ' -f1)

# 判断表 1 行目の target を書き換える（decide.sh は変えない）
python3 - <<'EOF'
p = "plugins/placement-decision-flow/skills/placement-decision-flow/references/criteria.md"
s = open(p, encoding="utf-8").read()
old = "| yes | * | * | * | subagent-definition | governance |"
new = "| yes | * | * | * | skill-instructions | governance |"
assert s.count(old) == 1, s.count(old)
open(p, "w", encoding="utf-8").write(s.replace(old, new))
EOF
bash plugins/placement-decision-flow/tests/run.sh 2>&1 | tail -5

# 復元（sha256 の一致まで確かめる）
cp /tmp/criteria.bak "$C"
[ "$sha_before" = "$(sha256sum "$C" | cut -d' ' -f1)" ] && echo "OK: 復元（sha256 一致）"
bash plugins/placement-decision-flow/tests/run.sh | tail -3
```

**実測（T029）**: 変異中は `test_criteria_sync.sh` が
`NG: 判断表 1 行目: skill-instructions / governance に一致しない` を出して終了コード非 0
（`tests/run.sh` は終了コードで合否を決めるため `PASS: 6 FAIL: 1`）。復元後は `PASS: 7 FAIL: 0`。
`criteria.md` を書き換えただけでは `decide.sh` は変わらない、という前提が効いている。

**さらに SC-006**（同じ入力に対して別のセッション・別のプロジェクトでも同じ判断）を、
実行ディレクトリを変えても出力が変わらないことで確かめる。

```bash
cd /home/takumi/github/copilot-plugins-marketplace
D="$PWD/plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh"

A=$(cd /tmp && "$D" --governance no --orchestration no --reusable yes --needs-code yes)
B=$(cd ~ && "$D" --governance no --orchestration no --reusable yes --needs-code yes)
[ "$A" = "$B" ] && echo "OK: 実行ディレクトリに依存しない" || echo "NG: 出力が変わった"
```

**期待される結果**: `OK: 実行ディレクトリに依存しない`。カレントディレクトリ・環境変数・
時刻に依存した出力は決定性（FR-008）に反する。
---

## 検証 9: マニフェストの整合性（憲章 II / 憲章 VI）

```bash
cd /home/takumi/github/copilot-plugins-marketplace

# plugin.json と marketplace.json の name/version/source 一致
# （jq を必要としない。M-1 / M-2 が上記の一致を固定している）
bash plugins/placement-decision-flow/tests/test_manifest.sh

# SKILL.md の name と親ディレクトリ名の一致
diff <(grep -m1 '^name:' plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md | sed 's/^name: *//') \
     <(basename plugins/placement-decision-flow/skills/placement-decision-flow) && echo "OK: skill 名一致"

# description に Use when: トリガーがある
grep -q 'Use when:' plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md \
  && echo "OK: Use when: あり"
```

**期待される結果**: `test_manifest.sh` が全 pass（実測: `PASS: 20 FAIL: 0`）、続く 2 つが `OK`。
差分が出ればマニフェスト契約（`contracts/skill-frontmatter.md`）違反。

> **注**: `contracts/skill-frontmatter.md` §5 には `jq -S` を使った等価な確認コマンドが載っている。
> 前提条件に「追加依存なし」を掲げているため、ここでは `jq` を必要としないテストで同じ内容を確かめる
> （`jq` のある環境では契約側のコマンドでも同じ結果になる）。

---

## 検証 10: テストが空虚でないことを変異探針で確かめる（憲章 V）

テストが「実装のコピー」を検証していないことを、**実装を壊して失敗するか**で確かめる。

```bash
cd /home/takumi/github/copilot-plugins-marketplace
S=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh
cp "$S" /tmp/decide.backup
sha_before=$(sha256sum "$S" | cut -d' ' -f1)

# 変異 1: ガバナンスの短絡を外す（governance=yes でも早期に exit 0 しないようにする）
python3 - <<'EOF'
p = "plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh"
s = open(p, encoding="utf-8").read()
old = "reason=governance\\nbranches=governance=yes\\n'\n        exit 0\n"
new = "reason=governance\\nbranches=governance=yes\\n'\n"
assert s.count(old) == 1, s.count(old)  # 置換対象が一意であることを先に確かめる
open(p, "w", encoding="utf-8").write(s.replace(old, new))
EOF
bash plugins/placement-decision-flow/tests/run.sh 2>&1 | tail -8

# 復元して必ずフルスイートを再実行する
cp /tmp/decide.backup "$S"
[ "$sha_before" = "$(sha256sum "$S" | cut -d' ' -f1)" ] && echo "OK: 復元（sha256 一致）"
bash plugins/placement-decision-flow/tests/run.sh && echo "OK: 復元後に全 pass"
```

**期待される結果**: 変異させた状態でテストが**失敗する**（`FAIL` が 1 件以上。実測: `PASS: 4 FAIL: 3`
＝ `test_criteria_sync.sh` / `test_decide.sh` / `test_governance.sh`）。
復元後に**全 pass に戻る**（`PASS: 7 FAIL: 0`）。

> **注意**: 復元後のフルスイート再実行までを 1 セットとする。復元して再実行しないと、
> 「変異で落ちた」のか「元から落ちていた」のかを区別できない。

> **落とし穴**: 変異の対象を「最初に現れる `governance`」のように**出現順で選んではならない**。
> `decide.sh` の最初の `governance` は 4 行目のコメントにあり、そこを書き換えても挙動は変わらないため
> フルスイートは `PASS: 7 FAIL: 0` のままになる（＝探針自身が空虚で、何も証明しない）。
> 変異は**挙動を変える行**に当て、`assert s.count(old) == 1` で一意性を先に確かめる。
>
> また、この探針は**検証専用のツール**として Python 3 を使う（出荷スクリプトは追加依存を持たない）。

---

## 検証 11: 性能目標（SC-004a / SC-004b）

```bash
D=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh
time $D --governance no --orchestration no --reusable yes --needs-code yes
```

**期待される結果**: 実行時間が 1 秒未満（**SC-004b**）。併せて、4 分類それぞれの**完全な入力**を
1 回だけ渡したときに `result=decision` が返ること（追加の問い返し 0 回で確定すること）を確認する
（**SC-004a**。`tests/test_performance.sh` が固定する）。

---

## 検証 12: 指名なしでは起動しない（FR-018 / FR-019 / SC-009）

**これは人手で確認する検証**。AI の起動挙動はシェルスクリプトでは駆動できない。

1. このスキルを**指名せず**、判断が必要そうな文脈を含む別の作業を依頼する
   （例: 「このリポジトリにコード整形のスクリプトを追加して」）
2. 依頼への対応が進むことを確認する

**期待される結果**: 判断フローが自動起動せず、依頼した作業が中断されない。起動は
「どこに置くべきか判断して」のような**明示の指名**があったときに限られる。

---

## 検証 13: AI と判定コードの矛盾が提示される（FR-015 / SC-008）

**これも人手で確認する検証**。`decide.sh` は AI の判断を受け取らないため、矛盾の検出は
AI 側の手順に属し、機械的なテストでは固定できない。

1. `decide.sh` の結論と**異なる配置先**を AI が結論する状況を作る
   （例: ガバナンスに該当する処理について、AI 側で「使い回せる」と解釈してスキルと結論する）
2. 提示内容を確認する

**期待される結果**: 片方を黙って採用せず、**矛盾として両方の結論と採用した基準（コード側）が
提示される**。矛盾があるのに単一の答えだけが示されたら失敗。

---

## 人手確認の記録

| 検証 | 実施日 | 入力 | 観測した挙動 | 判定 |
|---|---|---|---|---|
| 12 | （記入） | （記入） | （記入） | （記入） |
| 13 | （記入） | （記入） | （記入） | （記入） |

> **SC-008 / SC-009 は機械的に測れないため、この記録が無い限り当該 Success Criterion は
> 未検証として扱う**（憲章 IV: 主張には観測結果を添える）。

---

## 完了条件

| 検証 | 対応する要件 |
|---|---|
| 1 | FR-001 / FR-002 / FR-003 / SC-001 / SC-005 |
| 2 | FR-005 / FR-021 / FR-022 / SC-002 / SC-010 |
| 3 | FR-006 / FR-012 / SC-007 |
| 4 | 憲章 III |
| 5 | FR-009 / FR-010 / SC-003 |
| 6 | FR-020 |
| 7 | FR-007 / FR-020 |
| 8 | FR-008 / FR-017 / SC-006 |
| 9 | 憲章 II / 憲章 VI |
| 10 | 憲章 V |
| 11 | SC-004a / SC-004b |
| 12 | FR-018 / FR-019 / SC-009（人手） |
| 13 | FR-015 / SC-008（人手） |

> 検証 12・13 は人手確認であり、`quickstart.md` の「人手確認の記録」に観測結果を残すまで
> 完了としない。

---

## 検証 1〜11 の実施記録（機械的検証）

実施日: 2026-09-12 / 実行環境: bash 5.2.21(1)-release、`jq` なし、`python3` 3.12.3
（作業ディレクトリは `copilot-plugins-marketplace` のルート）。

| 検証 | 実行したコマンドの要点 | 観測結果 | 判定 |
|---|---|---|---|
| 1 | `decide.sh` に 5 通りの完全な入力 | 5 件とも `exit=0`。`target` は `subagent-definition` / `orchestrator` / `skill-scripts` / `skill-instructions` / `subagent-definition`。`branches` は評価した分岐だけを評価順に列挙（例: `branches=governance=yes` のみ） | PASS |
| 2 | `--governance yes --reusable yes --needs-code yes` | `target=subagent-definition` / `reason=governance` / `branches=governance=yes`（`reusable` / `needs_code` は出力に現れない＝短絡の証明） | PASS |
| 3 | 引数なし / `--orchestration unknown` | `result=ask` + `missing=governance` / `missing=orchestration`、ともに `exit=0` | PASS |
| 4 | `maybe` / `YES` / 未知オプション / 重複指定 | 4 件とも `exit=2`、stdout は空、stderr に理由（`decide.sh: ... の値が不正です` 等） | PASS |
| 5 | `--query` あり / なし / 一致 0 件 | 2 件がタブ区切り相対パスの昇順、`--query review` で 1 件、0 件は出力なし（空行もなし）で `exit=0` | PASS |
| 6 | 一時ディレクトリへ複製し前後のツリー sha256 を比較 | `OK: 書き込みなし` | PASS |
| 7 | `--detect-conventions` | 4 行（`skill` 2 / `subagent` 2）、`layer` → `path` の昇順、`exists` は `yes` / `no` | PASS |
| 8 | `tests/run.sh` / 実行ディレクトリを変えて出力比較 | 全テスト pass（`PASS: 7 FAIL: 0`）、`OK: 実行ディレクトリに依存しない` | PASS |
| 9 | `tests/test_manifest.sh` + name 一致 `diff` + `Use when:` の grep | `PASS: 20 FAIL: 0`、`OK: skill 名一致`、`OK: Use when: あり` | PASS |
| 10 | 変異 1（governance の短絡を外す）→ フルスイート → 復元 → フルスイート | 変異中 `PASS: 4 FAIL: 3`（`test_criteria_sync.sh` / `test_decide.sh` / `test_governance.sh`）、復元後 `PASS: 7 FAIL: 0` | PASS |
| 11 | `time decide.sh ...` | `real 0m0.006s`（1 秒未満） | PASS |

### この実施で直した quickstart の記述

| 箇所 | 直す前 | 直したあと | 理由（実測） |
|---|---|---|---|
| 検証 9 | `jq -S` でマニフェストを比較 | `jq` を必要としない `tests/test_manifest.sh` で同じ内容を確認 | 前提条件に「追加依存なし」を掲げているが `jq` は環境に無く、検証が実行できなかった（`jq: 未インストール`）。M-1 / M-2 が name / version / source の一致を固定している |
| 検証 10 | `s.replace("governance", "govX", 1)`（最初の出現を置換） | governance=yes の短絡（`exit 0`）を除去 | 最初の `governance` は 4 行目のコメントにあり、置換しても挙動が変わらず **`PASS: 7 FAIL: 0` のまま**で探針が空虚だった。挙動を変える行に当て替えて `FAIL: 3` を観測した |
