# yazi 审片工作流迁移包

在新 Mac 上复刻完整的 yazi 视频审片环境：悬停 12fps 连续轮播预览、
图片/视频中文参数信息、回车 IINA 双倍窗口播放、多选自动平铺居中。

## 给 Claude Code 的操作指引（傻瓜式安装）

在新 Mac 上按顺序执行，无需询问用户额外决策：

```bash
bash setup.sh                 # 依赖 + 配置 + IINA 偏好，缺失项自动安装
bash build-patched-yazi.sh    # 编译补丁版 yazi（源码编译，一次性约 10 分钟）
```

验证：重开终端进入 yazi，悬停一个视频 —— 预览栏应自动轮播，
下方显示中文标签的参数信息；回车应弹出 IINA 大窗口播放。

前置条件检查（不满足时提醒用户）：
- 已安装 Homebrew；
- 终端为 Ghostty / kitty / WezTerm（需 kitty 图形协议，iTerm2 不支持本仓库的 yazi 补丁）；
- 首次在 yazi 中多选视频回车（触发窗口平铺）时，macOS 会弹
  "自动化/辅助功能"授权框，需用户手动允许一次。

## 这套功能由三层组成

| 层 | 内容 | 迁移方式 |
|---|---|---|
| 配置/插件 | `config/` 里的 yazi.toml、video-timeline / image-info 插件、IINA 打开与平铺脚本 | setup.sh 直接拷贝到 `~/.config/yazi/` |
| IINA 偏好 | 打开视频时窗口 = 视频 2 倍尺寸 | setup.sh 写入 defaults |
| 源码补丁 | 同区域换帧跳过擦除步骤（`yazi-kgp-noflicker.patch`，6 行） | `build-patched-yazi.sh` 从源码编译（git 仓库不含预编译二进制） |

## 依赖

Homebrew 包：`yazi` `ffmpeg` `mpv`（可选）+ cask `iina`；编译补丁需 `rust`。
均由脚本自动安装缺失项。

## 注意事项

- 补丁版二进制会 `brew pin yazi`；日后升级 yazi：`brew unpin yazi && brew upgrade yazi`，
  然后改 `build-patched-yazi.sh` 里的 TAG 为新版本重新编译（若补丁位置代码有变需手动适配）。
- 回滚原版 yazi：`ln -sf ../Cellar/yazi/<版本>/bin/yazi /opt/homebrew/bin/yazi && brew unpin yazi`

## 参数调整速查

| 想调什么 | 改哪里 |
|---|---|
| 轮播帧率 | `config/plugins/video-timeline.yazi/preview.sh` 的 `PREVIEW_FPS`（抽帧密度）+ `main.lua` 的 `TICK_SECONDS`（播放节奏） |
| 长视频阈值/帧数 | preview.sh 的 `LONG_VIDEO_SECS` / `SPARSE_N` / `MAXFRAMES` |
| 缩略图清晰度 | preview.sh 的 `OUT_W` / `OUT_H`（改后清缓存：`rm -rf "$TMPDIR/yazi-video-timeline"`） |
| IINA 窗口倍数 | `defaults write com.colliderli.iina resizeWindowOption -int N`（1=0.5x 2=1x 3=1.5x 4=2x 0=适配屏幕） |
