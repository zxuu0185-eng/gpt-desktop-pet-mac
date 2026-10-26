# gpt桌宠 mac端

一个用 Swift、AppKit 和 SwiftUI 编写的 macOS 桌面伴侣与本地 Codex 用量面板。

**源码公开，仅限非商业用途。** 本项目采用 [PolyForm Noncommercial 1.0.0](LICENSE.md)，不是 OSI 定义的开源软件。第三方资源保留各自许可证。项目独立开发，与 OpenAI 无官方隶属关系。

## 可以做什么

- 读取本机 Codex 会话日志，显示最近活动、Token 统计及上下文余量估算。
- 通过本机 `codex app-server` 获取 5 小时、周额度和重置倒计时；账户支持时提供手动使用 reset 的入口。
- 完成事件去重与未读提醒；菜单栏数字一键全部已读。
- 可拖拽的桌宠、单击切换动作、双击数据气泡、定时自言自语。
- 自定义名称、声音、台词、显示时长与动画分配。
- 角色与气泡配置为跨 Spaces 显示；不同全屏应用和多显示器组合尚未完整验收。

**角色素材单独通过 [GitHub Release](https://github.com/zxuu0185-eng/gpt-desktop-pet-mac/releases/tag/v0.10.4-assets) 分发。** 素材包包含01–25动作、持续动作衔接帧、26抱空盆静态图及动图、专用菜单栏图标，不放入Git历史。下载与导入见 [角色资源说明](docs/ASSETS.md)。未导入时显示内置占位界面。素材保留上游授权声明，不适用本项目代码许可证。

## 环境与构建

macOS 14+，Swift 6 工具链（采用 Swift 5 语言模式），Apple Command Line Tools 或 Xcode。已在 Apple Silicon 上验证；Intel 尚未实测。无第三方 Swift 包依赖。

```sh
zsh scripts/check.sh
zsh scripts/build-app.sh
open outputs/白龙.app
```

生成 `outputs/白龙.app` 和 `outputs/白龙-Mac.zip`。构建使用临时签名，未进行 Developer ID 签名或 Apple 公证。

菜单栏图标打开一级菜单：显示、隐藏、全部标为已读、刷新和退出。双击角色进入数据气泡，顶部设置按钮进入陪伴设置；完整工作台中的设置可修改名称和角色可见性。

额度功能需要本机已安装并登录 Codex；找不到命令时在工作台设置中指定可执行文件。未配置或日志缺失时显示不可用状态，不影响程序启动。不会要求填写 API key。

## 数据范围与隐私

应用读取 `CODEX_HOME`（默认 `~/.codex`）内可读的近期日志，并增量索引本机用量。日志输入量不是精确实时上下文；缺少数据时不代表账户没有使用量。额度百分比也不是可直接换算的剩余 Token 数。

应用不调用外部模型、不截图、不上传屏幕或会话。额度连接由本机 Codex app-server 处理，可能沿用 Codex 自身网络与账户行为。**Reset 按钮会消费账户已有的 reset 权益**；只在手动点击时调用，结果不明时保留幂等请求以核验。菜单栏“已读”只修改本应用提醒，不同步 Codex 聊天已读。

更多内容见 [隐私与数据](docs/PRIVACY.md)、[角色资源](docs/ASSETS.md)、[开发说明](docs/DEVELOPMENT.md) 和 [第三方声明](THIRD_PARTY_NOTICES.md)。

## 贡献与许可证

欢迎提交 bug 报告和非商业用途的改进，见 [CONTRIBUTING.md](CONTRIBUTING.md)。请勿上传真实会话日志、账户凭据或无权分发的角色素材。

代码许可为 PolyForm Noncommercial 1.0.0。非商业使用、修改与分发以许可证原文为准；商业使用不在授权范围。第三方 CC0 素材的原许可不因本项目改变。详见 [LICENSE.md](LICENSE.md) 与 [NOTICE.md](NOTICE.md)。
