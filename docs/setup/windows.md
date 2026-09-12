# Windows Setup

This setup uses Windows 11 and the MSYS2 UCRT64 environment.

## 1. Prepare Windows and MSYS2

Enable Windows Developer Mode:

```text
Settings
  -> System
  -> Advanced
  -> For developers
  -> Developer Mode
```

Developer Mode allows the Windows symbolic links managed by this repository to
be created without elevation. A runner that already has symlink privilege can
also create them; the apply does not change Windows privilege settings.

Install [MSYS2] at the supported root:

```text
C:\msys64
```

[MSYS2]: https://www.msys2.org/

Start the UCRT64 environment:

```text
C:\msys64\ucrt64.exe
```

Update MSYS2 and install the bootstrap packages:

```sh
pacman -Syu
pacman -S --needed \
    fish \
    mingw-w64-ucrt-x86_64-curl \
    mingw-w64-ucrt-x86_64-git \
    openssh \
    unzip
```

Restart the UCRT64 environment if requested during the update, then start
Fish:

```sh
fish
```

## 2. Install chezmoi and mise

Install chezmoi into the MSYS2 home:

```fish
mkdir -p "$HOME/.local/bin"
curl -fsLS https://get.chezmoi.io \
    | sh -s -- -b "$HOME/.local/bin"
```

Download `mise-v<version>-windows-x64.zip` from the [mise releases page].
Extract it and copy both files into `$HOME/.local/bin`:

```text
mise.exe
mise-shim.exe
```

In the UCRT64 environment, `$HOME/.local/bin` resolves under:

```text
C:\msys64\home\<username>\.local\bin
```

[mise releases page]: https://github.com/jdx/mise/releases

Verify both bootstrap tools:

```fish
"$HOME/.local/bin/chezmoi" --version
"$HOME/.local/bin/mise.exe" --version
```

## 3. Authenticate Git and Initialize

Configure [GitHub SSH authentication] before initialization. The managed
GitHub CLI credential helper does not exist until after the first apply.
Confirm that the SSH key is accepted:

```fish
ssh -T git@github.com
```

[GitHub SSH authentication]: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

Then initialize through SSH:

```fish
"$HOME/.local/bin/chezmoi" init \
    git@github.com:Rollphes/dotfiles.git
```

Do not replace `init` with a direct clone followed by `apply`. During init,
the repository's `.chezmoi.toml.tmpl` creates the local chezmoi configuration
that selects:

```text
destination: C:/msys64/home/<username>
sh interpreter: C:/msys64/usr/bin/sh.exe
```

Verify that this contract was generated correctly:

```fish
"$HOME/.local/bin/chezmoi" target-path
```

The result must point to the MSYS2 home, not the Windows user home.

Inspect and apply the managed state:

```fish
"$HOME/.local/bin/chezmoi" diff
"$HOME/.local/bin/chezmoi" apply
```

The apply installs the remaining MSYS2 dependencies, including Git LFS, and
converges Rust, mise tools, Fish integrations, managed user fonts, and the
selected Windows bridges. Existing conflicting Windows resources are not
overwritten.

Verify the managed tools:

```fish
git lfs version
mise --version
rustup show active-toolchain
```

## 4. Authenticate GitHub CLI

Authentication remains machine-local:

```fish
gh auth login
gh auth status
```

The Windows Git config is a symlink to the canonical config in the MSYS2
home. The managed credential helper calls the stable mise shim. GitHub's web,
API and gist credential contexts reset inherited helpers independently. Each
helper invocation restates the canonical HOME, XDG, mise and MSYS2 temp paths
because the gh shim starts a nested native mise process.

## 5. Install WezTerm Nightly

Install the Windows Nightly build from the [WezTerm installation page], then
start WezTerm.

[WezTerm installation page]: https://wezterm.org/install/windows.html

The managed configuration launches UCRT64 Fish and keeps the Windows and
MSYS2 homes isolated except for the selected bridges.

## 6. Run a Runtime Leakage Audit

Record filesystem state before and after normal interactive CLI work:

```fish
audit start
# Use CLI tools normally.
audit stop
audit report
```

The audit leaves no background process running. Reports and snapshots are kept
under `$XDG_STATE_HOME/dotfiles-leakage-audit`.

The applied shell contract is:

- `HOME=/home/<username>` for the POSIX view.
- `USERPROFILE=C:\msys64\home\<username>` for native Windows children.
- `APPDATA` and `LOCALAPPDATA` map to the XDG config and data directories.
- `TEMP` and `TMP` map to `C:\msys64\tmp`.
- The Windows login profile and Known Folders remain unchanged.

Managed bridges and user fonts remain host-owned. For the containment boundary,
tool-specific behavior, audit policy, exclusions, report format and CI coverage,
see [Windows Runtime Containment].

[Windows Runtime Containment]: ../reference/windows-runtime-containment.md
