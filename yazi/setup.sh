#!/usr/bin/env bash
# yazi 审片工作流迁移脚本（macOS / Apple Silicon）
# 用法：./setup.sh              — 安装依赖 + 配置 + IINA 偏好 + 防闪屏二进制
#       ./setup.sh --no-patch   — 同上，但跳过防闪屏二进制（保留 brew 原版 yazi）
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
WITH_PATCH=1
[[ "${1:-}" == "--no-patch" ]] && WITH_PATCH=0

echo "==> 1/4 安装依赖（Homebrew）"
command -v brew >/dev/null || { echo "请先安装 Homebrew: https://brew.sh"; exit 1; }
brew list yazi   >/dev/null 2>&1 || brew install yazi
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
brew list mpv    >/dev/null 2>&1 || brew install mpv        # 可选：o 菜单里的终端内播放
[[ -d /Applications/IINA.app ]]  || brew install --cask iina

echo "==> 2/4 部署 yazi 配置与插件"
mkdir -p ~/.config/yazi/plugins
if [[ -f ~/.config/yazi/yazi.toml ]]; then
  bak=~/.config/yazi/yazi.toml.bak.$(date +%Y%m%d%H%M%S)
  cp ~/.config/yazi/yazi.toml "$bak"
  echo "    已备份现有 yazi.toml -> $bak"
fi
cp    "$KIT/config/yazi.toml"     ~/.config/yazi/
cp    "$KIT/config/iina-open.sh"  ~/.config/yazi/
cp    "$KIT/config/iina-tile.js"  ~/.config/yazi/
cp -r "$KIT/config/plugins/video-timeline.yazi" ~/.config/yazi/plugins/
cp -r "$KIT/config/plugins/image-info.yazi"     ~/.config/yazi/plugins/
chmod +x ~/.config/yazi/iina-open.sh ~/.config/yazi/iina-tile.js \
         ~/.config/yazi/plugins/video-timeline.yazi/preview.sh

echo "==> 3/4 IINA 偏好（打开视频时窗口 = 视频 2 倍尺寸）"
defaults write com.colliderli.iina resizeWindowTiming -int 1
defaults write com.colliderli.iina resizeWindowOption -int 4

echo "==> 4/4 防闪屏补丁版 yazi 二进制"
if [[ "$WITH_PATCH" == 1 ]]; then
  if [[ ! -f "$KIT/bin/yazi-26.5.6-arm64-patched" ]]; then
    echo "    本 kit 不含预编译二进制（git 仓库不提交 18MB 文件）。"
    echo "    请运行: bash build-patched-yazi.sh 从源码编译安装（一次性，约 10 分钟）"
  elif [[ "$(uname -m)" != "arm64" ]]; then
    echo "    ⚠️ 本机不是 Apple Silicon，预编译二进制不适用；请改用 build-patched-yazi.sh 从源码编译"
  elif [[ "$(yazi --version 2>/dev/null | awk '{print $2}')" != "26.5.6" ]]; then
    echo "    ⚠️ brew 安装的 yazi 版本不是 26.5.6，二进制补丁可能不匹配；"
    echo "       建议用 build-patched-yazi.sh 基于对应版本源码重打补丁（补丁文件在 kit 里）"
  else
    rm -f /opt/homebrew/bin/yazi
    cp "$KIT/bin/yazi-26.5.6-arm64-patched" /opt/homebrew/bin/yazi
    xattr -d com.apple.quarantine /opt/homebrew/bin/yazi 2>/dev/null || true
    brew pin yazi
    echo "    已安装补丁版并 brew pin（防止升级覆盖）"
  fi
else
  echo "    已跳过（--no-patch）。轮播换帧会有闪屏，其余功能不受影响。"
fi

echo ""
echo "✅ 完成。提示："
echo "  - 首次在 yazi 里多选视频回车（触发窗口平铺）时，macOS 会请求"
echo "    自动化/辅助功能权限，给你的终端 App 授权一次即可。"
echo "  - 回滚 yazi 原版：ln -sf ../Cellar/yazi/26.5.6/bin/yazi /opt/homebrew/bin/yazi && brew unpin yazi"
