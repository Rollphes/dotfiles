# Windows Runtime Containment

This document defines the Windows and MSYS2 runtime boundary, including the
filesystem audit used for STG5 leakage closure. For installation steps, see
[Windows Setup].

[Windows Setup]: ../setup/windows.md

## Environment Contract

MSYS2 development shells and their native Windows children use the same home
directory through different path representations.

| Variable | Value |
| --- | --- |
| `HOME` | `/home/<username>` |
| `USERPROFILE` | `C:\msys64\home\<username>` |
| `XDG_CONFIG_HOME` / `APPDATA` | `C:\msys64\home\<username>\.config` |
| `XDG_DATA_HOME` / `LOCALAPPDATA` | `C:\msys64\home\<username>\.local\share` |
| `XDG_STATE_HOME` | `C:\msys64\home\<username>\.local\state` |
| `XDG_CACHE_HOME` | `C:\msys64\home\<username>\.cache` |
| `TEMP` / `TMP` | `C:\msys64\tmp` |

The development profile has no `AppData` storage authority. Two managed file
links may exist below its otherwise retired `AppData` path. Every other entry
there remains forbidden.

This contract is process-local. It does not change the Windows account,
registry, Known Folders or environment stored by Windows.

## Host Operations and Bridges

Windows GUI applications continue to use the registered login profile. Managed
bridges connect that profile to selected files below the canonical home. Their
meaning does not change when a development shell virtualizes `USERPROFILE`.

Font and bridge scripts launch host-scoped PowerShell children when they must
operate on host resources. Those children receive the registered host profile
and AppData paths. Their temp directory remains `C:\msys64\tmp`. The bridge
reconciler creates canonical `AppData` containers only for the two reverse link
endpoints described below.

Managed user fonts remain in the registered host Local AppData directory.
Existing runtime data is neither migrated nor deleted.

PowerShell on Windows derives its startup directory from the Windows
`LocalApplicationData` Known Folder even when process `LOCALAPPDATA` points to
XDG data. Two reverse bridges contain those writes without changing Windows:

```text
C:\msys64\home\<username>\AppData\Local\Microsoft\PowerShell\StartupProfileData-NonInteractive
  -> <host Local AppData>\Microsoft\PowerShell\StartupProfileData-NonInteractive

C:\msys64\home\<username>\AppData\Local\Microsoft\PowerShell\telemetry.uuid
  -> <host Local AppData>\Microsoft\PowerShell\telemetry.uuid
```

Only these file endpoints are reversed. The bridge reconciler does not replace
an existing canonical file or directory; it reports a topology conflict for
manual resolution.

## Tool Behavior

| Tool | Windows containment behavior |
| --- | --- |
| mise | Config, data, state, cache and temp directories are explicit canonical paths. |
| Go | Uses `go`, `go\pkg\mod` and `.config\go\env`; `GOCACHE` uses `.cache\go-build`. |
| npm | Cache uses `.cache\npm`. |
| tree-sitter | Parser data follows `LOCALAPPDATA` into `.local\share\tree-sitter`. |
| Starship | Config uses `.config\starship.toml`; cache uses `.cache\starship`. |
| Atuin | Not installed or activated on Windows because its Known Folder lookup bypasses the process-local profile contract. |

On Windows, mise disables aqua GitHub artifact attestation because its
sigstore-rust dependency resolves the TUF cache through Windows Known Folders.
Aqua checksum, SLSA, Cosign and Minisign verification remain enabled.

The repository exports `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `MISE_STATE_DIR`,
`MISE_CACHE_DIR` and `MISE_TMP_DIR` as ordinary process variables. It does not
persist them as Fish universal variables. Inspect machine-local values without
changing them with:

```fish
set --show MISE_CONFIG_DIR MISE_DATA_DIR MISE_STATE_DIR MISE_CACHE_DIR MISE_TMP_DIR
```

## Leakage Audit

Start and stop the audit around a focused command or interactive session:

```fish
audit start
# Run the commands being examined.
audit stop
audit report
```

The audit stores snapshots and reports below
`$XDG_STATE_HOME/dotfiles-leakage-audit`. It has no background process.

Interactive runs resolve the registered host profile and host temp directory at
start. CI captures those paths before virtualizing the development environment.
The saved paths remain authoritative for stop and report.

Use `-WorkspaceRoots` when the intended command target lies inside a monitored
host root. Each entry must be an exact workspace; an exclusion that hides an
entire monitored root is rejected.

### Monitored Roots

The audit takes before and after snapshots of:

- the registered Windows profile;
- host Local and Roaming AppData;
- host Windows temp;
- the retired `AppData` path below the canonical home.

It records ordinary directories such as `go` and rejects traversal through
reparse points. Any `.ssh` path component is rejected before the audit queries
the entry or its metadata.

### Exclusions and Allowed Host Assets

Exclusions have narrow, documented purposes:

| Category | Paths |
| --- | --- |
| Managed bridges | Exact link and target endpoints, including the two reverse PowerShell links, plus their container metadata |
| Audit state | The active audit's own files |
| Workspace | Explicit `-WorkspaceRoots` entries |
| Windows registry state | Observed `NTUSER.DAT` hive files and `Microsoft\Windows\UsrClass.dat.LOG1` |
| Windows OS state | Host temp `WinSAT` and the exact Windows PowerShell startup-cache path |
| GitHub-hosted runner state | `Microsoft\Windows\WebCache` and `AppData\LocalLow\Microsoft\CryptnetUrlCache` |

The Windows PowerShell startup-cache exclusion below host Local AppData is:

```text
Microsoft\Windows\PowerShell\StartupProfileData-NonInteractive
```

PowerShell 7 startup data under `Microsoft\PowerShell` is classified through
the reverse bridge endpoints instead of the OS-state exclusion.

Runner exclusions apply only when both `GITHUB_ACTIONS=true` and
`RUNNER_ENVIRONMENT=github-hosted`. Adjacent paths remain monitored.

Manifest-selected font files and their directory containers are classified as
managed host assets. They are reported separately from exclusions, and font
verification checks their filenames, families and registration.

### Policy

`policy.json` connects snapshot detection directly to the CI result.

| Change | Result |
| --- | --- |
| `new` | Failure unless it is an allowed managed host asset |
| `modified` | Failure unless it is an allowed managed host asset |
| `metadataOnly` | Failure unless it is an allowed managed host asset |
| `deleted` | Informational; a surviving parent metadata change still counts as a write |
| Snapshot error | Coverage failure |

The text report prints each forbidden entry with its status and monitored root:

```text
POLICY VIOLATIONS:
  METADATAONLY [local]: Microsoft/example.state
POLICY: fail (1 forbidden writes)
```

A passing report prints `None` below `POLICY VIOLATIONS:`. Complete structured
results remain in `policy.json` and `diff/*.json`.

### Coverage Limits

The audit compares names, types, sizes, link targets and write times. Use
`audit start -HashFiles` to compare file contents as well. Hashing is more
expensive on populated profiles. Without it, a same-size change whose timestamp
is restored cannot be detected.

This is a filesystem before-and-after audit. It cannot observe temporary files
removed before stop, unrelated volumes or the process responsible for a write.
Keep the audit window focused when investigating a new violation.

## GitHub Actions

Windows CI audits both the first apply and the idempotency apply. Artifacts are
uploaded even when policy enforcement fails. Runtime probes cover native child
environment resolution without reinstalling every tool or loading user Neovim
configuration.

The Windows CI toolset excludes Go and the `go:*` backend. The runtime probe
checks that exclusion and skips only the Go and gopls workload; remaining
containment probes still run.
