# PowerShell Script for Automated Active Directory User Provisioning

This robust PowerShell script automates the process of creating new user accounts in Active Directory. It reads user and department information from CSV files, generates unique usernames, handles potential conflicts, and places users in the correct Organizational Units (OUs).

---

### **Key Features**

* **Flexible Input**: Reads user data from a `users.csv` file and department-to-OU mappings from a `depts.csv` file.
* **Intelligent Username Generation**:
    * Generates `sAMAccountName` and `UserPrincipalName` (UPN) based on a consistent policy (first initial + last name).
    * Automatically **normalizes names to ASCII** to ensure compatibility with Active Directory.
    * Handles long names by **truncating `sAMAccountName` to 20 characters**, a standard AD limit.
    * **Deduplicates usernames** by adding a numeric suffix (e.g., `jdoe-01`) if a conflict is found, ensuring every account is unique.
* **Robust Validation and Error Handling**:
    * **Validates input data** from the CSV files, skipping any rows with missing or invalid information.
    * **Verifies that OUs exist in Active Directory** before attempting to create a user in them.
    * Includes comprehensive `try...catch` blocks to gracefully handle and log any errors during the process.
* **Enhanced Security**:
    * By default, assigns a fixed password and requires a change at first logon.
    * Includes an option to use **cryptographically-secure random passwords**.
    * Provides an **encrypted logging** mechanism for random passwords, ensuring sensitive data is not stored in plaintext.
* **Detailed Logging**: All actions, including user creation, skipped entries, warnings, and errors, are logged with timestamps and clear contextual information, making it easy to audit the script's run.

---

### **How to Use**

#### **1. Prerequisites**

* PowerShell 5.1 or later.
* The **Active Directory PowerShell Module** (part of RSAT).

#### **2. Input Files**

Create two CSV files in the same directory as the script:

**`users.csv`**
```csv
FirstName,LastName,DepartmentID
John,Doe,101
Jane,Smith,102
depts.csv (Semicolon-delimited)

DepartmentID;DepartmentOU
101;OU=Sales,OU=Users,DC=example,DC=com
102;OU=Marketing,OU=Users,DC=example,DC=com
3. Running the Script
Run the script from an elevated PowerShell console.

#### **3. Basic Usage (with fixed password)

PowerShell

.\New-AdUsers.ps1 -UsersCsv .\users.csv -DeptsCsv .\depts.csv -UpnSuffix "@example.local" -MailDomain "example.com"
Advanced Usage (with random, encrypted passwords)

PowerShell

# Generate a secure key (should be done once and stored in a secure vault)
$key = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 } | ForEach-Object {[byte]$_}))

# Run the script with random passwords and the secure key
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
