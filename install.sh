#!/usr/bin/env bash
set -euo pipefail

# ── Bootstrap: resolve REPO_DIR before anything else ─────────────────────────
# When piped via `curl | bash`, BASH_SOURCE[0] is unset and bash reads the
# script from stdin. Wrapping all logic in main() ensures bash buffers the
# entire script before execution, so `exec < /dev/tty` (below) cannot
# truncate the script mid-read.

if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _REMOTE=false
else
  REPO_DIR="$(mktemp -d)"
  _REMOTE=true
fi

# ── Colours ───────────────────────────────────────────────────────────────────
GR='\033[0;32m'   # green
CY='\033[0;36m'   # cyan
YL='\033[1;33m'   # yellow
BD='\033[1m'      # bold
DM='\033[2m'      # dim
RS='\033[0m'      # reset

ok()   { echo -e "  ${GR}✔${RS}  $*"; }
info() { echo -e "  ${CY}→${RS}  $*"; }
warn() { echo -e "  ${YL}!${RS}  $*"; }
hr()   { echo -e "  ${DM}──────────────────────────────────────${RS}"; }

# ── Skill helpers ─────────────────────────────────────────────────────────────
skill_files()  { find "$REPO_DIR/skills" -maxdepth 1 -name 'sf-*.md' | sort; }
skill_count()  { skill_files | wc -l | tr -d ' '; }

get_meta() {
  awk -v k="$1" 'BEGIN{f=0} /^---$/{f++; next} f==1 && $0~"^"k":"{sub("^"k":[[:space:]]*",""); print; exit}' "$2"
}
strip_frontmatter() {
  awk 'BEGIN{f=0} /^---$/{f++; next} f>=2{print}' "$1"
}

# ── Key reader ────────────────────────────────────────────────────────────────
# Tab (single byte \x09) is the primary navigation key — no escape sequences,
# no timing issues. Arrow keys are attempted as a best-effort bonus.
_KEY_RESULT=""
_read_key() {
  local k="" char
  IFS= read -rsn1 k 2>/dev/null
  case "$k" in
    $'\t')    _KEY_RESULT='DOWN'  ;;   # Tab → next (cycles)
    ' ')      _KEY_RESULT='SPACE' ;;
    ''|$'\n') _KEY_RESULT='ENTER' ;;
    q|Q)      _KEY_RESULT='QUIT'  ;;
    $'\x1b')
      while IFS= read -rsn1 -t 0.05 char 2>/dev/null; do
        k+="$char"
      done
      case "$k" in
        $'\x1b[A') _KEY_RESULT='UP'   ;;
        $'\x1b[B') _KEY_RESULT='DOWN' ;;
        *)         _KEY_RESULT='ESC'  ;;
      esac ;;
    *) _KEY_RESULT="$k" ;;
  esac
}

# ── Multi-select checkboxes ───────────────────────────────────────────────────
# Usage:  multiselect "Label 1" "Label 2" ...
# Result: _MULTISEL_RESULT array of selected indices
_MULTISEL_RESULT=()
multiselect() {
  local opts=("$@") n=${#@} cur=0 i
  local sel=(); for (( i=0; i<n; i++ )); do sel+=("false"); done

  _ms_draw() {
    printf "\033[%dA" "$n"
    for (( i=0; i<n; i++ )); do
      printf '\033[2K\r'
      local box; [[ "${sel[$i]}" == "true" ]] && box="${GR}✔${RS}" || box=" "
      if (( i == cur )); then
        printf "  ${BD}▶${RS}  [ ${box} ]  ${BD}${opts[$i]}${RS}\n"
      else
        printf "     [ ${box} ]  ${DM}${opts[$i]}${RS}\n"
      fi
    done
  }

  for (( i=0; i<n; i++ )); do printf '\n'; done
  _ms_draw

  tput civis
  while true; do
    _read_key
    case "$_KEY_RESULT" in
      UP)    (( cur = (cur - 1 + n) % n )) || true ;;
      DOWN)  (( cur = (cur + 1)     % n )) || true ;;
      SPACE) [[ "${sel[$cur]}" == "true" ]] && sel[$cur]="false" || sel[$cur]="true" ;;
      ENTER) break ;;
      QUIT)  tput cnorm; echo ""; exit 0 ;;
    esac
    _ms_draw
  done
  tput cnorm

  _MULTISEL_RESULT=()
  for (( i=0; i<n; i++ )); do
    [[ "${sel[$i]}" == "true" ]] && _MULTISEL_RESULT+=("$i")
  done
}

# ── Radio select ──────────────────────────────────────────────────────────────
# Usage:  radioselect "Option 1" "Option 2" ...
# Result: _RADIOSEL_RESULT index of chosen option
_RADIOSEL_RESULT=0
radioselect() {
  local opts=("$@") n=${#@} cur=0 i

  _rs_draw() {
    printf "\033[%dA" "$n"
    for (( i=0; i<n; i++ )); do
      printf '\033[2K\r'
      if (( i == cur )); then
        printf "  ${BD}▶${RS}  ${GR}●${RS}  ${BD}${opts[$i]}${RS}\n"
      else
        printf "     ${DM}○  ${opts[$i]}${RS}\n"
      fi
    done
  }

  for (( i=0; i<n; i++ )); do printf '\n'; done
  _rs_draw

  tput civis
  while true; do
    _read_key
    case "$_KEY_RESULT" in
      UP)    (( cur = (cur - 1 + n) % n )) || true ;;
      DOWN)  (( cur = (cur + 1)     % n )) || true ;;
      ENTER) break ;;
      QUIT)  tput cnorm; echo ""; exit 0 ;;
    esac
    _rs_draw
  done
  tput cnorm

  _RADIOSEL_RESULT=$cur
}

# ── Installers ────────────────────────────────────────────────────────────────
install_claude() {
  local dest="$HOME/.claude/skills/sf-skills"
  info "Claude Code  →  $dest"
  mkdir -p "$dest"
  local f; for f in $(skill_files); do cp "$f" "$dest/$(basename "$f")"; done
  ok "$(skill_count) skills installed.  Restart Claude Code or run /reload."
}

install_cursor() {
  local scope="$1"
  local dest; [[ "$scope" == "global" ]] && dest="$HOME/.cursor/rules" || dest="$(pwd)/.cursor/rules"
  info "Cursor ($scope)  →  $dest"
  mkdir -p "$dest"
  local f name desc body
  for f in $(skill_files); do
    name=$(get_meta name "$f")
    desc=$(get_meta description "$f")
    body=$(strip_frontmatter "$f")
    printf -- '---\ndescription: %s\nglobs: "**/*.cls,**/*.trigger,**/*.flow-meta.xml,**/*.xml"\nalwaysApply: false\n---\n\n%s\n' \
      "$desc" "$body" > "$dest/${name}.mdc"
  done
  ok "$(skill_count) rule files written."
}

install_codex() {
  local scope="$1"
  local outfile
  [[ "$scope" == "global" ]] \
    && { outfile="$HOME/.codex/AGENTS.md"; mkdir -p "$HOME/.codex"; } \
    || outfile="$(pwd)/AGENTS.md"
  info "Codex ($scope)  →  $outfile"
  [[ -f "$outfile" ]] && { cp "$outfile" "${outfile}.bak"; warn "Existing file backed up to ${outfile}.bak"; }
  {
    printf '# Salesforce Best Practice Skills\n\n'
    printf 'Apply the following best practices when working on Salesforce metadata, Apex, Flows, or architecture decisions.\n\n---\n\n'
    local f name desc body
    for f in $(skill_files); do
      name=$(get_meta name "$f"); desc=$(get_meta description "$f"); body=$(strip_frontmatter "$f")
      printf '## %s\n\n> %s\n\n%s\n\n---\n\n' "$name" "$desc" "$body"
    done
  } > "$outfile"
  ok "AGENTS.md written with $(skill_count) skills."
}

# ── Main ──────────────────────────────────────────────────────────────────────
# Defined as a function so bash buffers the entire script before executing.
# This prevents `exec < /dev/tty` (below) from cutting off script reads when
# running via `curl | bash`.
main() {
  if [[ "$_REMOTE" == true ]]; then
    echo "  Downloading sf-skills…"
    curl -fsSL https://github.com/whoisemiliano/sf-skills/archive/refs/heads/master.tar.gz \
      | tar -xz -C "$REPO_DIR" --strip-components=1
    echo "  Done."
    echo ""
  fi

  trap 'tput cnorm 2>/dev/null; stty sane 2>/dev/null || true; [[ "$_REMOTE" == true ]] && rm -rf "$REPO_DIR"' EXIT

  # ── Non-interactive mode (flags) ────────────────────────────────────────────
  if [[ $# -gt 0 ]]; then
    TARGET="" SCOPE="project"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --scope)  SCOPE="$2";  shift 2 ;;
        --help|-h)
          echo "Usage: ./install.sh [--target claude|cursor|codex|all] [--scope project|global]"
          exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
      esac
    done
    echo ""
    [[ "$TARGET" == "claude" || "$TARGET" == "all" ]] && { install_claude; echo ""; }
    [[ "$TARGET" == "cursor" || "$TARGET" == "all" ]] && { install_cursor "$SCOPE"; echo ""; }
    [[ "$TARGET" == "codex"  || "$TARGET" == "all" ]] && { install_codex  "$SCOPE"; echo ""; }
    ok "Done."; exit 0
  fi

  # ── Interactive TUI ─────────────────────────────────────────────────────────
  # Reattach stdin to /dev/tty so interactive prompts work when piped.
  [[ ! -t 0 ]] && exec < /dev/tty

  echo ""
  echo -e "  ${BD}Salesforce Best Practice Skills${RS}  ${DM}— installer${RS}"
  echo -e "  ${DM}$(skill_count) skills · Claude Code · Cursor · Codex${RS}"
  echo ""
  hr
  echo ""
  echo -e "  ${BD}Select tools to install${RS}"
  echo -e "  ${DM}Tab  navigate   SPACE  toggle   ENTER  confirm   q  quit${RS}"
  echo ""

  multiselect "Claude Code" "Cursor" "Codex (OpenAI)"

  if [[ ${#_MULTISEL_RESULT[@]} -eq 0 ]]; then
    echo ""; warn "Nothing selected. Exiting."; exit 0
  fi

  # Show scope picker only if Cursor (1) or Codex (2) was selected
  SCOPE="project"
  needs_scope=false
  for i in "${_MULTISEL_RESULT[@]}"; do (( i == 1 || i == 2 )) && needs_scope=true && break; done

  if [[ "$needs_scope" == true ]]; then
    echo ""
    hr
    echo ""
    echo -e "  ${BD}Install scope${RS}"
    echo -e "  ${DM}Tab  navigate   ENTER  confirm${RS}"
    echo ""
    radioselect \
      "Project — current directory  (.cursor/rules/  ·  AGENTS.md)" \
      "Global  — all projects       (~/.cursor/rules/ ·  ~/.codex/AGENTS.md)"
    (( _RADIOSEL_RESULT == 1 )) && SCOPE="global" || SCOPE="project"
  fi

  echo ""
  hr
  echo ""
  echo -e "  ${BD}Installing…${RS}"
  echo ""

  for i in "${_MULTISEL_RESULT[@]}"; do
    case "$i" in
      0) install_claude ;;
      1) install_cursor "$SCOPE" ;;
      2) install_codex  "$SCOPE" ;;
    esac
    echo ""
  done

  hr
  echo ""
  ok "All done."
  echo ""
}

main "$@"
