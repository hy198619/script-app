# 参与贡献

感谢你愿意帮助改进草稿本。

## 提交问题

请先搜索现有 Issues，避免重复。Bug 请附上系统版本、App 版本和最小复现步骤，但不要附带私人草稿或账号信息。

## 本地开发

需要 Xcode 16.2 或兼容的更新版本。

```bash
swift test
./scripts/build-app.sh
```

构建产物位于 `dist/草稿本.app`。

## Pull Request

- 一个 PR 尽量只解决一个问题；
- 对状态和数据行为的变更请补充单元测试；
- 不要提交 `.build/`、`dist/` 或用户数据；
- 提交贡献即表示你同意贡献内容按照本项目的 PolyForm Perimeter License 1.0.1 提供。
