# VibeCodingEnv

我的 macOS vibe coding 终端环境重建仓库。在任何新 Mac 上克隆本仓库，
让 Claude Code 按本 README 从上到下执行，即可复刻整套工具链：

**Ghostty**（终端）· **starship**（提示符）· **yazi**（文件管理 + 审片工作流）·
**bat**（cat 替代）· **lazygit**（git TUI）· **lsd**（ls 替代）

> **给 Claude Code 的总指引**：按第 0-7 节顺序执行，无需询问额外决策。
> 所有配置一律以本仓库内的副本为准（外部 gist 已收编入库，出处见各节注释），
> 用 `cp` 部署，不要从网络重新下载。第 8 节的密钥需要用户手动提供，不在仓库中。

## 0. 前置

```bash
# Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Nerd 字体（Ghostty 配置和 starship 图标依赖）
brew install --cask font-maple-mono-nf-cn
```

## 1. Ghostty（终端模拟器）

```bash
brew install --cask ghostty
mkdir -p ~/.config/ghostty
cp ghostty/config ~/.config/ghostty/config
```

配置出处：基于 [zhangchitc 的 gist](https://gist.github.com/zhangchitc/7dead7c1b517390e061e07759ed80277)，
本仓库版本额外包含：Claude Code Ink 渲染修复（禁用 font-thicken/adjust-cell-height 并注明原因）、
`minimum-contrast = 4.5`（修复暗色主题下暗淡文字看不清）、`cmd+k / cmd+shift+k` 清屏与硬重置快捷键。

**zsh 片段**：`ghostty/claude-term-fix.zsh` 是 Ghostty 1.3.x 下 Claude Code 渲染损坏的
TERM 变通函数，追加进 `~/.zshrc`（见第 7 节）。

## 2. starship（提示符）

```bash
brew install starship
cp starship/starship.toml ~/.config/starship.toml
```

配置出处：[zhangchitc 的 gist](https://gist.github.com/zhangchitc/62f5dca64c599084f936fda9963f1100)
（Catppuccin 主题，含 Nerd Font 特殊字符——务必 `cp` 部署，不要手抄）。
`~/.zshrc` 需要 `eval "$(starship init zsh)"`（见第 7 节）。

## 3. yazi（文件管理器 + 视频审片工作流）

完整安装说明见 [`yazi/README.md`](yazi/README.md)。快速路径：

```bash
cd yazi
bash setup.sh                 # 依赖(含 IINA/mpv/ffmpeg) + 配置插件 + IINA 偏好
bash build-patched-yazi.sh    # 防闪屏补丁版 yazi（源码编译，一次性约 10 分钟）
cd ..
```

功能：悬停视频 12fps 无闪屏轮播预览、图片/视频中文参数信息、回车 IINA 双倍窗口播放、
多选回车自动平铺窗口。`~/.zshrc` 需要 `y` 唤起函数（见第 7 节）。

## 4. bat（cat 替代）

```bash
brew install bat
mkdir -p "$(bat --config-dir)"
cp bat/config "$(bat --config-file)"
```

## 5. lazygit（git TUI）

```bash
brew install lazygit
```

当前使用默认配置。如需自定义，配置路径为
`~/Library/Application Support/lazygit/config.yml`（仓库 `lazygit/config.yml` 为占位模板）。

## 6. lsd（ls 替代）

```bash
brew install lsd
```

配置即 `alias ll="lsd -hl"`（见第 7 节）。

## 7. ~/.zshrc 汇总

把以下内容追加到 `~/.zshrc`（各片段的独立副本在对应工具文件夹中）：

```sh
# zoxide（目录跳转，配套工具）
eval "$(zoxide init zsh)"        # 需先 brew install zoxide

# starship 提示符
eval "$(starship init zsh)"

# yazi：y 唤起并在退出时 cd 到所在目录
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# lsd
alias ll="lsd -hl"

# Ghostty 1.3.x + Claude Code 渲染修复（详见 ghostty/claude-term-fix.zsh 注释）
claude() {
  if [[ "$TERM" == xterm-ghostty ]]; then
    TERM=xterm-256color command claude "$@"
  else
    command claude "$@"
  fi
}
alias clauded="claude --dangerously-skip-permissions"
```

## 8. 密钥与私有环境变量（不入库，需手动迁移）

以下环境变量在旧机器的 `~/.zshrc` 中，**值不进 git 仓库**，需要用户从
旧机器或密码管理器手动搬运：

```
ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN / CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
TAVILY_API_KEY / FIRECRAWL_API_KEY / JINA_API_KEY
PIXVERSE_API_KEY
GITHUB_PERSONAL_ACCESS_TOKEN
```

## 验证清单

- [ ] 新开 Ghostty：半透明毛玻璃窗口、Maple Mono 字体、starship 彩色分段提示符无乱码
- [ ] `y` 进入 yazi：悬停视频自动轮播无闪屏，下方中文参数；`q` 退出后 cd 到所在目录
- [ ] yazi 中多选视频回车：IINA 窗口平铺居中（首次需授权"自动化/辅助功能"）
- [ ] `ll`、`bat <文件>`、`lazygit` 正常
