#!/bin/zsh
set -uo pipefail

# ── 路径解析 ──────────────────────────────────────────────────────
SCRIPT_DIR="${0:A:h}"
SKILL_SRC="$SCRIPT_DIR/SKILL.md"

# ── OpenClaw 适配 ──────────────────────────────────────────────────
ADAPT_SH="$SCRIPT_DIR/../.shared/adapt-openclaw.sh"
if [[ -f "$ADAPT_SH" ]]; then
  source "$ADAPT_SH"
fi

# ── 颜色定义 ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 参数解析 ──────────────────────────────────────────────────────
CHECK_ONLY=false
UNINSTALL=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --uninstall) UNINSTALL=true ;;
    --force) FORCE=true ;;
    --help|-h)
      echo "用法: ./install.sh [--check] [--uninstall] [--force]"
      echo "  (无参数)   自动检测已安装的智能体，安装 daily-report 技能软连接"
      echo "  --check    只读验证，不做任何修改"
      echo "  --uninstall  移除所有软连接"
      echo "  --force    覆盖旧版本时跳过确认"
      exit 0 ;;
    *) echo "未知参数: $arg"; exit 1 ;;
  esac
done

# ── 智能体注册表 ──────────────────────────────────────────────────
# name detect_type detect_value skill_dir
AGENTS=(
  "claude-code dir $HOME/.claude $HOME/.claude/skills/daily-report"
  "codebuddy   dir $HOME/.codebuddy $HOME/.codebuddy/skills-marketplace/skills/daily-report"
  "workbuddy   dir $HOME/.workbuddy $HOME/.workbuddy/skills/daily-report"
  "gemini      cmd gemini $HOME/.gemini/skills/daily-report"
  "copilot     cmd copilot $HOME/.copilot/skills/daily-report"
  "codex       cmd codex $HOME/.codex/skills/daily-report"
  "openclaw    cmd openclaw $HOME/.openclaw/skills/daily-report"
)

# ── 颜色辅助函数 ──────────────────────────────────────────────────
c() {
  case "$1" in
    OK)   echo -n "${GREEN}[OK]${NC}" ;;
    FAIL) echo -n "${RED}[FAIL]${NC}" ;;
    NEW)  echo -n "${GREEN}[NEW]${NC}" ;;
    SKIP) echo -n "${CYAN}[SKIP]${NC}" ;;
    MISS) echo -n "${RED}[MISS]${NC}" ;;
    *)    echo -n "$1" ;;
  esac
}

# ── 智能体检测 ────────────────────────────────────────────────────
# 返回 0 表示该智能体已安装
agent_installed() {
  case "$1" in
    dir) [[ -d "$2" ]] ;;
    cmd) command -v "$2" &>/dev/null ;;
  esac
}

# ── 卸载分支 ──────────────────────────────────────────────────────
if $UNINSTALL; then
  echo "移除 daily-report 软连接..."
  removed=0
  for entry in "${AGENTS[@]}"; do
    read -r name dtype dval sdir <<< "$entry"
    if [[ "$name" == "openclaw" ]]; then
      detect_openclaw && uninstall_openclaw_skill "daily-report"
      continue
    fi
    agent_installed "$dtype" "$dval" || continue
    target="$sdir/SKILL.md"
    if [[ -L "$target" ]]; then
      rm "$target"
      # 如果技能目录为空，也一并清理
      rmdir "$sdir" 2>/dev/null || true
      echo "  $name: 已移除"
      removed=$((removed + 1))
    else
      echo "  $name: 无需移除（软连接不存在）"
    fi
  done
  if [[ $removed -eq 0 ]]; then
    echo "没有需要移除的软连接。"
  fi
  exit 0
fi

# ── 检查 SKILL.md 是否存在 ─────────────────────────────────────────
if [[ ! -f "$SKILL_SRC" ]]; then
  echo -e "${RED}错误: 找不到 SKILL.md (路径: $SKILL_SRC)${NC}"
  echo "请确保在 daily-report 仓库根目录下运行此脚本。"
  exit 1
fi

# ── 安装 ──────────────────────────────────────────────────────────
echo "=== daily-report 技能安装 ==="
echo "源文件: $SKILL_SRC"
echo ""

# 打印表头
printf "%-14s %-8s %s\n" "智能体" "状态" "备注"
printf "%-14s %-8s %s\n" "------" "------" "------"

installed=0 skipped=0

for entry in "${AGENTS[@]}"; do
  read -r name dtype dval sdir <<< "$entry"

  # 检测智能体是否安装
  if ! agent_installed "$dtype" "$dval"; then
    printf "%-14s " "$name"
    c SKIP
    printf " %s\n" "未安装"
    skipped=$((skipped + 1))
    continue
  fi

  # ── OpenClaw 专用安装路径 ──────────────────────────────────────
  if [[ "$name" == "openclaw" ]] && detect_openclaw; then
    if ! $CHECK_ONLY; then
      adapt_openclaw_skill "$SKILL_SRC" "$HOME/.openclaw/skills/daily-report"
    elif ! verify_openclaw_skill "$HOME/.openclaw/skills/daily-report"; then
      printf "%-14s " "$name"; c FAIL; printf " %s\n" "verification failed"
    fi
    printf "%-14s " "$name"
    if [[ -f "$HOME/.openclaw/skills/daily-report/SKILL.md" ]]; then
      c OK; printf " %s\n" "installed (sed-transformed)"
      installed=$((installed + 1))
    else
      c FAIL; printf " %s\n" "not installed"
    fi
    continue
  fi

  target="$sdir/SKILL.md"
  skill_status=""
  skill_note=""

  # 检查目标路径现有状态
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$SKILL_SRC" ]]; then
    skill_status="OK"
    skill_note="已是最新"
  elif [[ -L "$target" ]]; then
    skill_note="旧软连接 → $(readlink "$target")"
  elif [[ -d "$target" ]]; then
    skill_note="旧版技能目录"
  elif [[ -f "$target" ]]; then
    skill_note="旧版单文件"
  elif [[ -e "$target" ]]; then
    skill_note="未知文件类型"
  fi

  # 安装（除非是 check-only 模式）
  if ! $CHECK_ONLY && [[ "$skill_status" != "OK" ]]; then
    # 如果存在旧版本，需要确认或备份
    if [[ -n "$skill_note" ]]; then
      if ! $FORCE; then
        echo -e "${YELLOW}[警告] $name: $skill_note${NC}"
        echo "        替换为软连接？[y/N] "
        read -r answer
        [[ "$answer" =~ ^[Yy] ]] || { skill_status="SKIP"; skill_note="用户跳过"; }
      fi
      if [[ "$skill_status" != "SKIP" ]]; then
        bak="${sdir}.bak"
        [[ -e "$bak" ]] && rm -rf "$bak"
        mv "$target" "$bak" 2>/dev/null || rm -rf "$target"
        skill_note="旧版本 → 已备份"
      fi
    fi
    if [[ "$skill_status" != "SKIP" ]]; then
      mkdir -p "$sdir"
      ln -sf "$SKILL_SRC" "$target"
      skill_status="NEW"
    fi
  elif $CHECK_ONLY; then
    [[ -z "$skill_status" ]] && skill_status="FAIL"
  fi

  # 最终验证（check 模式或刚安装后都验证一次）
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$SKILL_SRC" ]]; then
    skill_status="OK"
  fi

  # 打印状态行
  printf "%-14s " "$name"
  c "${skill_status:-FAIL}"
  printf " %s\n" "${skill_note:-}"

  if [[ "$skill_status" != "SKIP" ]]; then
    installed=$((installed + 1))
  fi
done

# ── OpenClaw: 如有新 MCP 注册则重启 Gateway ──────────────────────
restart_gateway_if_mcp_changed 2>/dev/null || true

echo ""
echo "安装完成: $installed 个智能体, 跳过 $skipped 个未安装的智能体"
if $CHECK_ONLY; then
  echo "(只读检查模式，未做任何修改)"
fi
