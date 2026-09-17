#!/bin/bash

# Set up this machine from the dotfiles repo.
#
# Usually invoked by bootstrap.sh on a fresh machine, but can be run
# directly at any time:
#   ./setup.sh
#
# Steps:
#   1. Install core utilities from Brewfile (always)
#   2. Symlink dotfiles into $HOME with stow
#   3. Install global default runtimes declared in .config/mise/config.toml
#   4. Authenticate with GitHub over SSH (gh handles key generation/upload)
#   5. Pick apps to install from Brewfile.apps (nothing pre-selected)
#   6. Prompt for git identity + signing, written to ~/.gitconfig.local
#   7. Offer to apply macOS defaults (trackpad, dock, finder, hotkeys)
#
# Safe to re-run: brew bundle skips installed packages, stow --restow
# refreshes symlinks, and auth steps are skipped once configured.

# Strict mode: -e exits on any error, -u makes undefined variables errors,
# pipefail makes a pipeline fail if any command in it fails (not just the last)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

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
# Pre-create ~/.config so stow links its children individually instead of
# "folding" — symlinking the missing directory as a whole into the repo.
# A folded ~/.config sends every app's writes (gh auth state, editor
# databases, ...) straight into the working tree. NOTE: any future stowed
# top-level directory needs the same pre-creation here.
mkdir -p "$HOME/.config"

echo "🔗 Symlinking dotfiles with stow..."
conflicts=$(stow --no --restow --target="$HOME" . 2>&1 |
	sed -n 's/.*existing target is not owned by stow: //p') || true
for f in $conflicts; do
	echo "⚠️  Backing up existing ~/$f to ~/$f.pre-stow"
	mv "$HOME/$f" "$HOME/$f.pre-stow"
done
stow --restow --target="$HOME" .

# 3. Global default runtimes (node, python) — declared in the stowed
# .config/mise/config.toml, so this must run after stow. mise install
# materialises whatever is missing and skips what's already there.
echo "🧪 Installing global runtimes with mise..."
mise install

# 4. GitHub authentication over SSH
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

# 5. Apps — everything opt-in via picker, nothing pre-selected.
# awk labels each entry with its most recent "## Group" heading, so picker
# rows read:  Group  cask "name"  # comment
# Typing filters on group names too, and Ctrl-A selects everything currently
# matching — so "dev" + Ctrl-A selects the whole Dev tools group. cut strips
# the label afterwards so raw Brewfile lines flow on to brew bundle.
echo "📱 Choose apps to install..."
selection=$(awk '
	/^## / { group = substr($0, 4) }
	/^[[:space:]]*(tap|brew|cask|mas)[[:space:]]/ { printf "%-20s\t%s\n", group, $0 }
' "$DOTFILES_DIR/Brewfile.apps" |
	fzf --multi --height=~100% --layout=reverse --delimiter='\t' \
		--bind 'space:toggle' --bind 'ctrl-a:select-all' \
		--header="SPACE toggle · group name + Ctrl-A selects group · ENTER installs · ESC skips" \
		--prompt="apps > " | cut -f2) || true

if [ -z "${selection:-}" ]; then
	echo "Nothing selected — skipping app installation."
else
	# --file=- reads a Brewfile from stdin — i.e. just the lines picked above
	echo "$selection" | brew bundle --file=-
fi

# 6. Git identity + commit signing. Machine-specific (personal vs work
# email, signing mechanism), so it lives in ~/.gitconfig.local — which the
# stowed .gitconfig includes — and is prompted rather than committed.
# Runs after the app picker so choosing 1Password signing on a machine
# that just installed 1Password works. Only asked when the file doesn't
# exist yet; edit or delete ~/.gitconfig.local to redo.
if [ -f "$HOME/.gitconfig.local" ]; then
	echo "✅ Git identity already configured (~/.gitconfig.local)."
else
	echo "🪪 Configuring git identity (written to ~/.gitconfig.local)..."
	read -rp "  Git name: " git_name
	read -rp "  Git email for this machine: " git_email
	git config --file "$HOME/.gitconfig.local" user.name "$git_name"
	git config --file "$HOME/.gitconfig.local" user.email "$git_email"

	echo "  Commit signing (puts the Verified badge on GitHub commits):"
	echo "    1) this machine's SSH key — reuses the key gh set up, fully automatic"
	echo "    2) 1Password — signs with a vault key via Touch ID; needs 1Password"
	echo "       installed, signed in, and its SSH integration enabled"
	echo "    3) none"
	read -rp "  Choose [1/2/3]: " signing
	case "$signing" in
	2)
		# op-ssh-sign only works once 1Password is fully onboarded (app
		# installed + signed in + SSH agent enabled in its settings); the
		# install check below catches the scriptable part of that
		if [ ! -d "/Applications/1Password.app" ]; then
			echo "⚠️  1Password isn't installed — skipping signing. Install it"
			echo "   (apps picker), then delete ~/.gitconfig.local and re-run setup."
		else
			# 1Password holds the private key; git only needs the PUBLIC half
			# (copy it from the key's entry in 1Password)
			read -rp "  Public signing key from 1Password (ssh-ed25519 ...): " signing_key
			git config --file "$HOME/.gitconfig.local" gpg.format ssh
			git config --file "$HOME/.gitconfig.local" gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
			git config --file "$HOME/.gitconfig.local" user.signingkey "$signing_key"
			git config --file "$HOME/.gitconfig.local" commit.gpgsign true
		fi
		;;
	3)
		echo "  Skipping commit signing."
		;;
	*)
		# Default (1, or just Enter): GitHub registers auth and signing keys
		# separately — uploading the same key again with --type signing is
		# what makes commits made with it verify
		git config --file "$HOME/.gitconfig.local" gpg.format ssh
		git config --file "$HOME/.gitconfig.local" user.signingkey "$HOME/.ssh/id_ed25519.pub"
		git config --file "$HOME/.gitconfig.local" commit.gpgsign true
		gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --type signing --title "$(hostname) signing" ||
			echo "⚠️  Couldn't upload the signing key — add ~/.ssh/id_ed25519.pub as a signing key on GitHub manually."
		;;
	esac
fi

# 7. macOS defaults — personal system preferences. Prompted because they're
# taste, not necessity; skipping leaves the machine untouched. Runs after
# the app picker so the Raycast check below sees a just-installed Raycast.
# All writes are idempotent — re-applying is harmless.
read -rp "🖥  Apply macOS defaults (tap-to-click, dock autohide, finder, ⌘Space → Raycast)? [y/N] " apply_defaults
if [[ "$apply_defaults" =~ ^[Yy] ]]; then
	# Trackpad: tap to click (all three writes needed: builtin trackpad,
	# bluetooth trackpad, and the per-host global that System Settings reads)
	defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
	defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
	defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

	# Dock: auto-hide
	defaults write com.apple.dock autohide -bool true

	# Dock: pin only System Settings (Finder and Trash are permanent
	# fixtures, not pinned apps, so they survive the reset).
	# NOTE: re-applying wipes any apps pinned since the last run
	defaults write com.apple.dock persistent-apps -array
	defaults write com.apple.dock persistent-apps -array-add "<dict>
		<key>tile-data</key><dict><key>file-data</key><dict>
			<key>_CFURLString</key><string>/System/Applications/System Settings.app</string>
			<key>_CFURLStringType</key><integer>0</integer>
		</dict></dict></dict>"

	# Finder: new windows open in the home folder ("PfHm" = home; see
	# NewWindowTarget for the other magic codes)
	defaults write com.apple.finder NewWindowTarget -string "PfHm"
	defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

	# Finder: show filename extensions, hidden dotfiles, and the path bar
	defaults write NSGlobalDomain AppleShowAllExtensions -bool true
	defaults write com.apple.finder AppleShowAllFiles -bool true
	defaults write com.apple.finder ShowPathbar -bool true

	# Window tiling: no margins between tiled windows
	# (System Settings → Desktop & Dock → "Tiled windows have margins")
	defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

	# Hand ⌘Space from Spotlight to Raycast — only when Raycast is actually
	# installed, so a machine without it never loses the shortcut entirely.
	# Spotlight's ⌘Space is symbolic hotkey 64; the XML is its definition
	# (space=49, cmd=1048576) with enabled=false. Raycast reads its hotkey
	# from raycastGlobalHotkey (49 = space keycode).
	if [ -d "/Applications/Raycast.app" ]; then
		defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "
			<dict>
				<key>enabled</key><false/>
				<key>value</key><dict>
					<key>parameters</key><array>
						<integer>32</integer><integer>49</integer><integer>1048576</integer>
					</array>
					<key>type</key><string>standard</string>
				</dict>
			</dict>"
		defaults write com.raycast.macos raycastGlobalHotkey -string "Command-49"
	fi

	# Make it all take effect: restart Dock and Finder, and nudge the system
	# to reload the hotkey table (otherwise it waits for logout)
	killall Dock Finder
	hotkey_reload="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
	[ -x "$hotkey_reload" ] && "$hotkey_reload" -u
	echo "✅ macOS defaults applied (trackpad change may need a log out)."
else
	echo "Skipping macOS defaults."
fi

echo "Setup finished ✅"
