# macOS Setup

This setup supports both Apple Silicon and Intel Macs. Homebrew must already
be installed and available in the current shell.

## 1. Install chezmoi

```sh
brew install chezmoi
```

Git and curl are supplied by the macOS environment required by Homebrew. Fish
and Git LFS are installed later by this repository.

## 2. Authenticate Git and Initialize

Configure [GitHub SSH authentication] and confirm that the key is accepted:

```sh
ssh -T git@github.com
```

[GitHub SSH authentication]: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

```sh
chezmoi init git@github.com:Rollphes/dotfiles.git
```

Inspect the intended changes before applying them:

```sh
chezmoi diff
```

## 3. Apply the Configuration

```sh
chezmoi apply
```

The apply process installs Fish and Git LFS through Homebrew, bootstraps mise
and rustup, installs the native stable Rust toolchain, and converges the mise
toolset.

Start a managed Fish session:

```sh
fish
```

Verify the managed tools:

```sh
fish --version
git lfs version
mise --version
rustup show active-toolchain
```

## 4. Authenticate GitHub CLI

Authentication remains machine-local and is not stored in this repository:

```sh
gh auth login
gh auth status
```

The managed Git configuration invokes the stable mise shim for `gh`.

## 5. Install WezTerm Nightly

```sh
brew install --cask wezterm@nightly
```

The managed WezTerm configuration launches native Homebrew Fish from
`/opt/homebrew/bin/fish` on Apple Silicon or `/usr/local/bin/fish` on Intel.

Start WezTerm from Applications after installation. macOS uses native paths;
the Windows environment quarantine and bridge scripts do not run.
