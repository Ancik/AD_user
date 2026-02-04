# Changelog

## v1.1.0 - 2026-02-04
**Scope**: `AD_user/final.ps1`

**Added**
- PowerShell `-WhatIf` support via `SupportsShouldProcess` to enable safe simulation runs.
- Per-run summary statistics (created, skipped, errors, simulated) printed at the end.
- Counters for each outcome category to improve operational visibility.
- `ArgumentCompleter` for `PasswordLogFilePath` to improve path entry UX.

**Changed**
- `PasswordLogPath` renamed to `PasswordLogFilePath` with analyzer suppression for false-positive.
- `PasswordLogKeyBase64` now accepts `SecureString` and is decrypted in memory only when needed.
- `FixedPassword` now accepts `SecureString` and is required when random passwords are not used.
- `Ensure-UniqueSamUpn` renamed to `Get-UniqueSamUpn` (approved verb).

**Fixed**
- Removed unused OU variable assignment in OU existence check.
- Corrected string interpolation for `UsersCsv`/`DeptsCsv` error messages.
