# 角色与资源

公开构建包含声音和GPT矢量标识，不包含角色动画。可以在工作台设置中导入有权使用的PNG/JPEG，或选择兼容的本地动画素材目录。

## 本地打包

角色资源放在被Git忽略的 `Resources/Local/`，只有明确启用时才进入app：

```sh
BAILONG_INCLUDE_LOCAL_ASSETS=1 zsh scripts/build-app.sh
```

可选文件名：`BAILONG_GPT_TOPBAR_V2_SIMPLE.png`、`bailong-bowl.png`、`bailong-bowl.gif`。缺失时菜单栏用系统符号，抱盆动作不可用。此开关只是本地构建选项，不授予素材分发许可。公开发布使用默认不含本地素材的构建。

动画目录通过用户导入，不会被构建脚本打进应用。目录必须包含 `quality-v1/idle.webp` 和 `素材清单.json`。程序按 idle、additionalIdleAnimations、variants、dragAnimation、landingAnimation、quotaAnimation、workAnimations 顺序读取记录，记录使用 `id`、`name`、`playbackFile`、`durationMs`；路径必须为目录内相对路径。

示意结构（请自行提供图片文件）：

```json
{
  "idle": {"id": "idle", "name": "待机", "playbackFile": "quality-v1/idle.webp", "durationMs": 4000},
  "workAnimations": [{"id": "work02", "name": "处理任务", "playbackFile": "quality-v1/work02.webp", "durationMs": 4000}]
}
```

现有动作ID语义来自原本机素材编排，任意新角色不保证动作段长、持续帧或方位兼容。不能只重命名文件就承诺达到同样效果。请勿将他人的素材随PR提交。
