#!/bin/bash

DOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
OS="$(uname -s)"
ARCH="$(uname -m)"

exists() {
    command -v "$1" >/dev/null 2>&1
}

is_macos() {
    [[ "$OS" == "Darwin" ]]
}

is_linux() {
    [[ "$OS" == "Linux" ]]
}

ensure_homebrew() {
    if exists brew; then
        return 0
    fi

    echo "Homebrew not found; installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Apple Silicon installs to /opt/homebrew
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! exists brew; then
        echo "Homebrew installation failed or brew is not on PATH" >&2
        return 1
    fi
}

kubectl_platform() {
    local os arch
    case "$OS" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *)
            echo "Unsupported OS for kubectl: $OS" >&2
            return 1
            ;;
    esac

    case "$ARCH" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="amd64" ;;
        *)
            echo "Unsupported architecture for kubectl: $ARCH" >&2
            return 1
            ;;
    esac

    echo "${os}/${arch}"
}

# True if kubectl exists and can actually run on this machine
# (guards against leftover linux/amd64 binaries on macOS).
kubectl_usable() {
    exists kubectl || return 1
    kubectl version --client >/dev/null 2>&1
}

install_kubectl() {
    if is_macos; then
        ensure_homebrew || return 1
        echo "install kubectl via Homebrew"
        brew install kubectl
        # Drop an unusable binary earlier on PATH (e.g. leftover linux/amd64).
        if exists kubectl && ! kubectl_usable; then
            local bad
            bad="$(command -v kubectl)"
            echo "removing unusable kubectl at ${bad}"
            sudo rm -f "${bad}"
        fi
        if kubectl_usable; then
            return 0
        fi
        echo "Homebrew kubectl not usable yet; falling back to direct download" >&2
    fi

    local RELEASE PLATFORM DEST TMP
    RELEASE=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    PLATFORM=$(kubectl_platform) || return 1
    TMP="$(mktemp -d)"
    DEST="/usr/local/bin/kubectl"

    echo "install kubectl (${PLATFORM}) to ${DEST}"
    curl -fL "https://dl.k8s.io/release/${RELEASE}/bin/${PLATFORM}/kubectl" -o "${TMP}/kubectl"
    chmod +x "${TMP}/kubectl"

    if sudo mv "${TMP}/kubectl" "${DEST}"; then
        rm -rf "${TMP}"
        return 0
    fi

    # No sudo: install to a user bin that is on PATH
    DEST="${HOME}/.local/bin/kubectl"
    mkdir -p "$(dirname "${DEST}")"
    mv "${TMP}/kubectl" "${DEST}"
    rm -rf "${TMP}"
    echo "installed kubectl to ${DEST}"
    echo "if another kubectl earlier on PATH is broken, remove it: sudo rm -f \$(command -v kubectl)"
}

install_packages() {
    if is_macos; then
        echo "install some basic command line utilities using Homebrew"

        ensure_homebrew || return 1

        local packages=(
            curl
            git
            ripgrep
            rsync
            tmux
            tree
            vifm
            vim
            zsh
            jq
            bat
            eza
            duf
            coreutils
            fzf
        )

        brew update
        brew install "${packages[@]}"
    elif is_linux; then
        echo "install some basic command line utilities using apt"

        local packages=(
            curl
            git
            ripgrep
            rsync
            tmux
            tree
            vifm
            vim-athena
            xsel
            zsh
            jq
            dnsutils
            bat
            eza
            duf
            fzf
        )
        # vim-athena has +clipboard and +python3

        sudo apt update
        # shellcheck disable=SC2086
        echo ${packages[*]} | xargs sudo apt install --assume-yes
    else
        echo "Unsupported OS: $OS" >&2
        return 1
    fi
}

install_dev_packages() {
    if is_macos; then
        echo "install some packages for development using Homebrew"

        ensure_homebrew || return 1

        if ! xcode-select -p >/dev/null 2>&1; then
            echo "install Xcode Command Line Tools"
            xcode-select --install || true
        fi

        local packages=(
            clang-format
            llvm
            universal-ctags
            python
        )

        brew update
        brew install "${packages[@]}"

        # Prefer brew clangd if available
        if [[ -x "$(brew --prefix llvm)/bin/clangd" ]]; then
            echo "clangd is available via: $(brew --prefix llvm)/bin/clangd"
            echo "Add \$(brew --prefix llvm)/bin to your PATH if needed"
        fi
    elif is_linux; then
        echo "install some packages for development using apt"

        local packages=(
            build-essential
            clang-format
            clangd-9
            exuberant-ctags
            python3-dev
        )

        sudo apt update
        # shellcheck disable=SC2086
        echo ${packages[*]} | xargs sudo apt install --assume-yes

        echo "make clangd-9 the default clangd"
        sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-9 100
    else
        echo "Unsupported OS: $OS" >&2
        return 1
    fi
}

install_powerline_symbols() {
    echo "install powerline symbols"
    local URL="https://github.com/powerline/powerline/raw/develop/font"
    local FONT_DIR
    local FONT_FILE="PowerlineSymbols.otf"
    local legacy="${HOME}/.local/share/fonts/${FONT_FILE}"

    if is_macos; then
        # macOS apps (Cursor, Terminal.app, iTerm) only see fonts under Library/Fonts.
        # ~/.local/share/fonts is ignored — a common cause of tofu glyphs in tmux.
        FONT_DIR="${HOME}/Library/Fonts"
    else
        FONT_DIR="${HOME}/.local/share/fonts"
    fi

    mkdir -p "${FONT_DIR}"

    # Migrate a previous Linux-style install path on macOS.
    if is_macos && [[ -f "${legacy}" && ! -e "${FONT_DIR}/${FONT_FILE}" ]]; then
        echo "moving ${legacy} -> ${FONT_DIR}/${FONT_FILE}"
        mv "${legacy}" "${FONT_DIR}/${FONT_FILE}"
    fi

    if [[ ! -e "${FONT_DIR}/${FONT_FILE}" ]]; then
        curl -fLo "${FONT_DIR}/${FONT_FILE}" "${URL}/${FONT_FILE}" --create-dirs

        if is_linux && exists fc-cache; then
            fc-cache -vf "${FONT_DIR}"
            curl -fLo ~/.config/fontconfig/conf.d/10-powerline-symbols.conf \
                "${URL}/10-powerline-symbols.conf" --create-dirs
        fi
    fi

    if is_macos; then
        install_nerd_font_macos
        configure_macos_terminal_fonts
    fi
}

# MesloLGS Nerd Font includes Powerline / Private Use glyphs used by tmux status.
install_nerd_font_macos() {
    local font_file="${HOME}/Library/Fonts/MesloLGSNerdFont-Regular.ttf"

    if [[ -f "${font_file}" ]]; then
        echo "MesloLGS Nerd Font already installed"
        return 0
    fi

    ensure_homebrew || return 1
    echo "install MesloLGS Nerd Font (Homebrew cask)"
    brew install --cask font-meslo-lg-nerd-font
}

# Point Terminal.app and iTerm2 at MesloLGS Nerd Font so tmux Powerline
# separators render (Cursor uses settings.json separately).
configure_macos_terminal_fonts() {
    local font_family="MesloLGS Nerd Font"
    local font_size="13"

    echo "configure macOS terminal fonts -> ${font_family}"

    # --- Terminal.app -------------------------------------------------------
    if [[ -d /System/Applications/Utilities/Terminal.app ]] || [[ -d /Applications/Utilities/Terminal.app ]]; then
        echo "  Terminal.app: set default / startup / all profile fonts"
        osascript <<EOF >/dev/null || warn_terminal_font "Terminal.app"
tell application "Terminal"
    activate
    try
        set font name of default settings to "${font_family}"
        set font size of default settings to ${font_size}
    end try
    try
        set font name of startup settings to "${font_family}"
        set font size of startup settings to ${font_size}
    end try
    repeat with s in settings sets
        try
            set font name of s to "${font_family}"
            set font size of s to ${font_size}
        end try
    end repeat
end tell
EOF
    fi

    # --- iTerm2 -------------------------------------------------------------
    if [[ -d /Applications/iTerm.app ]] || [[ -d /Applications/iTerm2.app ]] \
        || [[ -f "${HOME}/Library/Preferences/com.googlecode.iterm2.plist" ]]; then
        echo "  iTerm2: set Normal Font on all profiles"
        python3 - "${font_family}" "${font_size}" <<'PY' || warn_terminal_font "iTerm2"
import plistlib
import sys
from pathlib import Path

family, size = sys.argv[1], sys.argv[2]
font_value = f"{family} {size}"
plist_path = Path.home() / "Library/Preferences/com.googlecode.iterm2.plist"

if not plist_path.exists():
    print(f"    iTerm2 preferences not found at {plist_path}; open iTerm once, then re-run", file=sys.stderr)
    sys.exit(1)

with plist_path.open("rb") as f:
    data = plistlib.load(f)

bookmarks = data.get("New Bookmarks")
if not isinstance(bookmarks, list) or not bookmarks:
    print("    no iTerm2 profiles (New Bookmarks) found", file=sys.stderr)
    sys.exit(1)

changed = 0
for bookmark in bookmarks:
    if not isinstance(bookmark, dict):
        continue
    if bookmark.get("Normal Font") != font_value:
        bookmark["Normal Font"] = font_value
        changed += 1
    # Prefer one font for ASCII and non-ASCII (Powerline glyphs live here).
    bookmark["Use Non-ASCII Font"] = False

with plist_path.open("wb") as f:
    plistlib.dump(data, f)

print(f"    updated {changed} iTerm2 profile(s); restart iTerm2 to apply")
PY
    else
        echo "  iTerm2 not installed; skipping"
    fi

    # --- Cursor / VS Code integrated terminal -------------------------------
    local cursor_settings="${HOME}/Library/Application Support/Cursor/User/settings.json"
    if [[ -f "${cursor_settings}" ]] || [[ -d "${cursor_settings%/*}" ]]; then
        echo "  Cursor: set terminal.integrated.fontFamily"
        mkdir -p "${cursor_settings%/*}"
        python3 - "${cursor_settings}" "${font_family}" <<'PY' || warn_terminal_font "Cursor"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
family = sys.argv[2]
data = {}
if path.exists() and path.stat().st_size:
    raw = path.read_text()
    # VS Code / Cursor settings allow comments; strip // line comments lightly
    lines = []
    for line in raw.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        lines.append(line)
    try:
        data = json.loads("\n".join(lines))
    except json.JSONDecodeError:
        data = json.loads(raw)

if not isinstance(data, dict):
    data = {}

data["terminal.integrated.fontFamily"] = family
path.write_text(json.dumps(data, indent=4) + "\n")
print(f"    wrote {path}")
PY
    fi

    echo "  Restart Terminal.app / iTerm2 (and reload Cursor) to apply"
}

warn_terminal_font() {
    echo "  warning: could not configure $1 font automatically" >&2
}

install_kubernetes_tools() {
    if kubectl_usable; then
        echo "kubectl found"
    else
        if exists kubectl; then
            echo "kubectl present but not runnable on ${OS}/${ARCH}; reinstalling"
        fi
        install_kubectl || return 1
    fi

    if ! exists helm; then
        echo "install helm"
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh
        sudo ./get_helm.sh
        rm ./get_helm.sh
    else
        echo "helm found"
    fi
}

install_docker_in_wsl2() {
    if is_macos; then
        echo "Docker in WSL2 is Linux-only. On macOS, install Docker Desktop instead:"
        echo "  https://docs.docker.com/desktop/install/mac-install/"
        if exists brew; then
            echo "Or: brew install --cask docker"
        fi
        return 0
    fi

    # tested with ubuntu 24.04

    # System is up to date
    sudo apt update && sudo apt upgrade -y

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Install the docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index
    sudo apt update

    # Install docker
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # No sudo for docker commands
    sudo groupadd docker || true
    sudo usermod -aG docker "$USER"

    echo "restart WSL2 to apply the changes"
    echo "execute \"wsl --shutdown\" in cmd or pwsh"
}

configure_vim() {
    echo "configure vim"

    ln -svf "${DOTDIR}/vimrc" ~/.vimrc

    # never overwrite existing .vimrc.local
    if [ ! -f ~/.vimrc.local ]; then
        cp "${DOTDIR}/vimrc.local" ~/.vimrc.local
    fi

    echo "install vim plugins"
    vim "+PlugInstall" "+qa"
}

configure_tmux() {
    echo "configure tmux"

    ln -svf "${DOTDIR}/tmux.conf" ~/.tmux.conf
}

configure_git() {
    echo "configure git"

    ln -svf "${DOTDIR}/gitconfig.base" ~/.gitconfig.base

    if [ ! -e ~/.gitignore ]; then
        ln -sv "${DOTDIR}/gitignore" ~/.gitignore
    fi

    if [ ! -e ~/.git_template ]; then
        ln -sv "${DOTDIR}/git_template" ~/.git_template
    else
        echo "could not create ~/.git_template/ as it already exists"
    fi

    if [ ! -e ~/.gitmessage ]; then
        echo "creating empty .gitmessage file"
        touch ~/.gitmessage
    fi

    # never overwrite existing .gitconfig
    if [ ! -f ~/.gitconfig ]; then
        cp "${DOTDIR}/gitconfig" ~/.gitconfig
        echo "please edit your user in ~/.gitconfig"
    fi
}

configure_zsh() {
    echo "configure zsh"
    echo "download prompt"
    if [ ! -d ~/.zsh/pure ]; then
        git clone https://github.com/sindresorhus/pure.git ~/.zsh/pure
    fi
    echo "download colors"
    curl -fLo ~/.zsh/dircolors/dircolors.ansi-dark \
        https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark \
        --create-dirs
    mkdir -p ~/.zsh/completions
    mkdir -p ~/.zsh/cache
    ln -svf "${DOTDIR}/zshrc" ~/.zshrc
}

configure_vifm() {
    echo "configure vifm"

    local VIFM_CONFIG="${HOME}/.config/vifm"
    mkdir -vp "${VIFM_CONFIG}/colors"

    ln -svf "${DOTDIR}/solarized-dark.vifm" "${VIFM_CONFIG}/colors/solarized-dark.vifm"
    ln -svf "${DOTDIR}/vifmrc" "${VIFM_CONFIG}/vifmrc"
}

configure_kubernetes_tools() {
    echo "configure kubernetes tools"

    if [ ! -d ~/.zsh/completions ]; then
        return 0
    fi

    if ! kubectl_usable; then
        echo "skipping kubectl completion: kubectl missing or not runnable" >&2
    else
        kubectl completion zsh > ~/.zsh/completions/_kubectl
    fi

    if ! exists helm; then
        echo "skipping helm completion: helm not found" >&2
    else
        helm completion zsh > ~/.zsh/completions/_helm
    fi
}

configure_github_cli() {
    if is_macos; then
        ensure_homebrew || return 1
        brew install gh
    elif is_linux; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh
    else
        echo "Unsupported OS: $OS" >&2
        return 1
    fi

    echo "choose \"GitHub.com\", \"HTTPS\", \"Authenticate Git with your GitHub credentials=YES\" and \"Login with a web browser\""
    gh auth login
}

help() {
    echo "Install and configure the dotfiles
    -h|--help               show this help

    --install_packages      my dev packages
    --powerline_symbols     PowerlineSymbols (+ macOS: Nerd Font, Terminal/iTerm)
    --install_k8s           install kubectl, helm
    --install_all           installs all above options
    --install_docker_wsl2   installs docker in wsl2 (no docker desktop)

    --configure_all         configures all below options
    --configure_vim
    --configure_tmux
    --configure_git
    --configure_zsh
    --configure_vifm
    --configure_k8s

Without arguments, the default applies:
    --install_packages
    --install_k8s
    --configure_all
"
}

array=()

if [[ "$#" -eq 0 ]]; then
    array+=(1)
    array+=(13)
    array+=(6)
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) help; exit 0;;

        --install_packages) array+=(1);;
        --powerline_symbols) array+=(3);;
        --install_k8s) array+=(13);;
        --install_all) array+=(5);;
        --install_docker_wsl2) array+=(14);;

        --configure_all) array+=(6);;
        --configure_vim) array+=(7);;
        --configure_tmux) array+=(8);;
        --configure_git) array+=(9);;
        --configure_zsh) array+=(10);;
        --configure_vifm) array+=(11);;
        --configure_k8s) array+=(12);;

        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

for choice in "${array[@]}"; do
    case "$choice" in
        1)
            install_packages
            ;;
        3)
            install_powerline_symbols
            ;;
        13)
            install_kubernetes_tools
            ;;
        14)
            install_docker_in_wsl2
            ;;
        5)
            install_packages
            install_powerline_symbols
            install_kubernetes_tools
            ;;
        6)
            configure_vim
            configure_tmux
            configure_git
            configure_zsh
            configure_vifm
            configure_kubernetes_tools
            ;;
        7)
            configure_vim
            ;;
        8)
            configure_tmux
            ;;
        9)
            configure_git
            ;;
        10)
            configure_zsh
            ;;
        11)
            configure_vifm
            ;;
        12)
            configure_kubernetes_tools
            ;;
        *)
            echo "invalid number $choice"
            ;;
    esac
done

unset array
unset DOTDIR
unset OS
unset ARCH

# vim:set et sw=4 ts=4 fdm=indent:
