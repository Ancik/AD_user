\# Active Directory User Provisioning Script

This project is a PowerShell script that automates the creation of Active Directory accounts from CSV input.
It was originally based on a simple assignment, but I expanded it to handle real-world issues like:

cleaning up “messy” input data (empty names, special characters, long surnames)

generating usernames that always fit AD’s 20-character limit, with suffixes for duplicates

checking if an OU actually exists in AD before trying to place a user there

trimming overly verbose AD error messages into readable logs

supporting both fixed passwords (per assignment spec) and optional random passwords with encrypted logging

The script is designed to be safe, predictable, and auditable. All operations are logged with clear levels (Info, Warning, Error, DuplicateUserInAD, etc.) so you can run it in production and trust the output.

It handles real-world edge cases like invalid data, duplicate usernames, OU validation, and AD limits — making it safer for production use.
---

\## ✨ Features

\- Import users from `users.csv` (FirstName, LastName, DepartmentID).

\- Import OU mappings from `depts.csv` (`DepartmentID;DepartmentOU`).

\- Generate usernames:

&nbsp; - first initial + last name

&nbsp; - ASCII-only (diacritics removed)

&nbsp; - lowercase

&nbsp; - max 20 chars (with `-01`, `-02` suffix if needed).

\- Validate:

&nbsp; - skip users with missing/invalid input

&nbsp; - check for duplicates in AD (by `sAMAccountName` and `UPN`)

&nbsp; - confirm OU exists in AD before creating.

\- Passwords:

&nbsp; - Default fixed password: `Password!1` (per assignment spec).

&nbsp; - Optional random password mode with \*\*encrypted password log\*\*.

\- Logging:

&nbsp; - Structured logs with timestamp + level (`Info`, `Warning`, `Error`, `DuplicateUserInAD`, `MissingOU`, etc.)

&nbsp; - Trimmed error messages (≤200 chars) for readability.

\- Safety limit: process up to 100 users per run (`-MaxUsers`).



