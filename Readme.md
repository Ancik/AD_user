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



---



\## 📂 Input files

\### users.csv

Comma-delimited with header:

```csv

FirstName,LastName,DepartmentID

Alice,Nowak,FIN101

Bob,Kowalski,IT105



\### depts.csv



Semicolon-delimited with header:



DepartmentID;DepartmentOU

IT105;OU=IT,DC=example,DC=local

FIN101;OU=Finance,DC=example,DC=local



🔧 Usage

\# Basic run (fixed password 'Password!1')

.\\New-AdUsers.ps1 `

&nbsp; -UsersCsv .\\users.csv `

&nbsp; -DeptsCsv .\\depts.csv `

&nbsp; -UpnSuffix "@example.local" `

&nbsp; -MailDomain "example.com"



\# With random passwords and encrypted log

$key = \[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 } | ForEach-Object {\[byte]$\_}))

.\\New-AdUsers.ps1 `

&nbsp; -UsersCsv .\\users.csv `

&nbsp; -DeptsCsv .\\depts.csv `

&nbsp; -UpnSuffix "@example.local" `

&nbsp; -MailDomain "example.com" `

&nbsp; -UseRandomPassword `

&nbsp; -PasswordLogKeyBase64 $key



Log output



Logs are written to standard output, for example:



\[2025-09-08 11:23:45] Info User created User=jdoe UPN=jdoe@example.local Dept=IT105 Display=John Doe

\[2025-09-08 11:23:45] DuplicateUserInAD User already exists, skipping User=asmith UPN=asmith@example.local Dept=FIN101 Display=Alice Smith

\[2025-09-08 11:23:45] MissingOU No OU mapping for department, skipping User=bbrown UPN=bbrown@example.local Dept=HR999 Display=Bob Brown



✅ Why this version?



When analyzing the original assignment, I noticed some real-world gaps:



Username length \& duplicates → handled with truncation and suffixes.



Invalid input data → validated and logged instead of crashing.



OU existence → confirmed with AD query before creating users.



Verbose errors → trimmed and categorized.



Password logs → optionally encrypted, not plain text.



These weren’t in the spec, but they make the script practical and safe in production. Normally such points would be clarified during task scoping, but they’re worth adding for robustness.



⚠️ Requirements



Windows Server with RSAT Active Directory module installed.



Permission to create users in the target OUs.



PowerShell 5.1+ (or compatible on Windows Server).



📜 License



MIT — feel free to use and adapt.



