# 角色与资源

## 下载素材包

从 [v0.10.4 素材发布页](https://github.com/zxuu0185-eng/gpt-desktop-pet-mac/releases/tag/v0.10.4-assets) 下载 `BailongMac-0.10.4-assets.zip` 并解压。

- `materials/`：25段原有动作及持续动作衔接帧。在工作台设置中选择此目录，目录根部须有`素材清单.json`。
- `Resources/Local/`：26抱空盆PNG/GIF及菜单栏图标。自行构建时复制到源码的同名目录，然后按下方命令打包。
- `docs/upstream/`：原样保留的上游来源及授权说明。
- `ASSET_MANIFEST.json`：包内文件的SHA-256清单。

源码默认构建仍不携带素材；素材包单独下载，避免把大型二进制写入Git历史。

## 本地打包

角色资源放在被Git忽略的 `Resources/Local/`，只有明确启用时才进入app：

```sh
BAILONG_INCLUDE_LOCAL_ASSETS=1 zsh scripts/build-app.sh
```

可选文件名：`BAILONG_GPT_TOPBAR_V2_SIMPLE.png`、`bailong-bowl.png`、`bailong-bowl.gif`。缺失时菜单栏用系统符号，抱盆动作不可用。此开关只是本地构建选项，不授予素材分发许可。素材随Release单独分发，代码许可证不替代角色素材的原授权声明。

动画目录通过用户导入，不会被构建脚本打进应用。目录必须包含 `quality-v1/idle.webp` 和 `素材清单.json`。程序按 idle、additionalIdleAnimations、variants、dragAnimation、landingAnimation、quotaAnimation、workAnimations 顺序读取记录，记录使用 `id`、`name`、`playbackFile`、`durationMs`；路径必须为目录内相对路径。

示意结构（素材包已提供对应文件）：

```json
{
  "idle": {"id": "idle", "name": "待机", "playbackFile": "quality-v1/idle.webp", "durationMs": 4000},
  "workAnimations": [{"id": "work02", "name": "处理任务", "playbackFile": "quality-v1/work02.webp", "durationMs": 4000}]
}
```

现有动作ID语义来自原本机素材编排，任意新角色不保证动作段长、持续帧或方位兼容。不能只重命名文件就承诺达到同样效果。请勿将大型角色素材或私人文件随PR提交。上游来源与许可边界见 [第三方声明](../THIRD_PARTY_NOTICES.md)。
