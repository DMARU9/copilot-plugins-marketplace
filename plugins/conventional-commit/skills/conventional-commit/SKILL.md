---
name: conventional-commit
description: 'Conventional Commits 1.0.0 に準拠したコミットを作成します。コミットメッセージの作成、変更内容の確認、コミット実行までを支援します。Use when: committing changes, preparing commit messages, running git commit.'
argument-hint: 'コミットメッセージや指示があれば入力'
---

# Conventional Commit

[Conventional Commits 1.0.0](https://www.conventionalcommits.org/ja/v1.0.0/) に準拠したコミットを作成します。

## コミットメッセージの基本構造

```text
<type>[scope]: <description>

[本文(任意)]

[フッター(任意)]
```

## Type の選び方

| Type       | 用途                       | 例                                   |
| ---------- | -------------------------- | ------------------------------------ |
| `feat`     | 新機能の追加               | `feat: ログイン機能を追加`           |
| `fix`      | バグ修正                   | `fix: ログアウト時のエラーを修正`    |
| `docs`     | ドキュメントの変更のみ     | `docs: READMEのセットアップ手順を更新` |
| `style`    | コードの意味に影響しない変更 | `style: インデントを修正`          |
| `refactor` | リファクタリング           | `refactor: ユーザー取得処理を関数化` |
| `perf`     | パフォーマンス改善         | `perf: データベースクエリを最適化`  |
| `test`     | テストの追加・修正         | `test: ログイン機能のテストを追加`  |
| `build`    | ビルドシステムや依存関係の変更 | `build: TypeScriptのバージョンを更新` |
| `ci`       | CI 設定の変更              | `ci: GitHub Actionsのワークフローを修正` |
| `chore`    | その他の変更               | `chore: 未使用のファイルを削除`     |
| `revert`   | コミットの取り消し         | `revert: "feat: ..." を取り消し`     |

## Scope (任意)

変更の範囲を括弧で指定します。

```text
feat(auth): パスワードリセット機能を追加
fix(api): ユーザー削除のエンドポイントを修正
```

## 破壊的変更

既存の機能に影響する変更は `!` またはフッターで明示します。

```text
feat!: APIのレスポンス形式を変更

BREAKING CHANGE: レスポンスの構造が変わったため、クライアント側の修正が必要
```

## 記述ルール

- **言語**: 日本語で記述する
- **絵文字**: 使用しない
- **句点**: 1行目の末尾に句点（。）を付けない
- **文体**: 簡潔に記述する（「〜を追加」「〜を修正」など）

## 手順

### 1. 変更内容の把握

以下のコマンドで変更内容を確認します。AI が差分を分析し、コミット対象を判断します。

```bash
# 全体の変更状態を確認
git status
# 差分の詳細を確認（必要に応じて）
git diff
# 未追跡ファイルを含める場合
git status -u
```

必要に応じて[ヘルパースクリプト](./scripts/commit-helper.sh)でも確認できます。

```bash
bash plugins/conventional-commit/skills/conventional-commit/scripts/commit-helper.sh
```

### 2. Type と Scope の決定

変更内容に最も適した Type を上表から選択します。Scope は変更範囲が明確な場合に指定します。

### 3. ファイルのステージング

AI が変更内容を分析し、コミットに含めるべきファイルを判断してステージングします。

```bash
git add <ファイル1> <ファイル2> ...
```

### 4. コミットメッセージの作成

以下のフォーマットに従い、コミットメッセージを作成します。

```text
<type>(<scope>): <description>
```

### 5. Issue/PR フッターの自動付与（任意）

ブランチ名に Issue/PR 番号が含まれている場合、フッターに自動で付与します。

**ルール**: ブランチ名から `#数字` または `数字` のパターンを抽出し、以下をフッターに追加します。

```text
<type>: <description>

Issue/PR: #123
```

**ブランチ名のパターン例**:

| ブランチ名 | 抽出される参照 |
|---|---|
| `feature/123-add-login` | `#123` |
| `fix/456-error-handling` | `#456` |
| `feature/ABC-789-update-api` | `ABC-789` |

抽出後、コミットのフッターに追記します。

### 6. コミットの実行

```bash
git commit -m "<type>(<scope>): <description>" -m "Issue/PR: #123"
```

複数行の場合は `-m` を追加します。

```bash
git commit -m "<type>: <description>" -m "<本文>" -m "Issue/PR: #123"
```

### 7. 確認

- `git log -1` でコミット内容を確認します。
- コミットメッセージの形式がルールに従っていることを確認します。

## When to Use

- 変更をコミットするとき
- コミットメッセージの作成方法が分からないとき
- 従来のコミット規約に準拠したきれいなコミット履歴を維持したいとき
