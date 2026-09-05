# GitHub Issue Skill

定められたフォーマットに従ってGitHub Issueを作成・登録するスキルです。

## 概要

バリデーションスクリプトによるチェックを通過した Issue のみ登録するため、誤ったフォーマットでの登録を防止します。開発・執筆・改善提案・不具合報告などのタスクを統一された形式で Issue 管理できます。

## Issue フォーマット

YAML フロントマター（`title` / `labels`）+ Markdown 本文の1ファイルで構成します。

```markdown
---
title: "[企画] 簡潔なタイトル"
labels:
  - article
---

## 概要

...

## タスク

- [ ] タスク1
```

### 種別とラベル

| 種別 | 接頭辞 | ラベル | 必須セクション |
|---|---|---|---|
| 企画 | `[企画]` | `article` | 概要・方針・タスク・完了条件 |
| 改善 | `[改善]` | `enhancement` | 概要・現状の課題・改善案・完了条件 |
| バグ | `[バグ]` | `bug` | 概要・再現手順・期待する動作・実際の動作 |
| タスク | `[タスク]` | `task` | 概要・タスク・完了条件 |
| 質問 | `[質問]` | `question` | 概要・質問内容 |

## 使用方法

VS Code の Copilot チャットで以下のように依頼します：

```
「新機能の企画をIssueとして登録してください」
「〇〇の不具合をバグのIssueで登録して」
```

## テンプレート

```
assets/article.md       企画
assets/enhancement.md   改善
assets/bug.md           バグ
assets/task.md          タスク
assets/question.md      質問
```

## バリデーション

```bash
bash plugins/github-issue/skills/github-issue/scripts/validate-issue.sh <issue-file>
```

エラーが0件になるまで修正します。エラーがある状態での登録は拒否されます。

## 登録

```bash
# プレビュー（登録しない）
bash plugins/github-issue/skills/github-issue/scripts/create-issue.sh <issue-file> --dry-run

# 登録
bash plugins/github-issue/skills/github-issue/scripts/create-issue.sh <issue-file>
```

登録前にバリデーションを再実行し、合格した場合のみ `gh issue create` で登録します。`--dry-run` でプレビューしてから登録するのが安全です。

存在しないラベル（`article` など）は登録時に自動で作成されます。

## 前提条件

- GitHub CLI（`gh`）がインストールされ、ログイン済みであること（`gh auth login`）
