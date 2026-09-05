# Windows Setup

This document describes the initial setup process for the Windows development
environment.

## 1. Enable Windows Developer Mode

Enable Windows Developer Mode:

```text
Settings
  -> System
  -> Advanced
  -> For developers
  -> Developer Mode
```

Developer Mode is required to create the symbolic links managed by this
repository.

## 2. Install MSYS2

Install MSYS2 to:

```text
C:\msys64
```

## 3. Start the UCRT64 Environment

Launch:

```text
C:\msys64\ucrt64.exe
```

## 4. Install Bootstrap Packages

Update MSYS2:

```sh
pacman -Syu
```

If MSYS2 asks you to close the terminal during the update, launch
`C:\msys64\ucrt64.exe` again and continue the update.

Install the required bootstrap packages:

```sh
pacman -S --needed \
    fish \
    unzip \
    mingw-w64-ucrt-x86_64-git
```

## 5. Start Fish

```sh
fish
```

## 6. Install chezmoi

Install chezmoi into the MSYS2 home:

```fish
mkdir -p "$HOME/.local/bin"

curl -fsLS https://get.chezmoi.io \
    | sh -s -- -b "$HOME/.local/bin"
```

Verify the installation:

```fish
"$HOME/.local/bin/chezmoi" --version
```

Use the full path during bootstrap because the repository-managed PATH
configuration has not been applied yet.

## 7. Install mise

Download the latest Windows x64 release archive from:

```text
https://github.com/jdx/mise/releases
```

Download:

```text
mise-v<version>-windows-x64.zip
```

Extract the archive and copy both executables:

```text
mise.exe
mise-shim.exe
```

into:

```text
/home/<username>/.local/bin/
```

Verify the installation:

```fish
"$HOME/.local/bin/mise.exe" --version
```

Keep `mise-shim.exe` alongside `mise.exe`.

## 8. Initialize the Dotfiles Repository

Initialize chezmoi from the dotfiles repository:

```fish
"$HOME/.local/bin/chezmoi" init <repository>
```

The repository's `.chezmoi.toml.tmpl` generates the local chezmoi
configuration during initialization.

Verify the destination:

```fish
"$HOME/.local/bin/chezmoi" target-path
```

Expected:

```text
C:/msys64/home/<username>
```

## 9. Apply the Configuration

Apply the repository configuration:

```fish
"$HOME/.local/bin/chezmoi" apply
```

Existing conflicting Windows files or directories are not migrated or
overwritten automatically.

## 10. Install WezTerm Nightly

Install the Windows native WezTerm Nightly build from:

```text
https://wezterm.org/install/windows.html
```

Use the Nightly Windows build.

The WezTerm configuration is managed by this repository.

## 11. Start WezTerm

Close the bootstrap terminal and start WezTerm.

The managed WezTerm configuration starts the MSYS2 development environment
with Fish.

After startup, `chezmoi` and `mise` should be available directly from the
managed PATH.