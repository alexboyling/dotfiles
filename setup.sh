#!/bin/bash

# Set up this machine from the dotfiles repo.
#
# Usually invoked by bootstrap.sh on a fresh machine, but can be run
# directly at any time:
#   ./setup.sh [personal|work]
#
# Steps:
#   1. Install core utilities from Brewfile (always)
#   2. Symlink dotfiles into $HOME with stow
#   3. Authenticate with GitHub over SSH (gh handles key generation/upload)
#   4. Install apps for the chosen profile, with a picker to opt in/out
#
# Safe to re-run: brew bundle skips installed packages, stow --restow
# refreshes symlinks, and auth steps are skipped once configured.

# Strict mode: -e exits on any error, -u makes undefined variables errors,
# pipefail makes a pipeline fail if any command in it fails (not just the last)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Fail fast on a bad profile argument, before any slow work happens
profile="${1:-}"
if [ -n "$profile" ] && [ ! -f "$DOTFILES_DIR/Brewfile.$profile" ]; then
	echo "❌ Unknown profile '$profile'. Available: $(echo Brewfile.* | sed 's/Brewfile\.//g')"
	exit 1
fi

if ! command -v brew &>/dev/null; then
	echo "❌ Homebrew is not installed. Run bootstrap.sh first."
	exit 1
fi

# 1. Core utilities — always installed
echo "🧰 Installing core utilities..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 2. Symlink dotfiles into $HOME
# A pre-existing real file (e.g. a ~/.zshrc created before this setup, or
# brought over by Migration Assistant) makes stow abort. Detect conflicts
# with a dry run (--no) first and move each offender aside as <name>.pre-stow
# so the stow below succeeds and nothing is silently lost.
echo "🔗 Symlinking dotfiles with stow..."
conflicts=$(stow --no --restow --target="$HOME" . 2>&1 |
	sed -n 's/.*existing target is not owned by stow: //p') || true
for f in $conflicts; do
	echo "⚠️  Backing up existing ~/$f to ~/$f.pre-stow"
	mv "$HOME/$f" "$HOME/$f.pre-stow"
done
stow --restow --target="$HOME" .

# 3. GitHub authentication over SSH
if gh auth status &>/dev/null; then
	echo "✅ Already authenticated with GitHub."
else
	echo "🔑 Authenticating with GitHub..."
	echo "   When prompted, choose SSH and let gh generate/upload a key for you."
	gh auth login --git-protocol ssh
fi

# Load SSH keys into the agent automatically and store passphrases in the
# macOS keychain.
# NOTE: IdentityFile assumes gh generated ~/.ssh/id_ed25519 (its default when
# no key exists). If the key is actually named something else this line is
# harmlessly wrong: id_ed25519 is in ssh's default lookup list anyway, and
# ssh falls back to whatever keys the agent holds — which is where
# AddKeysToAgent put the real one — so auth still succeeds.
SSH_CONFIG_FILE="$HOME/.ssh/config"
if ! grep -qs "Host github.com" "$SSH_CONFIG_FILE"; then
	echo "Adding GitHub configuration to ~/.ssh/config..."
	mkdir -p "$HOME/.ssh"
	# <<- (vs <<) strips leading tabs from the heredoc, so the block can be
	# indented here but is written flush-left to ~/.ssh/config
	cat <<-EOL >>"$SSH_CONFIG_FILE"

		Host github.com
		  AddKeysToAgent yes
		  UseKeychain yes
		  IdentityFile ~/.ssh/id_ed25519
	EOL
fi

# Now that SSH auth works, switch the repo remote from HTTPS (which
# bootstrap.sh used because it needs no auth) to SSH so future pushes use
# the key. The SSH URL is derived from the existing origin URL rather than
# hardcoded, so forks work without editing this file.
origin_url=$(git remote get-url origin)
if [[ "$origin_url" == https://github.com/* ]]; then
	ssh_url="git@github.com:${origin_url#https://github.com/}"
	echo "Switching dotfiles remote to SSH ($ssh_url)..."
	git remote set-url origin "$ssh_url"
fi

# 4. Profile apps — opt in/out via picker
# The list of profiles is derived from the Brewfile.* files on disk, so
# adding a new profile is just adding a Brewfile.<name>
if [ -z "$profile" ]; then
	profile=$(printf "%s\n" Brewfile.* | sed 's/^Brewfile\.//' |
		fzf --height=~50% --layout=reverse \
			--header="What kind of machine is this?" --prompt="profile > ") || true
fi

if [ -z "$profile" ]; then
	echo "No profile chosen — skipping app installation."
else
	echo "📱 Choose apps to install for the '$profile' profile..."
	selection=$(grep -E '^\s*(tap|brew|cask|mas)\s' "$DOTFILES_DIR/Brewfile.$profile" |
		fzf --multi --height=~100% --layout=reverse \
			--bind 'start:select-all' --bind 'space:toggle' \
			--header="SPACE to toggle, ENTER to install, ESC to skip" \
			--prompt="apps ($profile) > ") || true

	if [ -z "${selection:-}" ]; then
		echo "Nothing selected — skipping app installation."
	else
		# --file=- reads a Brewfile from stdin — i.e. just the lines picked above
		echo "$selection" | brew bundle --file=-
	fi
fi

echo "Setup finished ✅"
