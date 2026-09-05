# Linux Setup

The supported Linux baseline is Debian 12 or Ubuntu 24.04. Other
distributions are not handled by the package automation in this review.

## 1. Install Bootstrap Packages

```sh
sudo apt-get update
sudo apt-get install -y git openssh-client chezmoi
```

Only Git, its SSH client, and chezmoi are needed before the repository exists.
The managed package script installs the remaining runtime dependencies.

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

The apply process installs CA certificates, curl, Fish, Git, Git LFS, GnuPG,
and the OpenSSH client through APT. It then bootstraps mise and rustup,
installs the native stable Rust toolchain, and converges the mise toolset.

If packages are missing, APT may ask for the sudo password during this first
apply.

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

Register the official WezTerm APT repository:

```sh
curl -fsSL https://apt.fury.io/wez/gpg.key \
    | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg

echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
    | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null

sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
sudo apt-get update
sudo apt-get install -y wezterm-nightly
```

The managed WezTerm configuration launches `/usr/bin/fish --login -i`.
Linux uses native paths; the Windows environment quarantine and bridge
scripts do not run.

Start `wezterm` after installation.
