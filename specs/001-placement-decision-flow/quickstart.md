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
さらに **SC-006**（同じ入力に対して別のセッション・別のプロジェクトでも同じ判断）を、
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

# plugin.json と marketplace.json の name/version 一致
diff <(jq -S '{name,version}' plugins/placement-decision-flow/plugin.json) \
     <(jq -S '.plugins[] | select(.name=="placement-decision-flow") | {name,version}' \
        .github/plugin/marketplace.json) && echo "OK: マニフェスト一致"

# SKILL.md の name と親ディレクトリ名の一致
diff <(grep -m1 '^name:' plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md | sed 's/^name: *//') \
     <(basename plugins/placement-decision-flow/skills/placement-decision-flow) && echo "OK: skill 名一致"

# description に Use when: トリガーがある
grep -q 'Use when:' plugins/placement-decision-flow/skills/placement-decision-flow/SKILL.md \
  && echo "OK: Use when: あり"
```

**期待される結果**: 3 つとも `OK`。差分が出ればマニフェスト契約（`contracts/skill-frontmatter.md`）
違反。

---

## 検証 10: テストが空虚でないことを変異探針で確かめる（憲章 V）

テストが「実装のコピー」を検証していないことを、**実装を壊して失敗するか**で確かめる。

```bash
cd /home/takumi/github/copilot-plugins-marketplace
S=plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh
cp "$S" /tmp/decide.backup

# 変異 1: ガバナンスの短絡を外す（governance を最初のゲートから降ろす）
python3 - <<'EOF'
p = "plugins/placement-decision-flow/skills/placement-decision-flow/scripts/decide.sh"
s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("governance", "govX", 1))
EOF
bash plugins/placement-decision-flow/tests/run.sh 2>&1 | tail -5

# 復元して必ずフルスイートを再実行する
cp /tmp/decide.backup "$S"
bash plugins/placement-decision-flow/tests/run.sh && echo "OK: 復元後に全 pass"
```

**期待される結果**: 変異させた状態でテストが**失敗する**（`FAIL` が 1 件以上）。
復元後に**全 pass に戻る**。

> **注意**: 復元後のフルスイート再実行までを 1 セットとする。復元して再実行しないと、
> 「変異で落ちた」のか「元から落ちていた」のかを区別できない。

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
