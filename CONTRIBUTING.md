# 参与贡献

本项目源码公开，采用非商用许可证。提交修改前请阅读 LICENSE.md；请仅贡献你有权按项目条款提供的代码或素材。

## 提交前

1. 使用 Swift 6 工具链运行 `zsh scripts/check.sh`。
2. 运行 `zsh scripts/build-app.sh`，确认无私有素材也可构建。
3. 修改原生输入时运行 `zsh scripts/check-input.sh`，需要已登录的 macOS 图形会话。
4. 如修改角色解码，使用自己的素材目录运行 `zsh scripts/check-animation.sh /path/to/materials`。
5. 如修改菜单栏角色图标，运行 `zsh scripts/check-status-icon.sh /path/to/icon.png`。无本地图标时跳过此可选检查。

PR说明问题、变化和实际验证结果。不要提交 outputs、work、.codex 数据、真实会话JSONL、个人截图、API密钥或未经许可的素材。报告日志解析错误时使用脱敏或合成的小样本，保留事件结构即可。

涉及隐私或凭据的漏洞请使用仓库启用后的私密漏洞报告渠道；不要在公开Issue中粘贴秘密。当前没有公布维护者私人邮箱。
