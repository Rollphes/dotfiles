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

The development process tree uses POSIX `HOME=/home/<username>` and native
`USERPROFILE=C:\msys64\home\<username>`. Native `APPDATA` maps directly to
`XDG_CONFIG_HOME` (`USERPROFILE\.config`) and `LOCALAPPDATA` maps to
`XDG_DATA_HOME` (`USERPROFILE\.local\share`); no development `AppData` tree is
part of the contract. `TEMP` and `TMP` resolve to `C:\msys64\tmp`. Fish exports
profile paths in native form explicitly.
Apply scripts use the chezmoi destination as HOME, and the mise subprocess also
converts XDG and tool-specific variables before starting native descendants.
WezTerm's native development shells use the same profile authority.

This is process-local. Windows login settings, Known Folders and the host GUI
profile remain unchanged. Managed bridges still originate in the registered
Windows login profile. Their profile resolver and the font installer scope the
registered host `HOME`, `USERPROFILE`, `APPDATA` and `LOCALAPPDATA` to their
PowerShell children. This prevents Windows profile initialization from creating
`AppData` below the development home. Managed user fonts remain in the
registered host Local AppData folder. `TEMP` and `TMP` remain the canonical
MSYS2 temp during host operations. No runtime data is migrated or deleted by
this change.

The current MSYS2 Atuin package calls Windows Known Folders through its Rust
`directories` dependency and cannot initialize under the virtualized development
profile. Windows therefore does not install or activate Atuin. An already
installed package is left untouched; Fish does not invoke it on Windows.

On Windows, mise's aqua GitHub artifact-attestation check is disabled. Its
sigstore-rust dependency resolves the TUF cache through Windows Known Folders,
which remain host-owned and cannot follow process-local USERPROFILE without a
host write. Aqua checksum, SLSA, Cosign and Minisign verification stay enabled.

The audit is part of **STG5 leakage closure**. It records the real host profile
independently of virtualized USERPROFILE; CI captures the original profile and
temp once in CI-only variables. Interactive audit defaults to the registered
login profile and its `AppData\Local\Temp`; supply `-HostProfile` and `-HostTemp`
at `start` if the host uses another location. Stop/report reuse saved authority.
For a command whose intended project lies inside a monitored host root, pass
that exact project path with `-WorkspaceRoots` at start. No workspace is guessed
or globally exported; a path hiding an entire monitored root is rejected.

Snapshots recursively monitor the host profile, Local/Roaming AppData, host
temp, and the retired `AppData` root below the canonical development home,
including ordinary directory names such as `go`. They never descend into
reparse points. When parent enumeration yields a `.ssh` entry, the audit rejects
it before querying that entry or traversing inside it; it does not inspect its
existence, metadata, contents or children. Managed bridges, their container
metadata, canonical home outside its forbidden `AppData` root, and audit state
are excluded. Locked Windows NTUSER
registry hive, journal and transaction filenames observed during validation are
separately recorded as OS exclusions, along with the observed inaccessible host
Temp `WinSAT` directory. The exact host Local AppData file
`Microsoft\Windows\PowerShell\StartupProfileData-NonInteractive` is also
excluded because the managed font and bridge operations launch host-scoped
PowerShell children that update it. Its counterpart below canonical `AppData`
remains forbidden. On a GitHub-hosted runner only, the two OS cache roots
observed in run `34536176054` are also excluded:
`Microsoft\Windows\WebCache` below host Local AppData and
`AppData\LocalLow\Microsoft\CryptnetUrlCache` below the host profile. The
exclusions do not apply to self-hosted runners or adjacent paths. There is no
development-tool or runner-wide allowlist.
Manifest-managed font filenames and their directory containers are classified as
managed host assets; the font verification checks their contents and registration.

`policy.json` connects detection to enforcement: `new`, `modified` and
`metadataOnly` forbidden entries fail `audit stop` and the CI verifier. `deleted`
alone is informational; a surviving parent timestamp change still counts as a
write. A snapshot error is a coverage failure, never PASS. Reports show counts,
a bounded preview and the policy decision. This is a before/after filesystem
audit, not a process tracer: temporary writes removed before stop, arbitrary
unmonitored volumes and unrelated host application activity require separate
investigation. Keep the audit window focused; do not suppress unknown churn with
a broad allowlist.
By default snapshots compare names, types, sizes, link targets and write times.
`audit start -HashFiles` additionally hashes file contents (potentially expensive
on a populated host profile). Without hashing, same-size changes with restored
timestamps are outside detection coverage.
Reports show at most 50 entries per status; full CSV/JSON evidence remains in the
session directory and is uploaded as a Windows CI artifact even on failure.

Go keeps the platform-neutral defaults `go`, `go\pkg\mod`, and `.config\go\env`;
`GOCACHE` is fixed to `.cache\go-build`. npm cache is fixed to `.cache\npm`, while
tree-sitter parser data follows `LOCALAPPDATA` into `.local\share\tree-sitter`.
Starship config and cache are fixed to `.config\starship.toml` and
`.cache\starship`; this also overrides any inherited host-profile
`STARSHIP_CACHE` before non-interactive Fish integration generation.
Runtime probes in `.github/scripts/probe-windows-runtime.ps1`
exercise the native child environment without reinstalling tools or loading user
Neovim configuration. GitHub Actions excludes Go and the `go:*` backend from the
rendered mise toolset; its runtime probe checks that exclusion and skips only the
Go/gopls workload while continuing the other containment probes.

MISE variables in this repository use `export` / Fish `set -gx`, not universal
variables. To inspect a suspected machine-local universal value without changing
it, run `set --show MISE_CONFIG_DIR MISE_DATA_DIR MISE_STATE_DIR MISE_CACHE_DIR
MISE_TMP_DIR` in Fish. No universal-variable deletion is part of this setup.
