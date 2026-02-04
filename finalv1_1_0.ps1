<#
.SYNOPSIS
  Create AD users from CSV with department-to-OU mapping (robust version).

.DESCRIPTION
  Reads users.csv (FirstName,LastName,DepartmentID) and depts.csv (DepartmentID;DepartmentOU),
  generates ASCII-only usernames (first initial + last name, lowercase), ensures SAM <= 20 chars,
  deduplicates with -01..-99 suffix if needed, validates OU existence, checks AD duplicates (SAM/UPN),
  creates users with fixed or random password, and logs everything with structured levels.
  If random passwords are enabled, they can be stored encrypted using a provided symmetric key.

.PARAMETER UsersCsv
  Path to users.csv (comma-delimited)

.PARAMETER DeptsCsv
  Path to depts.csv (semicolon-delimited; headers: DepartmentID;DepartmentOU)

.PARAMETER UpnSuffix
  UPN suffix, e.g. "@example.local" (if "example.local" is passed, '@' is added automatically)

.PARAMETER MailDomain
  Mail domain, e.g. "example.com"

.PARAMETER MaxUsers
  Safety cap per run (default 100)

.PARAMETER UseRandomPassword
  Use random passwords instead of fixed (default fixed).

.PARAMETER FixedPassword
  Fixed password used when -UseRandomPassword is NOT supplied. SecureString recommended.

.PARAMETER PasswordLogFilePath
  When -UseRandomPassword is set: file to store encrypted username/password pairs. Default: "passwords.log.enc"

.PARAMETER PasswordLogKeyBase64
  Base64-encoded 32-byte key for ConvertFrom-SecureString -Key (e.g. from a secure vault).
  Required to write encrypted password log when -UseRandomPassword is set. If omitted, passwords are NOT logged.

.EXAMPLE
  .\New-AdUsers.ps1 -UsersCsv .\users.csv -DeptsCsv .\depts.csv -UpnSuffix "@example.local" -MailDomain "example.com"

.EXAMPLE
  # With random passwords and encrypted password log:
  $key = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 } | ForEach-Object {[byte]$_}))
  .\New-AdUsers.ps1 -UsersCsv .\users.csv -DeptsCsv .\depts.csv -UpnSuffix "@example.local" -MailDomain "example.com" -UseRandomPassword -PasswordLogKeyBase64 $key -PasswordLogFilePath .\passwords.log.enc
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$UsersCsv,
  [Parameter(Mandatory)] [string]$DeptsCsv,
  [Parameter(Mandatory)] [string]$UpnSuffix,
  [Parameter(Mandatory)] [string]$MailDomain,
  [int]$MaxUsers = 100,
  [switch]$UseRandomPassword,
  [SecureString]$FixedPassword,
  [SuppressMessage('PSAvoidUsingPlainTextForPassword','PasswordLogFilePath',Justification='File path is not a secret; analyzer false-positive.')]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $pattern = if ([string]::IsNullOrWhiteSpace($wordToComplete)) { '*' } else { "$wordToComplete*" }
    Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_.FullName, $_.FullName, 'ParameterValue', $_.FullName)
    }
  })]
  [string]$PasswordLogFilePath = 'passwords.log.enc',
  [string]$PasswordLogKeyBase64
)

# --- Prereq ----------------------------------------------------------------
try {
  Import-Module ActiveDirectory -ErrorAction Stop
} catch {
  Write-Error ("ActiveDirectory module is required: {0}. Install RSAT or run 'Import-Module ActiveDirectory' manually." -f $_.Exception.Message)
  return
}

# --- Settings --------------------------------------------------------------
Set-StrictMode -Version Latest

# --- Helpers ---------------------------------------------------------------

function Write-Log {
  param(
    [ValidateSet('Info','Warning','Error','DuplicateUserInAD','MissingOU','InvalidInput','UsernameTruncated','UsernameDedup','ADQuery','ADCreate')]
    [string]$Level,
    [string]$Message,
    [hashtable]$Context
  )
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $msg = if ($Message.Length -gt 200) { $Message.Substring(0,200) } else { $Message }
  $ctx = if ($Context) { ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ' } else { '' }
  Write-Output "[${ts}] ${Level} ${msg} ${ctx}".Trim()
}

function Convert-ToAscii {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  $norm = $Text.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder
  foreach ($c in $norm.ToCharArray()) {
    $uc = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
    if ($uc -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
  }
  $str = $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
  $bytes = [Text.Encoding]::ASCII.GetBytes($str)
  $ascii = [Text.Encoding]::ASCII.GetString($bytes)
  return ($ascii -replace '[^A-Za-z0-9]', '')
}

function New-Username {
  param([string]$FirstName, [string]$LastName)
  $fi = Convert-ToAscii ($FirstName.Substring(0,1))
  $ln = Convert-ToAscii $LastName
  return ($fi + $ln).ToLowerInvariant()
}

function New-RandomPassword {
  # Guaranteed at least one of each class, length 12
  $lower = 'abcdefghijklmnopqrstuvwxyz'
  $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $digit = '0123456789'
  $sym   = '!@#$%^&*()_+-=[]{}|;:,.<>?'
  $rest  = ($lower + $upper + $digit + $sym)

  $chars = @()
  $chars += $lower[(Get-Random -Maximum $lower.Length)]
  $chars += $upper[(Get-Random -Maximum $upper.Length)]
  $chars += $digit[(Get-Random -Maximum $digit.Length)]
  $chars += $sym[(Get-Random -Maximum $sym.Length)]
  $needed = 12 - $chars.Count
  $chars += (1..$needed | ForEach-Object { $rest[(Get-Random -Maximum $rest.Length)] })
  -join ($chars | Sort-Object { Get-Random })
}

function Ensure-UniqueSamUpn {
  <#
    .SYNOPSIS
      Returns a (SamAccountName, Upn) tuple that is unique in AD.
    .DESCRIPTION
      - Truncates SAM to <= 20 chars.
      - If taken, appends '-01'..'-99' (also keeping <= 20 chars).
      - Checks both sAMAccountName and UPN (username + UpnSuffix) for conflicts.
  #>
  param(
    [Parameter(Mandatory)] [string]$BaseSam,
    [Parameter(Mandatory)] [string]$UpnSuffix,  # must start with '@' (weâ€™ll normalize)
    [switch]$LogTruncate,
    [switch]$LogDedup
  )

  $suffix = if ($UpnSuffix.StartsWith('@')) { $UpnSuffix } else { "@$UpnSuffix" }
  $sam = $BaseSam
  if ($sam.Length -gt 20) {
    $original = $sam
    $sam = $sam.Substring(0,20)
    if ($LogTruncate) { Write-Log -Level 'UsernameTruncated' -Message "sAMAccountName truncated to 20 chars" -Context @{ Original=$original; Truncated=$sam } }
  }

  for ($i = 0; $i -lt 100; $i++) {
    $candidate = if ($i -eq 0) {
      $sam
    } else {
      # reserve 3 chars for "-NN"
      $coreLen = 20 - 3
      if ($coreLen -lt 1) { $coreLen = 1 }
      ($sam.Substring(0,[Math]::Min($sam.Length,$coreLen))) + ('-{0:00}' -f $i)
    }

    $upn = "$candidate$suffix"

    try {
      $exists = Get-ADUser -LDAPFilter "(|(sAMAccountName=$candidate)(userPrincipalName=$upn))" -ErrorAction Stop
    } catch {
      $ctxErr = @{ Sam=$candidate; UPN=$upn; Reason=$_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)) }
      Write-Log -Level 'ADQuery' -Message "AD query failed during uniqueness check" -Context $ctxErr
      # On query failure, be conservative and try next candidate
      continue
    }

    if (-not $exists) {
      if ($i -gt 0 -and $LogDedup) {
        Write-Log -Level 'UsernameDedup' -Message "SAM deduplicated with numeric suffix" -Context @{ Final=$candidate }
      }
      return @($candidate, $upn)
    }
  }

  throw "Unable to find unique sAMAccountName within 100 attempts for base '$sam'."
}

# --- Load data -------------------------------------------------------------

try {
  $users = Import-Csv -Path $UsersCsv
} catch {
  Write-Error "Failed to read ${UsersCsv}: $($_.Exception.Message)"; return
}

try {
  $deptMap = @{}
  Import-Csv -Path $DeptsCsv -Delimiter ';' | ForEach-Object {
    $deptMap[$_.DepartmentID.Trim()] = $_.DepartmentOU.Trim()
  }
} catch {
  Write-Error "Failed to read ${DeptsCsv}: $($_.Exception.Message)"; return
}

if ($users.Count -gt $MaxUsers) {
  Write-Log -Level 'Warning' -Message "Input exceeds MaxUsers cap; truncating" -Context @{ Count=$users.Count; Max=$MaxUsers }
  $users = $users | Select-Object -First $MaxUsers
}

# Password log setup (encrypted) if random passwords requested
[byte[]]$PasswordKey = $null
if ($UseRandomPassword) {
  if ($PasswordLogKeyBase64) {
    try {
      $PasswordKey = [Convert]::FromBase64String($PasswordLogKeyBase64)
      if ($PasswordKey.Length -ne 32) {
        Write-Log -Level 'Warning' -Message "PasswordLogKeyBase64 must decode to 32 bytes; password log will be disabled" -Context @{ Length=$PasswordKey.Length }
        $PasswordKey = $null
      } else {
        "Username,Password_Protected" | Out-File -FilePath $PasswordLogFilePath -Encoding utf8
        Write-Log -Level 'Warning' -Message "Random passwords enabled; encrypted password log active" -Context @{ Path=$PasswordLogFilePath }
      }
    } catch {
      Write-Log -Level 'Warning' -Message "Invalid PasswordLogKeyBase64; password log will be disabled" -Context @{ Reason=$_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)) }
    }
  } else {
    Write-Log -Level 'Warning' -Message "Random passwords enabled but no key provided; passwords will NOT be logged" -Context @{}
  }
}

# --- Main loop -------------------------------------------------------------

foreach ($u in $users) {
  # Normalize & validate input
  $first = ($u.FirstName).ToString().Trim()
  $last  = ($u.LastName).ToString().Trim()
  $dept  = ($u.DepartmentID).ToString().Trim()

  if ([string]::IsNullOrWhiteSpace($first) -or [string]::IsNullOrWhiteSpace($last)) {
    Write-Log -Level 'InvalidInput' -Message "Missing FirstName/LastName, skipping row" -Context @{ Row = ($u | ConvertTo-Json -Compress) }
    continue
  }
  if ([string]::IsNullOrWhiteSpace($dept)) {
    Write-Log -Level 'InvalidInput' -Message "Missing DepartmentID, skipping user" -Context @{ First=$first; Last=$last }
    continue
  }

  # Base username
  $baseUser = New-Username -FirstName $first -LastName $last
  if ([string]::IsNullOrWhiteSpace($baseUser)) {
    Write-Log -Level 'InvalidInput' -Message "Username collapsed to empty after ASCII normalization, skipping" -Context @{ First=$first; Last=$last }
    continue
  }

  # Normalize UPN suffix
  $suffix = if ($UpnSuffix.StartsWith('@')) { $UpnSuffix } else { "@$UpnSuffix" }

  # Ensure SAM/UPN uniqueness (with truncation + numeric suffix)
  try {
    $result = Ensure-UniqueSamUpn -BaseSam $baseUser -UpnSuffix $suffix -LogTruncate -LogDedup
  } catch {
    Write-Log -Level 'ADQuery' -Message "Failed to ensure unique SAM/UPN" -Context @{ Base=$baseUser; Reason=$_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)) }
    continue
  }

  $username = $result[0]
  $upn      = $result[1]
  $mail     = "${username}@${MailDomain}"
  $display  = "$first $last"
  $ctx = @{ User=$username; UPN=$upn; Dept=$dept; Display=$display }

  # OU mapping present?
  if (-not $deptMap.ContainsKey($dept) -or [string]::IsNullOrWhiteSpace($deptMap[$dept])) {
    Write-Log -Level 'MissingOU' -Message "No OU mapping for department, skipping" -Context $ctx
    continue
  }
  $ouPath = $deptMap[$dept]

  # Verify OU exists in AD
  try {
    $ouObj = Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop
  } catch {
    $ctxErr = $ctx.Clone()
    $ctxErr['OU'] = $ouPath
    $ctxErr['Reason'] = $_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length))
    Write-Log -Level 'MissingOU' -Message "OU does not exist in AD, skipping" -Context $ctxErr
    continue
  }

  # Password selection (+ optional encrypted logging)
  if ($UseRandomPassword) {
    $passwordPlain = New-RandomPassword
    $secure = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
    if ($PasswordKey) {
      try {
        $protected = $secure | ConvertFrom-SecureString -Key $PasswordKey
        "$username,$protected" | Out-File -FilePath $PasswordLogFilePath -Append -Encoding utf8
      } catch {
        Write-Log -Level 'Warning' -Message "Failed to write encrypted password log" -Context @{ User=$username; Reason=$_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)) }
      }
    }
    $password = $secure
  } else {
    if (-not $FixedPassword) {
      Write-Log -Level 'Error' -Message "FixedPassword is required when UseRandomPassword is not set" -Context @{ User=$username }
      continue
    }
    $password = $FixedPassword
  }

  # Final safety check: duplicate (SAM/UPN) right before create
  try {
    $existing = Get-ADUser -LDAPFilter "(|(sAMAccountName=$username)(userPrincipalName=$upn))" -ErrorAction Stop
  } catch {
    $ctxErr = $ctx.Clone(); $ctxErr['Reason'] = $_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length))
    Write-Log -Level 'ADQuery' -Message "AD query failed before create" -Context $ctxErr
    continue
  }
  if ($existing) {
    Write-Log -Level 'DuplicateUserInAD' -Message "User already exists (post-uniqueness check), skipping" -Context $ctx
    continue
  }

  # Create user
  try {
    New-ADUser `
      -Name $display `
      -GivenName $first `
      -Surname $last `
      -DisplayName $display `
      -SamAccountName $username `
      -UserPrincipalName $upn `
      -EmailAddress $mail `
      -Path $ouPath `
      -Enabled $true `
      -AccountPassword $password `
      -ChangePasswordAtLogon $true `
      -ErrorAction Stop

    Write-Log -Level 'Info' -Message "User created" -Context $ctx
  } catch {
    $ctxErr = $ctx.Clone()
    $ctxErr['Exception'] = $_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length))
    Write-Log -Level 'ADCreate' -Message "Failed to create user" -Context $ctxErr
    continue
  }
}
