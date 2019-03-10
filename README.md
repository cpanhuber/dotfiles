# My linux dotfiles for vim, tmux and zsh

**Warning:** If you want to give these dotfiles a try, you should first fork
this repository, review the code, and remove things you don’t want or need.
Don’t blindly use my settings unless you know what that entails. Use at your
own risk!

This repository is mainly to keep my personal changes.
Thanks to [DDrexl](https://github.com/ddrexl) who helped me getting started with vim
with, but not only, the collection of dotfiles.

## Install
### Copy & Paste Installation (Interaction is still required)
The bootstrapper script, will overwrite the dotfiles in your home directory, so you should make a backup.
You will be asked for confirmation though.
The bootstrap script also installs a customized fork of the oh-my-zsh theme with some plugins being activated by default.
There are also some tweaks that enable colors in the terminal.

```bash
git clone git@github.com:FaBrand/dotfiles.git ~/dotfiles
source ~/dotfiles/bootstrap.bash && install_full
```

## Known Problems

On some setups it appears that the install of oh-my-zsh can't wasn't successfull.
e.g. The two-lined bira theme is not used.

Try changing the defult shell like this and logout and in again afterwards.
```bash
chsh $USER -s $(which zsh)
```
Open the link if this error ocurs [PAM authentication Error](https://www.google.de/search?q=ubuntu+chsh+pam+authentication+failure).


## Add your private configuration

The following files are reserved for your private local configuration:
 - `~/.vimrc.local`
 - `~/.zshrc.local`

If they don't exist, an initial version will be set up.

Your .gitconfig will be amended with an include to the git settings from here.
This is only done once (if necessary)
```
[include]
    path = ~/.git_settings
```

## Feedback

Feel free to leave your [suggestions/improvements](https://github.com/FaBrand/dotfiles/issues)!

## Thanks to…

* [Mathias Bynens](https://mathiasbynens.be/) and his [dotfiles repository](https://github.com/mathiasbynens/dotfiles)

