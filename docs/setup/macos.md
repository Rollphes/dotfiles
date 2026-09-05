# macOS Setup

> Status: Not implemented yet.

This document will describe the macOS bootstrap process once the platform
configuration has been implemented and verified.

The macOS setup must preserve the same repository-level principles where
applicable, while avoiding Windows-specific assumptions such as:

- MSYS2
- Windows Developer Mode
- Windows/MSYS2 cross-home bridges
- `APPDATA` / `LOCALAPPDATA` quarantine
- Windows-native shell interpreters

Do not treat the Windows setup as the macOS bootstrap procedure.
