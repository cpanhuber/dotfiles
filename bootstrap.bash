#!/bin/bash

function exists() {
  command -v $1 >/dev/null 2>&1
}

function is_installed() {
    dpkg-query -W -f='${Status}' $1 | grep 'ok installed' > /dev/null
}

function ensure_fzf() {
    # Install a fuzzy file finder for the command line (https://github.com/junegunn/fzf)
    fzf_install_dir=~/.fzf
    if exists fzf; then
        echo 'Updating fzf'
        fzf_install_dir=$(dirname $(dirname $(which fzf)))
        git -C $fzf_install_dir pull -q
        $fzf_install_dir/install --bin > /dev/null
    else
        echo 'Installing fzf'
        if [ -e $fzf_install_dir ]; then rm -rf $fzf_install_dir; fi
        git clone --depth 1 https://github.com/junegunn/fzf.git $fzf_install_dir -q
        $fzf_install_dir/install --update-rc --key-bindings --completion --no-bash > /dev/null
    fi
}

function ensure_oh_my_zsh() {
    export ZSH=$HOME/.oh-my-zsh

    if [ ! -e "$ZSH" ]; then
        echo 'Install OhMyZsh'
        # Install my customized oh-my-zsh version
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/FaBrand/oh-my-zsh/master/tools/install.sh)"
        chsh -s /bin/zsh

    else
        echo 'OhMyZsh already installed - updating'
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/FaBrand/oh-my-zsh/master/tools/upgrade.sh)"
    fi
}

function ensure_powerline_fonts() {
    echo 'Install powerline fonts'
    local POWERLINE_URL='https://github.com/powerline/powerline/raw/develop/font'
    local POWERLINE_SYMBOLS_FILE='PowerlineSymbols.otf'
    local POWERLINE_SYMBOLS_CONF='10-powerline-symbols.conf'

    if [ ! -e ~/.fonts/$POWERLINE_SYMBOLS_FILE ]; then
        curl -fsSL $POWERLINE_URL/$POWERLINE_SYMBOLS_FILE -o /tmp/$POWERLINE_SYMBOLS_FILE
        mkdir ~/.fonts 2> /dev/null
        mv /tmp/$POWERLINE_SYMBOLS_FILE ~/.fonts/$POWERLINE_SYMBOLS_FILE
        fc-cache -vf ~/.fonts/
    fi

    if [ ! -e ~/.config/fontconfig/conf.d/$POWERLINE_SYMBOLS_CONF ]; then
        curl -fsSL $POWERLINE_URL/$POWERLINE_SYMBOLS_CONF -o /tmp/$POWERLINE_SYMBOLS_CONF
        mkdir -p ~/.config/fontconfig/conf.d 2> /dev/null
        mv /tmp/$POWERLINE_SYMBOLS_CONF ~/.config/fontconfig/conf.d/$POWERLINE_SYMBOLS_CONF
    fi
}

function ensure_solarized_color_scheme() {
    local SOLARIZED_INSTALL_DIR=~/.solarized
    if ! exists dconf; then
        echo 'Package dconf-cli required for solarized colors!'
        return -1
    elif [ ! -d $SOLARIZED_INSTALL_DIR ]; then
        bash -c 'read -p "Have you already defined a new profile in your Terminal preferences e.g. 'SolDark'? If not add it now and continue by pressing the return key..."'
        echo Install solarized color scheme
        git clone https://github.com/Anthony25/gnome-terminal-colors-solarized.git $SOLARIZED_INSTALL_DIR -q
        $SOLARIZED_INSTALL_DIR/install.sh --install-dircolors
    else
        echo 'Solarized theme already installed'
    fi
}

function ensure_dotfiles() {
    # never overwrite existing .vimrc.local
    if [ ! -f ~/.vimrc.local ]; then
        cp .vimrc.local ~/.vimrc.local
    fi

    bash -c 'read -p "Do you want to copy the dotfiles to your home reposory? (This may overwrite some files) Are you sure? (y/[n]) " -n 1;'
    echo "";
    if [[ $REPLY =~ ^[YyZz]$ ]]; then
        rsync --exclude '.git/' \
            --exclude 'bootstrap.bash' \
            --exclude '.vimrc.local' \
            --exclude 'README.md' \
            --exclude 'catkin_aliases/*' \
            -avh --no-perms . ~;
    fi
}

function _patch_git_config() {
    echo 'Patch gitconfig to include the Settings'
    touch ~/.gitconfig
    grep 'path = ~/.git_settings' ~/.gitconfig > /dev/null
    if [ ! $? -eq 0 ]; then
        echo "[include]" >> ~/.gitconfig
        echo "    path = ~/.git_settings" >> ~/.gitconfig
    fi
}

function _patch_zshrc() {
    echo 'Set Theme to bira'
    sed -i 's/^ZSH_THEME.*/ZSH_THEME="bira"/' ~/.zshrc
}

function patch_dotfiles() {
    _patch_zshrc
    _patch_git_config
}

function ensure_vim_configuration() {
    # Check vim installation and perform changes if necessary
    if is_installed vim-tiny; then
        echo 'Removing vim-tiny installation'
        sudo apt-get -qq remove vim-tiny
    fi

    if is_installed vim-gnome; then
        echo 'vim gnome already installed. Updating vim'
        sudo apt-get update -qq
        sudo apt-get install --only-upgrade -qq -y vim-gnome
    else
        echo 'Installing vim (huge config)'
        sudo apt-get install -qq vim-gnome
    fi
    vim +PlugInstall +PlugUpdate +PlugUpgrade +qall
}

function ensure_bazel() {
    if exists bazel; then
        echo 'Bazel already installed. Upgrading bazel'
        sudo apt-get update -qq
        sudo apt-get install --only-upgrade -qq -y bazel
    else
        echo "Installing bazel"
        echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list > /dev/null
        curl --silent https://bazel.build/bazel-release.pub.gpg | sudo apt-key add -
        sudo apt-get update -qq
        sudo apt-get install -qq -y bazel
    fi
}

function ensure_bazel_zsh_completion() {
    zsh_completion_dir=~/.zsh/completion
    [ -f $zsh_completion_dir ] && mkdir $zsh_completion_dir
    curl -fsSL "https://raw.githubusercontent.com/bazelbuild/bazel/master/scripts/zsh_completion/_bazel" -o $zsh_completion_dir/_bazel
}

function ensure_buildifier() {
    echo "Downloading buildifier"
    install_path=/opt/buildifier/buildifier
    sudo rm -rf $(dirname $install_path) 2> /dev/null
    sudo mkdir -p $(dirname $install_path)

    #Downloading
    curl -fsSL "https://api.github.com/repos/bazelbuild/buildtools/releases/latest" | jq '.assets[] | select( .name == "buildifier" ) | .browser_download_url' | xargs sudo curl -fsSL -o $install_path
    sudo chmod +x $install_path

    #Make it visible
    buildifier_symlink=/usr/local/bin/buildifier
    [ ! -e $buildifier_symlink ] && sudo ln -s $install_path $buildifier_symlink
}

function ensure_packages() {
    # Install usefull packages
    packages=(
        build-essential
        clang-format
        clang-tidy
        cmake
        cppcheck
        curl
        dconf-cli
        exuberant-ctags
        git
        htop
        meld
        nmon
        python-dev
        python3-dev
        rsync
        silversearcher-ag
        taskwarrior
        tmux
        tmuxinator
        tree
        valgrind
        xsel
        zsh
        jq
    )

    echo 'Performing apt-get update'
    sudo apt-get -qq update

    echo "Installing items"
    echo ${packages[*]} | xargs sudo apt install --assume-yes
}

function install_full() {
    ensure_packages
    ensure_powerline_fonts
    ensure_solarized_color_scheme
    ensure_oh_my_zsh
    ensure_fzf
    ensure_vim_configuration
    ensure_bazel
    ensure_buildifier
    ensure_dotfiles
    patch_dotfiles
}
