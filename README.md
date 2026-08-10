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
4. Shows every app from `Brewfile.apps` in a grouped picker — nothing is
   pre-selected; SPACE toggles an app, typing a group name then Ctrl-A
   selects the whole group, ENTER installs

Everything is safe to re-run; already-installed packages and completed steps
are skipped.

## Existing machine

To re-apply after changing things:

```
./setup.sh
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
| `Brewfile.apps`     | All optional apps, grouped, chosen via picker  |
| everything else     | Dotfiles, stowed into `$HOME`                  |

Adding or removing an app is just editing the relevant Brewfile. Mac App
Store apps work too, via [mas](https://github.com/mas-cli/mas): add a line
like `mas "AppName", id: 12345` (find ids with `mas search <name>`; requires
being signed in to the App Store).

## Using this as someone else

Fork the repo, edit the two variables at the top of `bootstrap.sh`
(`REPO_HTTPS` and `DOTFILES_DIR`), and run the one-liner against your fork's
raw URL. Everything else adapts: `setup.sh` derives the SSH remote from
wherever the repo was actually cloned from, and the app lists are plain
Brewfiles to edit.
