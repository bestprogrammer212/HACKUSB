#!/usr/bin/env zsh
# ╔══════════════════════════════════════════════════════════════════╗
# ║   HACK USB — Install Tools on PC                               ║
# ║   Installs all pentest tools directly on your machine          ║
# ║                                                                 ║
# ║   macOS:   zsh install_on_pc.zsh   (no sudo)                  ║
# ║   Linux:   sudo zsh install_on_pc.zsh                          ║
# ║                                                                 ║
# ║   ⚠  USE ON YOUR OWN / AUTHORIZED SYSTEMS ONLY!               ║
# ╚══════════════════════════════════════════════════════════════════╝

BOLD='\033[1m'; RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; DIM='\033[2m'
MAGENTA='\033[0;35m'; NC='\033[0m'
LOG="/tmp/hackusb_pc_install.log"

ok()    { echo -e "${GREEN}  ✓${NC}  $1" | tee -a "$LOG"; }
info()  { echo -e "${CYAN}  →${NC}  $1" | tee -a "$LOG"; }
warn()  { echo -e "${YELLOW}  !${NC}  $1" | tee -a "$LOG"; }
err()   { echo -e "${RED}  ✗${NC}  $1" | tee -a "$LOG"; }
step()  { echo -e "\n${MAGENTA}${BOLD}  ▶ $1${NC}\n" | tee -a "$LOG"; }
section(){ echo -e "\n${CYAN}${BOLD}  ══════════════════════════════════\n  $1\n  ══════════════════════════════════${NC}\n"; }
ask()   { print -n "  ${CYAN}?${NC}  $1 " && read REPLY; }

# Detect real user
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  REAL_USER="$SUDO_USER"; REAL_HOME=$(eval echo "~$SUDO_USER")
else
  REAL_USER="${USER:-$(whoami)}"; REAL_HOME="$HOME"
fi
case "$(basename ${SHELL:-zsh})" in
  zsh)  SHELL_RC="$REAL_HOME/.zshrc" ;;
  bash) SHELL_RC="$REAL_HOME/.bashrc" ;;
  *)    SHELL_RC="$REAL_HOME/.profile" ;;
esac
[[ -f "$SHELL_RC" ]] || touch "$SHELL_RC" 2>/dev/null || true

run_as_user() {
  if [[ "$REAL_USER" != "root" ]] && [[ "$(id -u)" -eq 0 ]]; then
    sudo -u "$REAL_USER" env HOME="$REAL_HOME" "$@" 2>/dev/null || eval "$@"
  else
    eval "$@"
  fi
}

clear
echo -e "${RED}${BOLD}"
echo "  ██╗  ██╗ █████╗  ██████╗██╗  ██╗    ██╗   ██╗███████╗██████╗ "
echo "  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝    ██║   ██║██╔════╝██╔══██╗"
echo "  ███████║███████║██║     █████╔╝     ██║   ██║███████╗██████╔╝ "
echo "  ██╔══██║██╔══██║██║     ██╔═██╗     ██║   ██║╚════██║██╔══██╗ "
echo "  ██║  ██║██║  ██║╚██████╗██║  ██╗    ╚██████╔╝███████║██████╔╝ "
echo "  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═════╝  "
echo -e "${NC}"
echo -e "  ${DIM}PC Tool Installer — hackusb${NC}"
echo -e "  ${YELLOW}${BOLD}⚠  USE ON YOUR OWN / AUTHORIZED SYSTEMS ONLY!${NC}"
echo -e "  ${DIM}User: ${CYAN}$REAL_USER${NC}  |  Log: ${CYAN}$LOG${NC}"
echo ""

# OS detection
OS=""
PKG=""
u=$(uname -s 2>/dev/null || echo "Unknown")
case "$u" in
  Darwin*)
    OS="macos"; PKG="brew"
    ok "macOS $(sw_vers -productVersion 2>/dev/null)"
    for p in /opt/homebrew /usr/local; do
      [[ -f "$p/bin/brew" ]] && eval "$($p/bin/brew shellenv)" 2>/dev/null && break
    done
    if ! command -v brew &>/dev/null; then
      warn "Homebrew missing — installing..."
      run_as_user '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >> "$LOG" 2>&1
      for p in /opt/homebrew /usr/local; do
        [[ -f "$p/bin/brew" ]] && eval "$($p/bin/brew shellenv)" 2>/dev/null && break
      done
    fi ;;
  Linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"; else OS="linux"; fi
    command -v apt-get &>/dev/null && PKG="apt" || \
    command -v pacman  &>/dev/null && PKG="pacman" || \
    command -v dnf     &>/dev/null && PKG="dnf" || PKG="unknown"
    ok "${OS} / $PKG" ;;
  MINGW*|MSYS*)
    OS="windows"; PKG="winget"
    command -v winget &>/dev/null || PKG="choco"
    ok "Windows ($PKG)" ;;
esac

section "CHOOSE INSTALL PROFILE"
echo -e "  ${GREEN}[1]${NC}  Quick     — core tools only (nmap, python, go, node, git)"
echo -e "  ${YELLOW}[2]${NC}  Standard  — + pentest suite (hydra, john, sqlmap, metasploit, ...)"
echo -e "  ${RED}[3]${NC}  Full      — everything including wireless, forensics, phishing"
echo ""
ask "Profile [1/2/3, Enter=2]:"
PROFILE="${REPLY:-2}"

section "STEP 1 — SYSTEM PACKAGES"
case "$OS" in
  macos)
    _brew() { run_as_user "brew $*"; }
    _brew update --quiet >> "$LOG" 2>&1 || true
    QUICK_PKGS=(git curl wget jq zsh openssl@3 python3 go node ruby tmux fzf bat ripgrep)
    STD_PKGS=(nmap netcat hydra masscan sqlmap nikto gobuster ffuf hashcat john-jumbo
              binwalk exiftool steghide libpcap aircrack-ng)
    FULL_PKGS=(metasploit hcxtools hcxdumptool wireshark foremost tcpdump)
    ALL_PKGS=("${QUICK_PKGS[@]}")
    [[ "$PROFILE" -ge 2 ]] && ALL_PKGS+=("${STD_PKGS[@]}")
    [[ "$PROFILE" -ge 3 ]] && ALL_PKGS+=("${FULL_PKGS[@]}")
    i=0; total=${#ALL_PKGS[@]}
    for pkg in "${ALL_PKGS[@]}"; do
      i=$((i+1))
      run_as_user "brew list $pkg" &>/dev/null 2>&1 && ok "[$i/$total] $pkg — already installed" && continue
      info "[$i/$total] brew install $pkg ..."
      run_as_user "brew install $pkg" >> "$LOG" 2>&1 && ok "[$i/$total] $pkg ✓" || warn "[$i/$total] $pkg — failed"
    done ;;
  linux|wsl)
    sudo apt-get update -qq >> "$LOG" 2>&1
    QUICK_PKGS=(git curl wget jq zsh build-essential python3 python3-pip golang-go nodejs npm ruby tmux fzf bat ripgrep)
    STD_PKGS=(nmap ncat hydra masscan sqlmap nikto gobuster ffuf hashcat john aircrack-ng
              binwalk exiftool steghide foremost libpcap-dev tcpdump)
    FULL_PKGS=(metasploit-framework hcxtools hcxdumptool wireshark-common tshark)
    ALL_PKGS=("${QUICK_PKGS[@]}")
    [[ "$PROFILE" -ge 2 ]] && ALL_PKGS+=("${STD_PKGS[@]}")
    [[ "$PROFILE" -ge 3 ]] && ALL_PKGS+=("${FULL_PKGS[@]}")
    for pkg in "${ALL_PKGS[@]}"; do
      sudo apt-get install -y -qq "$pkg" >> "$LOG" 2>&1 && ok "$pkg ✓" || warn "$pkg — unavailable"
    done ;;
  windows)
    case "$PKG" in
      winget)
        BASE=("Git.Git" "Python.Python.3.12" "Golang.Go" "OpenJS.NodeJS.LTS" "Nmap.Nmap")
        STD=("VeraCrypt.VeraCrypt" "Microsoft.WindowsTerminal")
        for pkg in "${BASE[@]}" $([[ "$PROFILE" -ge 2 ]] && echo "${STD[@]}"); do
          winget install --id "$pkg" --accept-source-agreements --accept-package-agreements >> "$LOG" 2>&1 && ok "$pkg ✓" || warn "$pkg — failed"
        done ;;
      choco)
        choco install -y git python3 golang nodejs nmap wireshark ruby >> "$LOG" 2>&1 ;;
    esac ;;
esac

section "STEP 2 — NODE.JS & NPM TOOLS"
if ! command -v node &>/dev/null || [[ $(node -v 2>/dev/null | tr -d 'v' | cut -d. -f1) -lt 18 ]]; then
  case "$OS" in
    macos)
      run_as_user 'export NVM_DIR="$HOME/.nvm"; curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash' >> "$LOG" 2>&1
      export NVM_DIR="$REAL_HOME/.nvm"; [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
      run_as_user "export NVM_DIR=\"$NVM_DIR\"; source \"$NVM_DIR/nvm.sh\"; nvm install 20 && nvm alias default 20" >> "$LOG" 2>&1 ;;
    linux|wsl)
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - >> "$LOG" 2>&1
      sudo apt-get install -y -qq nodejs >> "$LOG" 2>&1 ;;
  esac
fi
command -v node &>/dev/null && ok "Node.js $(node --version)" || warn "Node.js not installed"
if command -v npm &>/dev/null; then
  npm config set prefix "$REAL_HOME/.npm-global" 2>/dev/null || true
  export PATH="$REAL_HOME/.npm-global/bin:$PATH"
  grep -q "npm-global" "$SHELL_RC" 2>/dev/null || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$SHELL_RC"
  npm install -g retire wappalyzer-cli snyk --silent >> "$LOG" 2>&1 && ok "npm tools ✓"
fi

section "STEP 3 — RUST + CARGO TOOLS"
if [[ "$PROFILE" -ge 2 ]]; then
  if ! command -v cargo &>/dev/null; then
    info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path >> "$LOG" 2>&1 || true
    export PATH="$REAL_HOME/.cargo/bin:$PATH"
    grep -q "cargo/bin" "$SHELL_RC" 2>/dev/null || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$SHELL_RC"
  fi
  command -v cargo &>/dev/null && {
    ok "Rust $(rustc --version 2>&1 | cut -d' ' -f2)"
    for t in feroxbuster rustscan; do
      command -v "$t" &>/dev/null && ok "cargo: $t — exists" || \
      { info "cargo install $t ..."; cargo install "$t" >> "$LOG" 2>&1 && ok "$t ✓" || warn "$t — failed"; }
    done
  }
fi

section "STEP 4 — GO TOOLS"
if command -v go &>/dev/null; then
  export GOPATH="${GOPATH:-$REAL_HOME/go}"; export PATH="$GOPATH/bin:$PATH"
  grep -q "go/bin" "$SHELL_RC" 2>/dev/null || echo 'export GOPATH="$HOME/go"; export PATH="$GOPATH/bin:$PATH"' >> "$SHELL_RC"
  ok "Go $(go version | cut -d' ' -f3)"
  QUICK_GO=("github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
             "github.com/projectdiscovery/httpx/cmd/httpx@latest"
             "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
             "github.com/ffuf/ffuf/v2@latest")
  STD_GO=("github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
           "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
           "github.com/projectdiscovery/katana/cmd/katana@latest"
           "github.com/tomnomnom/waybackurls@latest"
           "github.com/tomnomnom/assetfinder@latest"
           "github.com/tomnomnom/gf@latest"
           "github.com/tomnomnom/anew@latest"
           "github.com/lc/gau/v2/cmd/gau@latest")
  FULL_GO=("github.com/owasp-amass/amass/v4/...@master"
            "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
            "github.com/hakluke/hakrawler@latest")
  GO_TOOLS=("${QUICK_GO[@]}")
  [[ "$PROFILE" -ge 2 ]] && GO_TOOLS+=("${STD_GO[@]}")
  [[ "$PROFILE" -ge 3 ]] && GO_TOOLS+=("${FULL_GO[@]}")
  i=0; total=${#GO_TOOLS[@]}
  for pkg in "${GO_TOOLS[@]}"; do
    i=$((i+1)); name="${pkg##*/}"; name="${name%%@*}"
    command -v "$name" &>/dev/null && ok "[$i/$total] $name — exists" || \
    { info "[$i/$total] go install $name ..."; go install "$pkg" >> "$LOG" 2>&1 && ok "[$i/$total] $name ✓" || warn "[$i/$total] $name — failed"; }
  done
fi

section "STEP 5 — PYTHON PIP TOOLS"
if command -v pip3 &>/dev/null; then
  ok "Python $(python3 --version 2>&1 | cut -d' ' -f2)"
  _pip(){ pip3 install --quiet --break-system-packages "$1" >> "$LOG" 2>&1 || pip3 install --quiet "$1" >> "$LOG" 2>&1; }
  QUICK_PIP=(requests beautifulsoup4 dnspython rich colorama)
  STD_PIP=(impacket certipy-ad pwntools scapy shodan paramiko httpx mitmproxy)
  FULL_PIP=(bloodhound volatility3 pyOpenSSL cryptography theHarvester)
  PIP_PKGS=("${QUICK_PIP[@]}")
  [[ "$PROFILE" -ge 2 ]] && PIP_PKGS+=("${STD_PIP[@]}")
  [[ "$PROFILE" -ge 3 ]] && PIP_PKGS+=("${FULL_PIP[@]}")
  i=0; total=${#PIP_PKGS[@]}
  for pkg in "${PIP_PKGS[@]}"; do
    i=$((i+1)); info "[$i/$total] pip install $pkg ..."; _pip "$pkg" && ok "[$i/$total] $pkg ✓" || warn "[$i/$total] $pkg — failed"
  done
fi

section "STEP 6 — RUBY GEMS"
if command -v gem &>/dev/null && [[ "$PROFILE" -ge 2 ]]; then
  ok "Ruby $(ruby --version 2>&1 | cut -d' ' -f2)"
  for gem in wpscan evil-winrm; do
    gem list | grep -q "^$gem " && ok "gem: $gem — exists" || \
    { info "gem install $gem ..."; gem install "$gem" --no-document >> "$LOG" 2>&1 && ok "gem: $gem ✓" || warn "gem: $gem — failed"; }
  done
fi

# PATH finalize
echo ""
! grep -q "npm-global" "$SHELL_RC" 2>/dev/null && command -v npm &>/dev/null && echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$SHELL_RC"
! grep -q "cargo/bin"  "$SHELL_RC" 2>/dev/null && [[ -d "$REAL_HOME/.cargo/bin" ]] && echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$SHELL_RC"
! grep -q "go/bin"     "$SHELL_RC" 2>/dev/null && command -v go &>/dev/null && { echo 'export GOPATH="$HOME/go"'; echo 'export PATH="$GOPATH/bin:$PATH"'; } >> "$SHELL_RC"

echo ""
echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════╗"
echo -e "  ║   ✓  PC INSTALL COMPLETE!               ║"
echo -e "  ╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Installed runtimes:${NC}"
command -v python3 &>/dev/null && echo -e "  ${GREEN}✓${NC}  Python   $(python3 --version 2>&1 | cut -d' ' -f2)"
command -v node    &>/dev/null && echo -e "  ${GREEN}✓${NC}  Node.js  $(node --version)"
command -v go      &>/dev/null && echo -e "  ${GREEN}✓${NC}  Go       $(go version | cut -d' ' -f3)"
command -v ruby    &>/dev/null && echo -e "  ${GREEN}✓${NC}  Ruby     $(ruby --version 2>&1 | cut -d' ' -f2)"
command -v rustc   &>/dev/null && echo -e "  ${GREEN}✓${NC}  Rust     $(rustc --version 2>&1 | cut -d' ' -f2)"
command -v git     &>/dev/null && echo -e "  ${GREEN}✓${NC}  git      $(git --version 2>&1 | cut -d' ' -f3)"
command -v nmap    &>/dev/null && echo -e "  ${GREEN}✓${NC}  nmap     $(nmap --version 2>&1 | head -1 | cut -d' ' -f3)"
echo ""
echo -e "  ${DIM}Activate PATH: source $SHELL_RC${NC}"
echo -e "  ${DIM}Log: $LOG${NC}"
echo ""
echo -e "  ${RED}⚠  Use only on your own / authorized systems!${NC}"
echo ""