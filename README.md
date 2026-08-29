# copilot-plugins-marketplace
個人用の Agent Plugins マーケットプレイス。複数リポで使う共通スキルをプラグインごとに管理・配布します。

## なぜプラグイン化するのか

スキルやエージェントが各プロジェクトに散在すると「どこにあったか分からない」「コピーが面倒」になります。
このリポジトリは、**Git で管理した共有元**として機能します。各プロジェクトはコピーではなく、
マーケットプレイス経由で参照するだけです。更新はここで行い、各プロジェクトは追従するだけです。

## 含まれるプラグイン

| プラグイン | 内容 |
|---|---|
| `conventional-commit` | Conventional Commits 1.0.0 に準拠したコミットを作成するスキル |

## 導入方法（VS Code Copilot）

1. このリポジトリをリモートにプッシュします（`github/copilot-plugins` や `github/awesome-copilot` に加えて、
   `github/DMARU9/copilot-plugins-marketplace` をマーケットプレイスとして登録）。
2. VS Code の設定（`settings.json`）にて、エージェントプラグインの探索元にこのマーケットプレイスを追加します。
3. 各プロジェクトで、必要なプラグイン（`conventional-commit` など）を有効化します。

これで、各プロジェクトの `.github/skills/` を手作業でコピーする必要がなくなります。

## ディレクトリ構成

```text
copilot-plugins-marketplace/
├── .github-plugin/
│   └── marketplace.json          # マーケットプレイス定義
├── plugins/
│   └── conventional-commit/
│       ├── plugin.json           # プラグイン定義
│       └── skills/
│           └── conventional-commit/
│               ├── SKILL.md
│               └── scripts/
│                   └── commit-helper.sh
└── README.md
```
