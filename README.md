<div align="center">

# 🛠️ VibeCodingEnv

**一份可复刻的 macOS 终端开发环境**

克隆本仓库 → 交给 Claude Code 按本文执行 → 新 Mac 上十几分钟复刻整套环境

</div>

---

## 这个仓库是什么？

我在主力 Mac 上打磨了一套顺手的终端工作环境（终端模拟器、命令行提示符、文件管理器和若干现代 CLI 工具）。这个仓库把**所有配置文件、插件、源码补丁和安装步骤**固化下来——换新电脑或重装系统时，不用再凭记忆逐个装工具、翻聊天记录找配置，把仓库交给 Claude Code（或自己照着做）即可原样重建。

三条设计原则：

1. **仓库即唯一事实来源** —— 所有配置以仓库内副本为准。引用过的外部 gist 已经完整复制入库（防止原链接哪天失效），出处在各节注明；
2. **不含任何密钥** —— API key / token 一律不入库；
3. **每一步可验证** —— 每节末尾都写明"装完应该是什么样"。

## 工具总览

| 工具 | 是什么 | 为什么用它 |
|---|---|---|
| [Ghostty](https://ghostty.org) | GPU 加速的终端模拟器 | 快、原生 macOS 手感；支持 kitty 图形协议（yazi 在终端里显示图片/视频预览的前提） |
| [starship](https://starship.rs) | 跨 shell 的命令行提示符 | Catppuccin 主题的分段彩色提示符，自动显示当前目录、git 分支、语言版本、命令耗时 |
| [yazi](https://github.com/sxyazi/yazi) | 终端文件管理器 | 本仓库的重头戏：被深度定制成了「视频审片工作台」，见下一节 |
| [bat](https://github.com/sharkdp/bat) | `cat` 替代品 | 看文件自带语法高亮和行号 |
| [lazygit](https://github.com/jesseduffield/lazygit) | git 终端 UI | 可视化地暂存/提交/切分支，比裸敲 git 命令快得多 |
| [lsd](https://github.com/lsd-rs/lsd) | `ls` 替代品 | 图标 + 彩色输出，配合 `ll` 别名 |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` 替代品 | 记住你常去的目录，`z 关键词` 直接跳转 |

## yazi「审片工作台」是什么？

**背景**：我用 AI 工具批量生成短视频素材（9:16 竖屏短片），需要频繁地从几十个草稿里快速挑出可用镜头。默认的工作方式——逐个双击打开播放器看——太慢；yazi 默认的视频预览又只是一张静态缩略图，看不出运镜和瑕疵。

这套定制把「浏览 → 预判 → 细看 → 对比」压缩成四个动作：

| 动作 | 效果 |
|---|---|
| **光标悬停**在视频上 | 右侧预览栏以约 12fps 自动轮播**整条视频的连续画面**（近似低帧率播放，不是幻灯片跳切），且换帧无闪屏；画面下方显示中文标签的参数：分辨率（含宽高比）、时长、帧率、编码、码率、体积、音频 |
| **光标悬停**在图片上 | 显示图片 + 分辨率（含宽高比）、格式、体积 |
| **回车** | 调用 IINA（macOS 原生播放器）弹出 **2 倍尺寸窗口**精细回放，可逐帧查看 |
| **空格多选 + 回车** | 多个 IINA 窗口自动**横向平铺、整组居中**（选 2 个时接缝正好压在屏幕中线上），并排对比不同版本一目了然 |

> 即使你不做视频，这套配置也值得装：图片/视频的预览体验远好于 yazi 默认状态。

三层实现（详见 [`yazi/README.md`](yazi/README.md)）：

- **配置与插件**：魔改版 `video-timeline` 插件（单次 ffmpeg 解码抽帧条、竖屏不裁剪、自适应片长）+ 自写 `image-info` 插件 + IINA 打开/平铺脚本；
- **IINA 偏好**：打开视频时窗口自动调整为视频 2 倍尺寸；
- **源码补丁**：6 行 yazi 补丁消除轮播换帧闪屏（同区域换帧跳过"先擦除再重绘"），需从源码编译一次。

---

## 重建步骤

> **给 Claude Code 的总指引**：按第 0-7 节顺序执行，无需询问额外决策。
> 所有配置一律以本仓库内的副本为准，用 `cp` 部署，不要从网络重新下载。

### 0. 前置

```bash
# Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Nerd 字体（Ghostty 配置指定的字体，也是 starship 图标不乱码的前提）
brew install --cask font-maple-mono-nf-cn
```

### 1. Ghostty

```bash
brew install --cask ghostty
mkdir -p ~/.config/ghostty
cp ghostty/config ~/.config/ghostty/config
```

配置出处：基于 [zhangchitc 的 gist](https://gist.github.com/zhangchitc/7dead7c1b517390e061e07759ed80277)，本仓库版本额外包含三处本机踩坑后的修正——

- 禁用 `font-thicken` / `adjust-cell-height`（会让 Claude Code 的 Ink 渲染器行高计算失准，长输出文字重叠）；
- `minimum-contrast = 4.5`（半透明深色背景下，TUI 的暗淡文字对比度常常只有 2-3:1，看不清；此项让 Ghostty 自动提亮到 WCAG AA 标准）；
- `cmd+k` 清屏 / `cmd+shift+k` 硬重置终端（Claude Code 渲染花屏时的救急键，`Ctrl+L` 救不了）。

**验证**：新开 Ghostty 窗口应为半透明毛玻璃 + Catppuccin Mocha 配色 + Maple Mono 字体。

### 2. starship

```bash
brew install starship
cp starship/starship.toml ~/.config/starship.toml
```

配置出处：[zhangchitc 的 gist](https://gist.github.com/zhangchitc/62f5dca64c599084f936fda9963f1100)。文件里有大量 Nerd Font 专用字符，**务必 `cp` 部署，不要手抄或让 AI 转写**（本仓库就曾因转写导致字形损坏，后改为原始字节上传）。

需在 `~/.zshrc` 追加初始化行（见第 7 节）。

**验证**：重开终端后提示符为彩色分段胶囊样式（红色 OS 段 → 橙色路径段 → 黄色 git 段），图标无 `?` 或方框乱码。

### 3. yazi（含审片工作台）

```bash
cd yazi
bash setup.sh                 # 安装依赖（yazi/ffmpeg/mpv/IINA）+ 部署配置插件 + 写 IINA 偏好
bash build-patched-yazi.sh    # 编译防闪屏补丁版 yazi 并安装（一次性，约 10 分钟）
cd ..
```

需在 `~/.zshrc` 追加 `y` 唤起函数（见第 7 节）。

**验证**：进入 yazi 悬停一个视频——预览栏应自动轮播且换帧无闪屏，画面下方有中文参数；回车弹出 IINA 大窗口；空格选中两个视频再回车，两个窗口并排铺在屏幕中央。

⚠️ 两个预期内的现象：
- 首次多选回车时 macOS 会弹「"Ghostty" 想要控制 "System Events"」的授权框——窗口平铺脚本需要此权限，点一次"允许"即可；
- 终端必须支持 kitty 图形协议（Ghostty / kitty / WezTerm）。iTerm2 走不同的图片协议，防闪屏补丁对它无效。

### 4. bat

```bash
brew install bat
mkdir -p "$(bat --config-dir)"
cp bat/config "$(bat --config-file)"
```

**验证**：`bat` 任意代码文件，应有 Monokai Extended 高亮和行号。

### 5. lazygit

```bash
brew install lazygit
```

当前使用默认配置即可用。如需自定义，路径为 `~/Library/Application Support/lazygit/config.yml`（仓库 `lazygit/config.yml` 是带注释的占位模板）。

**验证**：任意 git 仓库内运行 `lazygit` 能打开 TUI。

### 6. lsd

```bash
brew install lsd
```

配置就是 `ll` 别名（见第 7 节）。

**验证**：`ll` 输出带文件类型图标和彩色列。

### 7. ~/.zshrc 汇总

以下内容追加到 `~/.zshrc`（各片段在对应工具文件夹里也有独立副本）：

```sh
# zoxide（目录跳转）
eval "$(zoxide init zsh)"        # 需先 brew install zoxide

# starship 提示符
eval "$(starship init zsh)"

# yazi：y 唤起，退出时自动 cd 到 yazi 中所在目录
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# lsd
alias ll="lsd -hl"

# Ghostty 1.3.x 下 Claude Code 渲染损坏的变通（详见 ghostty/claude-term-fix.zsh 注释）
claude() {
  if [[ "$TERM" == xterm-ghostty ]]; then
    TERM=xterm-256color command claude "$@"
  else
    command claude "$@"
  fi
}
alias clauded="claude --dangerously-skip-permissions"
```

---

## 常见问题

**Q：为什么 yazi 要 `brew pin`？**
防闪屏功能是打在 yazi 源码上的补丁、本地编译的二进制。`brew pin` 防止日后 `brew upgrade` 把它静默换回官方版（表现为轮播重新开始闪屏）。升级方法见 `yazi/README.md`。

**Q：悬停视频时第一秒是静止画面？**
正常。首次悬停会在后台把整条视频抽成帧条（几秒内完成），期间先显示首帧，抽完自动开始轮播；同一视频第二次悬停即秒开。

**Q：视频轮播为什么是 12fps 而不是更流畅？**
终端渲染视频的架构限制：每一帧都要经过「子进程抽帧 → 终端图形协议传输」，12fps 已接近该路径的实用上限。精细观看走回车 IINA。

**Q：这套配置在 Intel Mac 上能用吗？**
配置和插件都能用。仅 yazi 补丁需在本机重新编译（`build-patched-yazi.sh` 自动处理，不区分架构）。

## 维护约定

- 在任何一台机器上改了配置，同步改回本仓库对应文件并推送，保持"仓库即事实来源"；
- yazi 插件参数怎么调（帧率、清晰度、窗口倍数等），见 `yazi/README.md` 的速查表。
