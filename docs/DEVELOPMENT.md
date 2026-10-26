# 开发与验证

- Sources/BailongCore：JSONL解析、统计、完成去重、额度RPC、动作选择与布局计算。
- Sources/BailongMac：AppKit窗口、菜单栏、SwiftUI面板、WebP动画与系统交互。
- Tests/BailongCoreTests：独立CoreChecks程序，使用合成数据，无需真实账户。
- Tests/InputChecks、AnimationChecks、StatusBarIconChecks：原生输入与素材的专项检查。
- Resources/Public：可随源码分发的资源；Resources/Local：忽略的本地角色图稿。

```sh
zsh scripts/check.sh
zsh scripts/build-app.sh
zsh scripts/check-input.sh
zsh scripts/check-status-icon.sh
```

构建缓存只写入work。原生AppKit专项检查需要macOS图形会话，受限沙盒可能阻止访问WindowServer。CI只运行核心检查与公开构建，不消费真实reset，也不依赖角色素材。GitHub CI配置需要仓库发布后才能实际运行。

`python3 scripts/export-source.py` 用允许清单导出公开源码与ZIP，不包含.git历史、账户信息、内部设计说明、参考仓库或Resources/Local。请发布导出的源码，而非直接拖整个开发目录。

已知限制：只实测Apple Silicon；上下文为估算；非公证app；私有动作素材不分发；不同全屏应用及多屏布局组合仍待完整验证。Codex日志与app-server接口变化可能影响兼容性。
