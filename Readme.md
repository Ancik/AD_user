# 🛠️ Active Directory User Provisioning Script

A PowerShell script to automate bulk user creation in Active Directory from CSV files.  

Originally designed as a coding exercise, later expanded to cover **real-world AD limitations and pitfalls**.
This script reads user data from users.csv (containing FirstName, LastName, and DepartmentID) and OU mappings from depts.csv (with DepartmentID and DepartmentOU). It generates ASCII-only usernames (first initial + last name, lowercase), ensures they fit AD's 20-character limit, handles duplicates with numeric suffixes (-01 to -99), and creates users in the correct Organizational Units (OUs). The script includes comprehensive logging, input validation, and an option to use encrypted random passwords for added security.

Perfect for sysadmins looking to streamline user provisioning while avoiding common pitfalls like invalid data or missing OUs!


## ✨ Features
- Import users from `users.csv` (`FirstName,LastName,DepartmentID`)
- Import department-to-OU mappings from `depts.csv` (`DepartmentID;DepartmentOU`)
- Generate usernames:
  - first initial + last name  
  - ASCII-only (diacritics removed)  
  - lowercase  
  - max **20 chars** with `-01…-99` suffixes for uniqueness
- Validate before creating:
  - skip rows with missing or invalid input  
  - check if OU exists in AD  
  - detect duplicates in AD by `sAMAccountName` or `UPN`
- Password management:
  - default fixed password: **`Password!1`** (per assignment spec)  
  - optional random passwords with encrypted log output
- Structured logging:
  - `[Info]`, `[Warning]`, `[Error]`, `[DuplicateUserInAD]`, `[MissingOU]`  
  - error messages trimmed to max 200 chars for readability
- Safety cap: processes up to **100 users per run**

## 📂 Input Files
**users.csv**
```csv
FirstName,LastName,DepartmentID
Alice,Nowak,FIN101
Bob,Kowalski,IT105
```

**depts.csv**
```csv
DepartmentID;DepartmentOU
IT105;OU=IT,DC=example,DC=local
FIN101;OU=Finance,DC=example,DC=local
```

## 🚀 Usage
```powershell
# Basic run (fixed password 'Password!1')
.\New-AdUsers.ps1 `
  -UsersCsv .\users.csv `
  -DeptsCsv .\depts.csv `
  -UpnSuffix "@example.local" `
  -MailDomain "example.com"

# With random passwords and encrypted log
$key = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 } | ForEach-Object {[byte]$_}))
.\New-AdUsers.ps1 `
  -UsersCsv .\users.csv `
  -DeptsCsv .\depts.csv `
  -UpnSuffix "@example.local" `
  -MailDomain "example.com" `
  -UseRandomPassword `
  -PasswordLogKeyBase64 $key
```

## 📜 Example Log Output
```
[2025-09-08 11:23:45] Info User created User=jdoe UPN=jdoe@example.local Dept=IT105 Display=John Doe
[2025-09-08 11:23:45] DuplicateUserInAD User already exists, skipping User=asmith UPN=asmith@example.local Dept=FIN101 Display=Alice Smith
[2025-09-08 11:23:45] MissingOU No OU mapping for department, skipping User=bbrown UPN=bbrown@example.local Dept=HR999 Display=Bob Brown
```

## ✅ Why this version?
During analysis of the original exercise, I noticed some **real-world gaps**:
- AD username length limit (20 chars) → handled with truncation and suffixes  
- messy or incomplete input data → validated and logged, not causing crashes  
- OU references that don’t exist in AD → validated before creation  
- overly verbose AD errors → trimmed and categorized  
- insecure plain-text password logs → optional encrypted logs  

These improvements weren’t part of the original task, but make the script **robust, predictable, and production-ready**.

## ⚠️ Requirements
- Windows Server with **RSAT Active Directory module**  
- Permissions to create users in the target OUs  
- PowerShell 5.1+  

## 👤 Author

Created by [Volodymyr Lisovyi](https://www.linkedin.com/in/volodymyr-lisovyi-66447649/)


## 📜 License
MIT — free to use and adapt
