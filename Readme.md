# 🛠️ Active Directory User Provisioning Script
AD User Creation Script

A robust PowerShell script to automate the creation of Active Directory (AD) users from CSV files, with enhanced validation, logging, and security features.

Overview

This script reads user data from users.csv (containing FirstName, LastName, and DepartmentID) and OU mappings from depts.csv (with DepartmentID and DepartmentOU). It generates ASCII-only usernames (first initial + last name, lowercase), ensures they fit AD's 20-character limit, handles duplicates with numeric suffixes (-01 to -99), and creates users in the correct Organizational Units (OUs). The script includes comprehensive logging, input validation, and an option to use encrypted random passwords for added security.

Perfect for sysadmins looking to streamline user provisioning while avoiding common pitfalls like invalid data or missing OUs!

## ✨ Features
- Input Validation: Skips rows with missing or invalid FirstName, LastName, or DepartmentID.
- Username Management: Truncates names to 20 characters and adds suffixes for uniqueness.
- OU Verification: Checks if the target OU exists in AD before creating users.
- Logging: Detailed logs with timestamps, levels (Info, Warning, Error, etc.), and context.
- Password Options: Uses a fixed password ("Password!1") by default, with an optional encrypted random password feature.
- Security: Encrypts random passwords in a log file using a user-provided key.
- Safety Cap: Limits processing to 100 users per run to prevent overload.

Installation

1. Ensure you have the Active Directory module installed (part of RSAT on Windows).
   - Install RSAT via Settings > Apps > Optional Features, or run Install-WindowsFeature RSAT-AD-PowerShell on a server.
2. Clone or download this repository:
   git clone https://github.com/yourusername/ad-user-creation.git
3. Place your users.csv and depts.csv files in the script directory (see Usage for format).

⚠️ Requirements

Windows Server with RSAT Active Directory module

Permissions to create users in the target OUs

PowerShell 5.1+

## 📂 Input Files

CSV File Format
- users.csv:
  FirstName,LastName,DepartmentID
  Alice,Kowalski,IT101
  Bob,Kowalski,IT105
- depts.csv:
  DepartmentID;DepartmentOU
  IT101;OU=IT,DC=example,DC=local
  IT105;OU=Finance,DC=example,DC=local

🚀 Usage

Running the Script
1. Open PowerShell with administrative privileges.
2. Run the script with required parameters:
   .\New-AdUsers.ps1 -UsersCsv .\users.csv -DeptsCsv .\depts.csv -UpnSuffix "@example.local" -MailDomain "example.com"
3. For random passwords with encryption (optional):
   - Generate a 32-byte key (e.g., $key = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))).
   - Run with additional parameters:
     .\New-AdUsers.ps1 -UsersCsv .\users.csv -DeptsCsv .\depts.csv -UpnSuffix "@example.local" -MailDomain "example.com" -UseRandomPassword -PasswordLogKeyBase64 $key

Parameter Reference
-UsersCsv: Path to the user data file.
-DeptsCsv: Path to the department-to-OU mapping file.
-UpnSuffix: The UPN suffix for user accounts (e.g., @example.local).
-MailDomain: The mail domain for user accounts (e.g., example.com).
-MaxUsers: A safety limit on the number of users to process (default: 100).
-UseRandomPassword: A switch to enable the use of random passwords.
-FixedPassword: The fixed password used when -UseRandomPassword is not set.
-PasswordLogPath: File path for the encrypted password log (only used with -UseRandomPassword).
-PasswordLogKeyBase64: A Base64-encoded key required to encrypt the password log.  

📜 Example Log Output
- Logs are written to the console with timestamps and levels.
- Encrypted password logs (if enabled) are saved to passwords.log.enc.
[2025-09-08 11:23:45] Info User created User=jdoe UPN=jdoe@example.local Dept=IT105 Display=John Doe
[2025-09-08 11:23:45] DuplicateUserInAD User already exists, skipping User=asmith UPN=asmith@example.local Dept=FIN101 Display=Alice Smith
[2025-09-08 11:23:45] MissingOU No OU mapping for department, skipping User=bbrown UPN=bbrown@example.local Dept=HR999 Display=Bob Brown


✅ Why this version?

During analysis of the original exercise, I noticed some real-world gaps:

AD username length limit (20 chars) → handled with truncation and suffixes

messy or incomplete input data → validated and logged, not causing crashes

OU references that don’t exist in AD → validated before creation

overly verbose AD errors → trimmed and categorized

insecure plain-text password logs → optional encrypted logs

These improvements weren’t part of the original task, but make the script robust, predictable, and production-ready.

Contributing

We welcome contributions to make this script even better! To contribute:
1. Fork the repository.
2. Create a feature branch (git checkout -b feature/new-feature).
3. Commit your changes (git commit -m "Add new feature").
4. Push to the branch (git push origin feature/new-feature).
5. Open a Pull Request with a description of your changes.

Please ensure your code follows PowerShell best practices and includes tests for edge cases (e.g., long names, special characters, missing OUs).

Testing

- Test with large datasets (>100 users) to verify the safety cap.
- Try names with special characters (e.g., Ł, Ø) to check ASCII normalization.
- Use duplicate entries to confirm deduplication logic.
- Simulate missing OUs to ensure proper logging.

## 👤 Author

Created by [Volodymyr Lisovyi](https://www.linkedin.com/in/volodymyr-lisovyi-66447649/)


📜 License

MIT License - Feel free to use, modify, and distribute this script, but please include the original copyright notice.

Acknowledgments

Inspired by real-world AD admin challenges and built with love for automation! Special thanks to the PowerShell community for their invaluable resources.

Created on: 02:22 PM CEST, Monday, September 08, 2025
