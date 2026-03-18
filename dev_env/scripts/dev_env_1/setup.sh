#!/usr/bin/env bash
# =============================================================================
# devenv/setup.sh — Cross-platform developer environment setup
# Supports: Ubuntu 20.04/22.04/24.04 · Rocky Linux 8/9 · macOS 13+
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
LOG_FILE=""          # set after prefix is resolved
DRY_RUN=false
SUDO_CMD=""

# ── Colour helpers ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

log()     { echo -e "${CYAN}[INFO ]${RESET} $*"  | tee -a "${LOG_FILE:-/dev/null}"; }
warn()    { echo -e "${YELLOW}[WARN ]${RESET} $*" | tee -a "${LOG_FILE:-/dev/null}"; }
success() { echo -e "${GREEN}[OK   ]${RESET} $*"  | tee -a "${LOG_FILE:-/dev/null}"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2 | tee -a "${LOG_FILE:-/dev/null}"; exit 1; }
step()    { echo -e "\n${BOLD}══ $* ══${RESET}" | tee -a "${LOG_FILE:-/dev/null}"; }
dry()     { echo -e "${YELLOW}[DRY  ]${RESET} Would run: $*" | tee -a "${LOG_FILE:-/dev/null}"; }

run() {
  if $DRY_RUN; then
    dry "$*"
  else
    eval "$@"
  fi
}

# ── Read config.json with python3 ─────────────────────────────────────────────
cfg() {
  # cfg <python-key-path>   e.g.  cfg "['versions']['cmake']"
  python3 -c "import json; d=json.load(open('${CONFIG_FILE}')); print(d${1})" 2>/dev/null || true
}

# ── Default versions (overridable via env vars or config.json) ─────────────────
GIT_VERSION="${GIT_VERSION:-$(cfg "['versions']['git']['linux']")}"
GIT_VERSION="${GIT_VERSION:-2.47.1}"

GCC_VERSION="${GCC_VERSION:-$(cfg "['versions']['gcc']['version']")}"
GCC_VERSION="${GCC_VERSION:-13}"

ROCKY_TOOLSET="${ROCKY_TOOLSET:-$(cfg "['versions']['gcc']['rocky_toolset']")}"
ROCKY_TOOLSET="${ROCKY_TOOLSET:-13}"

CLANG_VERSION="${CLANG_VERSION:-$(cfg "['versions']['clang']['version']")}"
CLANG_VERSION="${CLANG_VERSION:-18}"

DOTNET_VERSION="${DOTNET_VERSION:-$(cfg "['versions']['dotnet_sdk']")}"
DOTNET_VERSION="${DOTNET_VERSION:-9.0.2}"

CMAKE_VERSION="${CMAKE_VERSION:-$(cfg "['versions']['cmake']")}"
CMAKE_VERSION="${CMAKE_VERSION:-3.25.3}"

CONAN_VERSION="${CONAN_VERSION:-$(cfg "['versions']['conan']")}"
CONAN_VERSION="${CONAN_VERSION:-2.10.2}"

NUGET_VERSION="${NUGET_VERSION:-$(cfg "['versions']['nuget']")}"
NUGET_VERSION="${NUGET_VERSION:-6.12.1}"

PYTHON_VERSION="${PYTHON_VERSION:-$(cfg "['versions']['python']")}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12.8}"

# ── Default install prefix ─────────────────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  DEFAULT_PREFIX="$(cfg "['install']['prefix_macos']")"
  DEFAULT_PREFIX="${DEFAULT_PREFIX:-/usr/local/devenv}"
else
  DEFAULT_PREFIX="$(cfg "['install']['prefix_linux']")"
  DEFAULT_PREFIX="${DEFAULT_PREFIX:-/opt/devenv}"
fi
DEVENV_PREFIX="${DEVENV_PREFIX:-${DEFAULT_PREFIX}}"

# ── Component toggles (default from config, override via env or --skip-X) ──────
_cfg_bool() { python3 -c "import json; d=json.load(open('${CONFIG_FILE}')); print(str(d['components']['${1}']).lower())" 2>/dev/null || echo "true"; }

INSTALL_GIT="${INSTALL_GIT:-$(_cfg_bool git)}"
INSTALL_GCC="${INSTALL_GCC:-$(_cfg_bool gcc)}"
INSTALL_DOTNET="${INSTALL_DOTNET:-$(_cfg_bool dotnet)}"
INSTALL_CMAKE="${INSTALL_CMAKE:-$(_cfg_bool cmake)}"
INSTALL_CONAN="${INSTALL_CONAN:-$(_cfg_bool conan)}"
INSTALL_NUGET="${INSTALL_NUGET:-$(_cfg_bool nuget)}"

# ── Argument parsing ───────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --prefix <dir>      Installation prefix  (default: ${DEFAULT_PREFIX})
  --skip-git          Do not install Git
  --skip-gcc          Do not install GCC/G++/GDB (Linux) or Clang/LLVM (macOS)
  --skip-dotnet       Do not install .NET SDK
  --skip-cmake        Do not install CMake
  --skip-conan        Do not install Conan
  --skip-nuget        Do not install NuGet
  --dry-run           Print commands without executing
  -h, --help          Show this help

Version overrides (env vars):
  GIT_VERSION, GCC_VERSION, CLANG_VERSION, DOTNET_VERSION, CMAKE_VERSION,
  CONAN_VERSION, NUGET_VERSION, DEVENV_PREFIX

Examples:
  sudo ./setup.sh
  sudo ./setup.sh --prefix /opt/build --skip-nuget
  CMAKE_VERSION=3.25.1 sudo -E ./setup.sh
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)       DEVENV_PREFIX="$2"; shift 2 ;;
    --skip-git)     INSTALL_GIT=false;   shift ;;
    --skip-gcc)     INSTALL_GCC=false;   shift ;;
    --skip-dotnet)  INSTALL_DOTNET=false; shift ;;
    --skip-cmake)   INSTALL_CMAKE=false; shift ;;
    --skip-conan)   INSTALL_CONAN=false; shift ;;
    --skip-nuget)   INSTALL_NUGET=false; shift ;;
    --dry-run)      DRY_RUN=true;        shift ;;
    -h|--help)      usage ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# ── Detect OS ──────────────────────────────────────────────────────────────────
detect_os() {
  OS_ID="unknown"
  OS_VERSION_ID=""
  PKG_MANAGER=""

  if [[ "$(uname)" == "Darwin" ]]; then
    OS_ID="macos"
    OS_VERSION_ID="$(sw_vers -productVersion 2>/dev/null || echo '')"
    PKG_MANAGER="brew"
    return
  fi

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-}"
  fi

  case "$OS_ID" in
    ubuntu|debian)
      PKG_MANAGER="apt"
      ;;
    rhel|rocky|centos|almalinux)
      PKG_MANAGER="dnf"
      ;;
    fedora)
      PKG_MANAGER="dnf"
      ;;
    *)
      error "Unsupported OS: ${OS_ID}. Supported: Ubuntu, Rocky Linux, macOS."
      ;;
  esac
}

# ── Privilege helper ───────────────────────────────────────────────────────────
check_privileges() {
  if [[ "$OS_ID" == "macos" ]]; then
    # macOS: Homebrew does not need root; prefix creation might
    SUDO_CMD=""
    return
  fi
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
      SUDO_CMD="sudo"
      warn "Not running as root — will use sudo where needed."
    else
      error "This script must be run as root (or sudo must be available)."
    fi
  fi
}

# ── Arch helper ───────────────────────────────────────────────────────────────
host_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) echo "$(uname -m)" ;;
  esac
}

# ── Package manager wrappers ───────────────────────────────────────────────────
pkg_update() {
  case "$PKG_MANAGER" in
    apt)  run "${SUDO_CMD} apt-get update -qq" ;;
    dnf)  run "${SUDO_CMD} dnf makecache --quiet" ;;
    brew) run "brew update --quiet" ;;
  esac
}

pkg_install() {
  case "$PKG_MANAGER" in
    apt)  run "${SUDO_CMD} apt-get install -y --no-install-recommends $*" ;;
    dnf)  run "${SUDO_CMD} dnf install -y $*" ;;
    brew) run "brew install $*" ;;
  esac
}

pkg_installed() {
  # pkg_installed <pkg>  → returns 0 if installed
  case "$PKG_MANAGER" in
    apt)  dpkg -s "$1" &>/dev/null ;;
    dnf)  rpm -q "$1" &>/dev/null ;;
    brew) brew list "$1" &>/dev/null ;;
  esac
}

# ── Prerequisites ──────────────────────────────────────────────────────────────
install_prerequisites() {
  step "Prerequisites"
  case "$PKG_MANAGER" in
    apt)
      pkg_install curl wget ca-certificates gnupg lsb-release software-properties-common \
                  tar xz-utils unzip python3 python3-pip python3-venv
      ;;
    dnf)
      pkg_install curl wget ca-certificates tar unzip python3 python3-pip
      if [[ "${OS_ID}" == "rhel" || "${OS_ID}" == "rocky" || "${OS_ID}" == "almalinux" ]]; then
        # Enable EPEL for extra packages
        run "${SUDO_CMD} dnf install -y epel-release" || warn "EPEL install failed — continuing."
      fi
      ;;
    brew)
      # Ensure Homebrew itself is present
      if ! command -v brew &>/dev/null; then
        log "Installing Homebrew..."
        run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      fi
      pkg_install curl wget python3
      ;;
  esac
  success "Prerequisites satisfied."
}

# ── Git ────────────────────────────────────────────────────────────────────────
install_git() {
  step "Git ${GIT_VERSION}"

  if command -v git &>/dev/null; then
    INSTALLED_GIT="$(git --version | awk '{print $3}')"
    if [[ "$INSTALLED_GIT" == "$GIT_VERSION"* ]]; then
      success "Git ${INSTALLED_GIT} already installed — skipping."
      return
    fi
    warn "Git ${INSTALLED_GIT} found but ${GIT_VERSION} requested."
  fi

  case "$PKG_MANAGER" in
    apt)
      # Use PPA for up-to-date Git on Ubuntu
      if [[ "$OS_ID" == "ubuntu" ]]; then
        run "${SUDO_CMD} add-apt-repository -y ppa:git-core/ppa"
        pkg_update
      fi
      pkg_install "git"
      ;;
    dnf)
      pkg_install git
      ;;
    brew)
      pkg_install git
      ;;
  esac

  if ! $DRY_RUN; then
    success "Git $(git --version) installed."
  fi
}

# ── C/C++ compiler + debugger ─────────────────────────────────────────────────
# Linux:  GCC/G++ (apt) or gcc-toolset (dnf/Rocky)
# macOS:  Clang/LLVM via Homebrew + lldb, lld, clang-format, clang-tidy
install_compiler() {
  if [[ "$PKG_MANAGER" == "brew" ]]; then
    step "Clang/LLVM ${CLANG_VERSION} (macOS)"

    LLVM_PREFIX="$(brew --prefix "llvm@${CLANG_VERSION}" 2>/dev/null || true)"

    # Check if already installed at the requested version
    if [[ -n "${LLVM_PREFIX}" && -x "${LLVM_PREFIX}/bin/clang" ]]; then
      INSTALLED_CLANG="$("${LLVM_PREFIX}/bin/clang" --version 2>/dev/null | head -1)"
      if [[ "${INSTALLED_CLANG}" == *"${CLANG_VERSION}"* ]]; then
        success "Clang/LLVM ${CLANG_VERSION} already installed — skipping."
        _set_macos_llvm_prefix "${LLVM_PREFIX}"
        return
      fi
    fi

    # Xcode CLT is a required base (provides SDK headers, libc++, etc.)
    if ! xcode-select -p &>/dev/null; then
      log "Installing Xcode Command Line Tools (required for SDK headers)..."
      # In CI/headless environments trigger the non-interactive path
      run "touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
      PROD="$(softwareupdate -l 2>/dev/null \
              | grep -E 'Command Line Tools for Xcode' \
              | sort -V | tail -1 \
              | sed 's/^.*\* //')"
      if [[ -n "${PROD}" ]]; then
        run "softwareupdate -i '${PROD}' --agree-to-license"
      else
        warn "Could not auto-install Xcode CLT. Run 'xcode-select --install' manually."
      fi
      run "rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    fi

    # Install LLVM (includes: clang, clang++, lld, lldb, clang-format,
    #  clang-tidy, llvm-ar, llvm-nm, llvm-objdump, llvm-ranlib, llvm-size)
    pkg_install "llvm@${CLANG_VERSION}"

    LLVM_PREFIX="$(brew --prefix "llvm@${CLANG_VERSION}")"
    _set_macos_llvm_prefix "${LLVM_PREFIX}"

    if ! $DRY_RUN; then
      success "Clang/LLVM ${CLANG_VERSION} installed."
      log "  clang:        ${LLVM_PREFIX}/bin/clang"
      log "  clang++:      ${LLVM_PREFIX}/bin/clang++"
      log "  lldb:         ${LLVM_PREFIX}/bin/lldb"
      log "  lld:          ${LLVM_PREFIX}/bin/lld"
      log "  clang-format: ${LLVM_PREFIX}/bin/clang-format"
      log "  clang-tidy:   ${LLVM_PREFIX}/bin/clang-tidy"
    fi

  else
    # ── Linux: GCC / G++ ────────────────────────────────────────────────────
    step "GCC/G++ ${GCC_VERSION} + GDB"

    case "$PKG_MANAGER" in
      apt)
        pkg_install \
          "gcc-${GCC_VERSION}" "g++-${GCC_VERSION}" \
          "gdb" "binutils" "make" "build-essential"

        # Set versioned GCC as default via update-alternatives
        run "${SUDO_CMD} update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100"
        run "${SUDO_CMD} update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 100"
        run "${SUDO_CMD} update-alternatives --install /usr/bin/cc  cc  /usr/bin/gcc-${GCC_VERSION} 100"
        run "${SUDO_CMD} update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_VERSION} 100"
        ;;

      dnf)
        # Rocky/RHEL: prefer gcc-toolset-N for specific versions
        TOOLSET_PKG="gcc-toolset-${ROCKY_TOOLSET}"
        if ${SUDO_CMD} dnf info "${TOOLSET_PKG}" &>/dev/null; then
          pkg_install "${TOOLSET_PKG}" "${TOOLSET_PKG}-gdb" "${TOOLSET_PKG}-binutils"
          TOOLSET_ENABLE="/etc/profile.d/gcc-toolset.sh"
          if ! $DRY_RUN; then
            cat <<EOENV | ${SUDO_CMD} tee "${TOOLSET_ENABLE}" > /dev/null
# Enable GCC Toolset ${ROCKY_TOOLSET}
source /opt/rh/gcc-toolset-${ROCKY_TOOLSET}/enable
EOENV
            ${SUDO_CMD} chmod +x "${TOOLSET_ENABLE}"
          fi
          log "GCC Toolset ${ROCKY_TOOLSET} will be activated via ${TOOLSET_ENABLE}"
        else
          warn "gcc-toolset-${ROCKY_TOOLSET} not found — falling back to system GCC."
          pkg_install gcc gcc-c++ gdb binutils make
        fi
        ;;
    esac

    if ! $DRY_RUN; then
      success "C/C++ toolchain installed."
    fi
  fi
}

# Store the resolved LLVM prefix so env-script generation can use it
MACOS_LLVM_PREFIX=""
_set_macos_llvm_prefix() {
  MACOS_LLVM_PREFIX="$1"
}

# ── .NET SDK ──────────────────────────────────────────────────────────────────
install_dotnet() {
  step ".NET SDK ${DOTNET_VERSION}"

  DOTNET_INSTALL_DIR="${DEVENV_PREFIX}/dotnet"
  DOTNET_BIN="${DOTNET_INSTALL_DIR}/dotnet"

  if [[ -x "${DOTNET_BIN}" ]]; then
    INSTALLED_DOTNET="$("${DOTNET_BIN}" --version 2>/dev/null || echo '')"
    if [[ "$INSTALLED_DOTNET" == "$DOTNET_VERSION"* ]]; then
      success ".NET SDK ${INSTALLED_DOTNET} already installed at ${DOTNET_INSTALL_DIR} — skipping."
      return
    fi
    warn ".NET SDK ${INSTALLED_DOTNET} found but ${DOTNET_VERSION} requested — reinstalling."
  fi

  run "${SUDO_CMD} mkdir -p '${DOTNET_INSTALL_DIR}'"

  DOTNET_INSTALL_SCRIPT="/tmp/dotnet-install.sh"
  log "Downloading dotnet-install.sh..."
  run "curl -fsSL https://dot.net/v1/dotnet-install.sh -o '${DOTNET_INSTALL_SCRIPT}'"
  run "chmod +x '${DOTNET_INSTALL_SCRIPT}'"

  # Install SDK only (no ASP.NET runtime)
  run "${DOTNET_INSTALL_SCRIPT} \
    --channel \"${DOTNET_VERSION%.*}\" \
    --version '${DOTNET_VERSION}' \
    --runtime 'dotnet' \
    --install-dir '${DOTNET_INSTALL_DIR}' \
    --no-path"

  # Also install the SDK (the above installs runtime; this installs SDK)
  run "${DOTNET_INSTALL_SCRIPT} \
    --channel \"${DOTNET_VERSION%.*}\" \
    --version '${DOTNET_VERSION}' \
    --install-dir '${DOTNET_INSTALL_DIR}' \
    --no-path"

  if ! $DRY_RUN; then
    success ".NET SDK $("${DOTNET_BIN}" --version) installed at ${DOTNET_INSTALL_DIR}."
  fi
}

# ── CMake ─────────────────────────────────────────────────────────────────────
install_cmake() {
  step "CMake ${CMAKE_VERSION}"

  CMAKE_INSTALL_DIR="${DEVENV_PREFIX}/cmake"
  CMAKE_BIN="${CMAKE_INSTALL_DIR}/bin/cmake"

  if [[ -x "${CMAKE_BIN}" ]]; then
    INSTALLED_CMAKE="$("${CMAKE_BIN}" --version 2>/dev/null | head -1 | awk '{print $3}')"
    if [[ "$INSTALLED_CMAKE" == "$CMAKE_VERSION"* ]]; then
      success "CMake ${INSTALLED_CMAKE} already installed at ${CMAKE_INSTALL_DIR} — skipping."
      return
    fi
    warn "CMake ${INSTALLED_CMAKE} found but ${CMAKE_VERSION} requested — reinstalling."
  fi

  ARCH="$(host_arch)"
  CMAKE_MAJOR_MINOR="${CMAKE_VERSION%.*}"   # e.g. 3.25

  case "$(uname)" in
    Linux)
      CMAKE_PKG="cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz"
      CMAKE_URL="https://cmake.org/files/v${CMAKE_MAJOR_MINOR}/${CMAKE_PKG}"
      CMAKE_DIR_NAME="cmake-${CMAKE_VERSION}-linux-${ARCH}"
      ;;
    Darwin)
      CMAKE_PKG="cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
      CMAKE_URL="https://cmake.org/files/v${CMAKE_MAJOR_MINOR}/${CMAKE_PKG}"
      CMAKE_DIR_NAME="cmake-${CMAKE_VERSION}-macos-universal"
      ;;
  esac

  TMP_DIR="$(mktemp -d)"
  log "Downloading ${CMAKE_PKG}..."
  run "curl -fsSL '${CMAKE_URL}' -o '${TMP_DIR}/${CMAKE_PKG}'"
  run "tar -xzf '${TMP_DIR}/${CMAKE_PKG}' -C '${TMP_DIR}'"
  run "${SUDO_CMD} rm -rf '${CMAKE_INSTALL_DIR}'"
  run "${SUDO_CMD} mkdir -p '$(dirname "${CMAKE_INSTALL_DIR}")'"

  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS archive has CMake.app inside
    run "${SUDO_CMD} mv '${TMP_DIR}/${CMAKE_DIR_NAME}/CMake.app/Contents' '${CMAKE_INSTALL_DIR}'"
  else
    run "${SUDO_CMD} mv '${TMP_DIR}/${CMAKE_DIR_NAME}' '${CMAKE_INSTALL_DIR}'"
  fi

  run "rm -rf '${TMP_DIR}'"

  if ! $DRY_RUN; then
    success "CMake $("${CMAKE_BIN}" --version | head -1) installed at ${CMAKE_INSTALL_DIR}."
  fi
}

# ── Conan ─────────────────────────────────────────────────────────────────────
install_conan() {
  step "Conan ${CONAN_VERSION}"

  CONAN_VENV="${DEVENV_PREFIX}/conan-venv"
  CONAN_BIN="${CONAN_VENV}/bin/conan"

  if [[ -x "${CONAN_BIN}" ]]; then
    INSTALLED_CONAN="$("${CONAN_BIN}" --version 2>/dev/null | awk '{print $NF}')"
    if [[ "$INSTALLED_CONAN" == "$CONAN_VERSION"* ]]; then
      success "Conan ${INSTALLED_CONAN} already installed — skipping."
      return
    fi
    warn "Conan ${INSTALLED_CONAN} found but ${CONAN_VERSION} requested — reinstalling."
  fi

  # Install into an isolated venv so pip doesn't pollute the system
  run "${SUDO_CMD} python3 -m venv '${CONAN_VENV}'"
  run "${SUDO_CMD} '${CONAN_VENV}/bin/pip' install --quiet --upgrade pip"
  run "${SUDO_CMD} '${CONAN_VENV}/bin/pip' install --quiet 'conan==${CONAN_VERSION}'"

  if ! $DRY_RUN; then
    success "Conan $("${CONAN_BIN}" --version) installed in ${CONAN_VENV}."
  fi
}

# ── NuGet ─────────────────────────────────────────────────────────────────────
install_nuget() {
  step "NuGet ${NUGET_VERSION}"

  # On Linux/macOS the dotnet CLI provides 'dotnet nuget' commands (recommended).
  # Optionally download nuget.exe for Mono compatibility.
  NUGET_DIR="${DEVENV_PREFIX}/nuget"
  NUGET_EXE="${NUGET_DIR}/nuget.exe"
  NUGET_WRAPPER="${DEVENV_PREFIX}/bin/nuget"

  if [[ -f "${NUGET_EXE}" ]]; then
    success "nuget.exe already present at ${NUGET_EXE} — skipping."
    return
  fi

  run "${SUDO_CMD} mkdir -p '${NUGET_DIR}'"
  run "${SUDO_CMD} mkdir -p '${DEVENV_PREFIX}/bin'"

  NUGET_URL="https://dist.nuget.org/win-x86-commandline/v${NUGET_VERSION}/nuget.exe"
  log "Downloading nuget.exe v${NUGET_VERSION}..."
  run "${SUDO_CMD} curl -fsSL '${NUGET_URL}' -o '${NUGET_EXE}'"

  # Create a wrapper that runs nuget.exe via dotnet script runner or mono
  if ! $DRY_RUN; then
    cat <<'WRAPPER' | ${SUDO_CMD} tee "${NUGET_WRAPPER}" > /dev/null
#!/usr/bin/env bash
# nuget wrapper — runs nuget.exe via mono (if available) or delegates to dotnet nuget
NUGET_EXE="$(dirname "$(realpath "$0")")/../nuget/nuget.exe"
if command -v mono &>/dev/null; then
  exec mono "${NUGET_EXE}" "$@"
else
  echo "[WARN] mono not found; delegating to 'dotnet nuget'. Install mono for full nuget.exe support." >&2
  exec dotnet nuget "$@"
fi
WRAPPER
    ${SUDO_CMD} chmod +x "${NUGET_WRAPPER}"
  fi

  success "nuget.exe ${NUGET_VERSION} downloaded. Use the 'nuget' wrapper or 'dotnet nuget' commands."
}

# ── Generate environment activation script ─────────────────────────────────────
generate_env_script() {
  step "Generating environment activation script"

  ENV_SCRIPT="${DEVENV_PREFIX}/env.sh"

  if ! $DRY_RUN; then
    ${SUDO_CMD} mkdir -p "${DEVENV_PREFIX}/bin"
    cat <<ENVSCRIPT | ${SUDO_CMD} tee "${ENV_SCRIPT}" > /dev/null
#!/usr/bin/env bash
# =============================================================================
# DevEnv environment activation — generated by setup.sh
# Source this file:  source ${ENV_SCRIPT}
# =============================================================================

DEVENV_ROOT="${DEVENV_PREFIX}"

# .NET SDK
if [[ -d "\${DEVENV_ROOT}/dotnet" ]]; then
  export DOTNET_ROOT="\${DEVENV_ROOT}/dotnet"
  export PATH="\${DOTNET_ROOT}:\${PATH}"
  # Suppress telemetry on build machines
  export DOTNET_CLI_TELEMETRY_OPTOUT=1
  export DOTNET_NOLOGO=1
fi

# CMake
if [[ -d "\${DEVENV_ROOT}/cmake/bin" ]]; then
  export PATH="\${DEVENV_ROOT}/cmake/bin:\${PATH}"
fi

# Conan (venv)
if [[ -d "\${DEVENV_ROOT}/conan-venv/bin" ]]; then
  export PATH="\${DEVENV_ROOT}/conan-venv/bin:\${PATH}"
  export CONAN_HOME="\${DEVENV_ROOT}/conan-home"
fi

# NuGet wrapper
if [[ -d "\${DEVENV_ROOT}/bin" ]]; then
  export PATH="\${DEVENV_ROOT}/bin:\${PATH}"
fi

# GCC Toolset (Rocky Linux)
if [[ -f /etc/profile.d/gcc-toolset.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/gcc-toolset.sh
fi

# Clang/LLVM (macOS — Homebrew)
if [[ -d "${MACOS_LLVM_PREFIX}/bin" ]]; then
  export PATH="${MACOS_LLVM_PREFIX}/bin:\${PATH}"
  export LDFLAGS="-L${MACOS_LLVM_PREFIX}/lib \${LDFLAGS:-}"
  export CPPFLAGS="-I${MACOS_LLVM_PREFIX}/include \${CPPFLAGS:-}"
  export CC="${MACOS_LLVM_PREFIX}/bin/clang"
  export CXX="${MACOS_LLVM_PREFIX}/bin/clang++"
fi

echo "[devenv] Environment activated (root: \${DEVENV_ROOT})"
ENVSCRIPT
    ${SUDO_CMD} chmod +x "${ENV_SCRIPT}"
    success "Activation script written to ${ENV_SCRIPT}"
    log "Add the following to your shell profile or CI pipeline:"
    echo ""
    echo "    source ${ENV_SCRIPT}"
    echo ""
  fi
}

# ── Print summary ──────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗"
  echo -e "║           DevEnv Setup Summary                       ║"
  echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
  printf "  %-18s  %s\n" "OS"       "${OS_ID} ${OS_VERSION_ID}"
  printf "  %-18s  %s\n" "Prefix"   "${DEVENV_PREFIX}"
  printf "  %-18s  %s\n" "Git"      "$(command -v git &>/dev/null && git --version | awk '{print $3}' || echo 'skipped')"
  case "$PKG_MANAGER" in
    apt)  _cc="$(gcc --version 2>/dev/null | head -1 || echo 'skipped')"
          printf "  %-18s  %s\n" "GCC/G++"  "${_cc}" ;;
    dnf)  _cc="$(gcc --version 2>/dev/null | head -1 || echo 'see gcc-toolset profile')"
          printf "  %-18s  %s\n" "GCC/G++"  "${_cc}" ;;
    brew) if [[ -n "${MACOS_LLVM_PREFIX}" && -x "${MACOS_LLVM_PREFIX}/bin/clang" ]]; then
            _cc="$("${MACOS_LLVM_PREFIX}/bin/clang" --version 2>/dev/null | head -1)"
          else
            _cc="skipped"
          fi
          printf "  %-18s  %s\n" "Clang/LLVM" "${_cc}" ;;
  esac
  printf "  %-18s  %s\n" ".NET SDK" "$([[ -x "${DEVENV_PREFIX}/dotnet/dotnet" ]] && "${DEVENV_PREFIX}/dotnet/dotnet" --version || echo 'skipped')"
  printf "  %-18s  %s\n" "CMake"    "$([[ -x "${DEVENV_PREFIX}/cmake/bin/cmake" ]] && "${DEVENV_PREFIX}/cmake/bin/cmake" --version | head -1 | awk '{print $3}' || echo 'skipped')"
  printf "  %-18s  %s\n" "Conan"    "$([[ -x "${DEVENV_PREFIX}/conan-venv/bin/conan" ]] && "${DEVENV_PREFIX}/conan-venv/bin/conan" --version | awk '{print $NF}' || echo 'skipped')"
  printf "  %-18s  %s\n" "NuGet"    "$([[ -f "${DEVENV_PREFIX}/nuget/nuget.exe" ]] && echo "v${NUGET_VERSION} (nuget.exe)" || echo 'skipped')"
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  detect_os
  check_privileges

  # Now that prefix is known, set up log file
  if ! $DRY_RUN; then
    ${SUDO_CMD} mkdir -p "${DEVENV_PREFIX}/logs"
    LOG_FILE="${DEVENV_PREFIX}/logs/setup-$(date +%Y%m%d-%H%M%S).log"
    ${SUDO_CMD} touch "${LOG_FILE}"
    ${SUDO_CMD} chmod 666 "${LOG_FILE}"
  fi

  echo -e "${BOLD}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║          Developer Environment Setup                 ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  log "OS:      ${OS_ID} ${OS_VERSION_ID}"
  log "Prefix:  ${DEVENV_PREFIX}"
  log "Dry run: ${DRY_RUN}"
  $DRY_RUN && warn "DRY-RUN MODE — no changes will be made."

  install_prerequisites

  [[ "${INSTALL_GIT}"    == "true" ]] && install_git
  [[ "${INSTALL_GCC}"    == "true" ]] && install_compiler
  [[ "${INSTALL_DOTNET}" == "true" ]] && install_dotnet
  [[ "${INSTALL_CMAKE}"  == "true" ]] && install_cmake
  [[ "${INSTALL_CONAN}"  == "true" ]] && install_conan
  [[ "${INSTALL_NUGET}"  == "true" ]] && install_nuget

  generate_env_script

  if ! $DRY_RUN; then
    print_summary
    success "DevEnv setup complete. Log: ${LOG_FILE}"
  else
    success "Dry run complete — no changes made."
  fi
}

main "$@"
