#!/bin/bash

# Bootstrap a new Mac.
#
# Run this on a fresh machine with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/alexboyling/dotfiles/main/bootstrap.sh)"
#
# The bash -c form matters: it keeps stdin attached to the terminal, which
# the interactive steps in setup.sh (gh auth login, profile picker) need.
# A plain `curl | bash` would leave stdin pointing at the pipe.
#
# It installs the bare minimum needed to get the dotfiles repo onto the
# machine (Xcode Command Line Tools, Homebrew, a clone of this repo over
# HTTPS), then hands off to setup.sh in the repo for everything else.
# Safe to re-run: every step checks before acting.

# Strict mode: -e exits on any error, -u makes undefined variables errors,
# pipefail makes a pipeline fail if any command in it fails (not just the last)
set -euo pipefail

REPO_HTTPS="https://github.com/alexboyling/dotfiles.git"
DOTFILES_DIR="$HOME/repos/dotfiles"

# Xcode Command Line Tools (required by Homebrew and provides git)
if xcode-select -p &>/dev/null; then
	echo "✅ Xcode Command Line Tools already installed."
else
	echo "🛠️  Installing Xcode Command Line Tools..."
	xcode-select --install
	# This loop waits forever if the install dialog is cancelled — there is
	# no way to detect a cancel, so bail out manually if you change your mind
	echo "Click Install on the prompt. Waiting for installation to finish (Ctrl-C to abort)..."
	until xcode-select -p &>/dev/null; do
		sleep 5
	done
	echo "✅ Xcode Command Line Tools installed."
fi

# Homebrew
if command -v brew &>/dev/null; then
	echo "✅ Homebrew already installed."
else
	echo "🍺 Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available in this shell and in future login shells.
# NOTE: assumes Apple Silicon (brew lives in /opt/homebrew). An Intel Mac
# puts brew in /usr/local and would need this block adjusted.
if [ -x /opt/homebrew/bin/brew ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	if ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
	fi
fi

# Clone the dotfiles repo over HTTPS (no SSH key needed yet — the repo is
# public; setup.sh switches the remote to SSH once GitHub auth is set up)
if [ -d "$DOTFILES_DIR/.git" ]; then
	echo "✅ Dotfiles repo already cloned at $DOTFILES_DIR."
	# Converge on the latest version. --ff-only never merges or rebases, so
	# local commits/changes are left alone — warn and carry on instead
	git -C "$DOTFILES_DIR" pull --ff-only ||
		echo "⚠️  Could not fast-forward $DOTFILES_DIR — continuing with the local version."
else
	echo "📦 Cloning dotfiles repo to $DOTFILES_DIR..."
	mkdir -p "$(dirname "$DOTFILES_DIR")"
	git clone "$REPO_HTTPS" "$DOTFILES_DIR"
fi

# Hand off to the repo's setup script for everything else.
# </dev/tty re-attaches stdin to the terminal so setup.sh's interactive
# prompts work even if this script was piped into bash
exec "$DOTFILES_DIR/setup.sh" "$@" </dev/tty
