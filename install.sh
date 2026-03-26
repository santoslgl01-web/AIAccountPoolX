#!/usr/bin/env bash
# AIAccountPoolX 一键安装脚本
# 用法：bash install.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 工具函数 ───────────────────────────────────────────────────────────────

check_command() {
  command -v "$1" >/dev/null 2>&1
}

version_ge() {
  # 比较版本号：$1 >= $2（仅比较主版本）
  local actual major_actual major_required
  actual="$1"
  major_actual="${actual%%.*}"
  major_required="${2%%.*}"
  [ "${major_actual}" -ge "${major_required}" ]
}

# ── 依赖检查 ───────────────────────────────────────────────────────────────

info "检查运行环境..."

# Node.js >= 18
if ! check_command node; then
  error "未找到 Node.js，请先安装 Node.js 18+：https://nodejs.org/"
  exit 1
fi
NODE_VER=$(node -v | sed 's/v//')
if ! version_ge "$NODE_VER" "18"; then
  error "Node.js 版本过低（当前 v${NODE_VER}），需要 18+。"
  exit 1
fi
info "Node.js v${NODE_VER} ✓"

# pnpm >= 8
if ! check_command pnpm; then
  warn "未找到 pnpm，尝试使用 npm 安装..."
  npm install -g pnpm@latest
fi
PNPM_VER=$(pnpm -v)
if ! version_ge "$PNPM_VER" "8"; then
  error "pnpm 版本过低（当前 ${PNPM_VER}），需要 8+。请执行：npm install -g pnpm@latest"
  exit 1
fi
info "pnpm v${PNPM_VER} ✓"

# Python >= 3.10
PYTHON_BIN=""
for bin in python3.12 python3.11 python3.10 python3 python; do
  if check_command "$bin"; then
    PY_VER=$("$bin" -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>/dev/null || true)
    if [ -n "$PY_VER" ] && version_ge "${PY_VER%%.*}" "3"; then
      MINOR="${PY_VER#*.}"
      MINOR="${MINOR%%.*}"
      if [ "${PY_VER%%.*}" -ge 3 ] && [ "$MINOR" -ge 10 ]; then
        PYTHON_BIN="$bin"
        break
      fi
    fi
  fi
done

if [ -z "$PYTHON_BIN" ]; then
  error "未找到 Python 3.10+，请先安装：https://www.python.org/downloads/"
  exit 1
fi
info "Python $($PYTHON_BIN --version 2>&1 | awk '{print $2}') [$PYTHON_BIN] ✓"

# ── 安装依赖 ───────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

info "安装前端依赖（pnpm install）..."
pnpm install

info "安装后端依赖（pip install -r requirements.txt）..."
BACKEND_DIR="$REPO_ROOT/packages/backend"

# 优先使用虚拟环境
if [ ! -d "$BACKEND_DIR/.venv" ]; then
  info "创建 Python 虚拟环境 packages/backend/.venv ..."
  "$PYTHON_BIN" -m venv "$BACKEND_DIR/.venv"
fi

VENV_PIP="$BACKEND_DIR/.venv/bin/pip"
"$VENV_PIP" install --upgrade pip -q
"$VENV_PIP" install -r "$BACKEND_DIR/requirements.txt"
info "后端依赖安装完成 ✓"

# ── 配置文件 ───────────────────────────────────────────────────────────────

CONFIG_FILE="$BACKEND_DIR/config.json"
CONFIG_EXAMPLE="$BACKEND_DIR/config.example.json"

if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$CONFIG_EXAMPLE" ]; then
    cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    info "已复制 config.example.json → config.json，请按需填写配置。"
  else
    warn "未找到 config.example.json，跳过配置文件初始化。"
  fi
else
  info "config.json 已存在，跳过复制。"
fi

# ── 完成提示 ───────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}=============================="
echo -e "  AIAccountPoolX 安装完成！"
echo -e "==============================${NC}"
echo ""
echo "  后端虚拟环境：packages/backend/.venv"
echo "  启动开发环境：pnpm dev"
echo "  前端地址：    http://localhost:3000"
echo "  后端地址：    http://localhost:1455"
echo ""
warn "首次使用前请编辑 packages/backend/config.json 填写邮箱、代理等配置，"
warn "或启动后在 Web UI 的"系统配置"中保存。"
echo ""
