# Linux Setup

> Status: Not implemented yet.

This document will describe the Linux bootstrap process once the platform
configuration has been implemented and verified.

The Linux setup should use the native Unix environment directly and must not
inherit Windows-specific bootstrap mechanisms such as:

- MSYS2
- Windows Developer Mode
- cross-home Windows symbolic links
- Windows environment-variable quarantine
- `C:/msys64` paths

Do not treat the Windows setup as the Linux bootstrap procedure.