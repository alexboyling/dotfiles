# Core utilities — always installed on every machine.
# Applied by setup.sh via `brew bundle`, which skips anything already
# installed — re-running is free.

brew "stow"   # for symlinking dotfiles (https://www.gnu.org/software/stow/)
brew "fzf"    # command-line fuzzy finder (https://github.com/junegunn/fzf)
brew "zoxide" # smarter cd command (https://github.com/ajeetdsouza/zoxide)
brew "bat"    # cat replacement (https://github.com/sharkdp/bat)
brew "eza"    # ls replacement (https://eza.rocks)
brew "micro"  # nano replacement (https://micro-editor.github.io/index.html)
brew "colima" # container runtimes (https://github.com/abiosoft/colima)
brew "gh"     # GitHub CLI, handles SSH auth (https://cli.github.com)
brew "mas"    # Mac App Store CLI, enables `mas` lines in Brewfiles — needs
              # an App Store sign-in before those install (https://github.com/mas-cli/mas)
brew "mise"   # version manager for python/node/etc, replaces pyenv+nvm (https://mise.jdx.dev)
brew "zinit"  # zsh plugin manager, sourced in .zshrc (https://github.com/zdharma-continuum/zinit)

# Deliberately the homebrew-core formula, not the official
# jandedobbeleer/oh-my-posh tap: untrusted taps need an interactive
# `brew trust` on new machines, which would break unattended setup
brew "oh-my-posh" # prompt theming (https://ohmyposh.dev)

cask "font-commit-mono-nerd-font"
