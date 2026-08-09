# XDG config home for consistent cross-platform tool configuration
export XDG_CONFIG_HOME="$HOME/.config"

# Homebrew env (PATH, MANPATH, HOMEBREW_* vars) — everything brew installs
# lives under /opt/homebrew and is invisible without this
eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$PATH" # user-installed tools (pipx, uv, etc.)
export EDITOR=micro                  # git commits, crontab -e, anything that asks

# mise — one version manager for python/node/etc (replaces pyenv + nvm).
# No runtimes are installed until needed: `mise use -g python@latest` (or
# node@latest) installs and sets a global default; per-project versions come
# from .tool-versions/.python-version/.nvmrc files (https://mise.jdx.dev)
eval "$(mise activate zsh)"

# Google Cloud SDK (installed by its own installer, not brew) — puts gcloud
# on PATH and wires up its completions. Guarded so shells on machines
# without it are unaffected.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# zinit — zsh plugin manager (https://github.com/zdharma-continuum/zinit).
# Installed via the Brewfile like everything else in this file; the plugins
# it manages are cloned into ~/.local/share/zinit on first shell start
source "${HOMEBREW_PREFIX}/opt/zinit/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting # colour commands as you type (red = not found)
zinit light zsh-users/zsh-completions         # extra completion definitions for common tools
zinit light zsh-users/zsh-autosuggestions     # ghost-text suggestion from history; → accepts
zinit light Aloxaf/fzf-tab                    # tab completion becomes an fzf fuzzy picker

# oh-my-zsh's git aliases (gst, gco, gp, glog, ...) without the rest of OMZ
zinit snippet OMZP::git

# Initialise zsh's completion system, then replay the completions zinit
# captured while plugins loaded (cdreplay) so plugin completions register
autoload -U compinit && compinit
zinit cdreplay -q

# Prompt theming via oh-my-posh with the "pure" theme. Skipped in Apple
# Terminal, which can't render the nerd-font glyphs themes rely on
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
	eval "$(oh-my-posh init zsh --config "${HOMEBREW_PREFIX}/opt/oh-my-posh/themes/pure.omp.json")"
fi

# Ctrl-P/N: search history for commands starting with what's already typed
# (unlike plain ↑/↓, which walk through everything)
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History — one big deduplicated stream shared across terminals.
# autosuggestions and Ctrl-R both feed off this, so bigger + cleaner = better
HISTSIZE=50000              # lines kept in memory per session
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE          # lines persisted to the file
setopt appendhistory        # append to the file on exit, never overwrite it
setopt sharehistory         # new commands appear in other open terminals immediately
setopt hist_ignore_space    # a leading space keeps a command out of history (secrets)
setopt hist_ignore_all_dups # re-running a command erases the older duplicate entry
setopt hist_save_no_dups    # never write duplicates to the file
setopt hist_find_no_dups    # history search skips duplicates

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive matching
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # colour entries like ls does
zstyle ':completion:*' menu no                          # no built-in menu — fzf-tab draws it
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'         # dir preview on cd tab
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath' # ...and on zoxide jumps

# Aliases — modern replacements installed via the Brewfile
alias ls='eza'  # nicer output, --tree mode, git awareness; `command ls` for the original
alias cat='bat' # syntax highlighting + paging; `command cat` for the original

# fzf keybindings: Ctrl-R fuzzy history search, Ctrl-T file finder, Alt-C cd
eval "$(fzf --zsh)"
# zoxide replaces cd: learns directories as you visit them, then `cd foo`
# jumps to the best-ranked match from anywhere (plain paths still work)
eval "$(zoxide init --cmd cd zsh)"
