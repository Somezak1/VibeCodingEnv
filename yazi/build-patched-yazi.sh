#!/usr/bin/env bash
# 从源码编译防闪屏补丁版 yazi（当预编译二进制不适用时使用：
# 非 arm64 机器，或 brew 的 yazi 版本 != 26.5.6 时先改下面的 TAG）
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
TAG=v26.5.6
SRC=~/.local/src/yazi-${TAG#v}

command -v cargo >/dev/null || brew install rust
[[ -d "$SRC" ]] || git clone --depth 1 --branch "$TAG" https://github.com/sxyazi/yazi "$SRC"

cd "$SRC"
if git apply --check "$KIT/yazi-kgp-noflicker.patch" 2>/dev/null; then
  git apply "$KIT/yazi-kgp-noflicker.patch"
  echo "补丁已应用"
else
  echo "补丁无法干净应用（可能已打过，或该版本代码有变动需要手动适配）"
  grep -q "shown_load() != Some(area)" yazi-adapter/src/drivers/kgp.rs \
    && echo "检测到补丁已存在，继续编译" || exit 1
fi

cargo build --release -p yazi-fm
rm -f /opt/homebrew/bin/yazi
cp target/release/yazi /opt/homebrew/bin/yazi
brew pin yazi
echo "✅ 补丁版已安装：$(yazi --version)"
