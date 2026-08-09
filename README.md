# My dotfiles

Dotfiles and machine setup for my Macs, symlinked into `$HOME` with
[GNU stow](https://www.gnu.org/software/stow/).

## New machine

On a fresh Mac, run:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/alexboyling/dotfiles/main/bootstrap.sh)"
```

This installs Xcode Command Line Tools and Homebrew, clones this repo to
`~/repos/dotfiles`, and then runs `setup.sh`, which:

1. Installs core utilities from `Brewfile` (always)
2. Symlinks the dotfiles into `$HOME` with stow
3. Authenticates with GitHub over SSH (`gh` generates and uploads the key)
4. Asks whether this is a `personal` or `work` machine, then shows the apps
   from the matching `Brewfile.<profile>` in a picker — everything is
   selected by default, SPACE toggles, ENTER installs

Everything is safe to re-run; already-installed packages and completed steps
are skipped.

## Existing machine

To re-apply after changing things:

```
./setup.sh personal   # or: ./setup.sh work, or no argument to be prompted
```

To only refresh the symlinks:

```
stow --restow --target="$HOME" .
```

## Layout

| File                | Purpose                                        |
| ------------------- | ---------------------------------------------- |
| `bootstrap.sh`      | Curl-able entry point for a fresh machine      |
| `setup.sh`          | Main setup: brew bundle, stow, GitHub, apps    |
| `Brewfile`          | Core utilities, always installed               |
| `Brewfile.personal` | Apps for personal machines (opt in/out picker) |
| `Brewfile.work`     | Apps for work machines (opt in/out picker)     |
| everything else     | Dotfiles, stowed into `$HOME`                  |

Adding or removing an app is just editing the relevant Brewfile.

## Using this as someone else

Fork the repo, edit the two variables at the top of `bootstrap.sh`
(`REPO_HTTPS` and `DOTFILES_DIR`), and run the one-liner against your fork's
raw URL. Everything else adapts: `setup.sh` derives the SSH remote from
wherever the repo was actually cloned from, and the app lists are plain
Brewfiles to edit.

Reference: [Dreams of Autonomy](https://www.youtube.com/watch?v=y6XCebnB9gs)
