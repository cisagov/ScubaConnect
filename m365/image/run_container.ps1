# increase output width to avoid wrapping in LAW
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 25)
$ErrorActionPreference = "Stop"

Invoke-SCuBA -Version
if ($Env:DEBUG_LOG -eq "true") {
    Get-ChildItem env:
}

Write-Output "Getting certificate from keyvault"
# Retrieve an Access Token
if (($Env:IS_VNET -eq "true") -and $Env:IDENTITY_ENDPOINT -like "http://10.92.0.*:2377/metadata/identity/oauth2/token?api-version=1.0") {
    $identityEndpoint = "http://169.254.128.1:2377/metadata/identity/oauth2/token?api-version=1.0"
} else {
    $identityEndpoint = $Env:IDENTITY_ENDPOINT
}

if ($Env:IS_GOV -eq "true") {
    $VaultURL = "https://$($Env:VAULT_NAME).vault.usgovcloudapi.net"
    $RawVaultURL = "https%3A%2F%2F" + "vault.usgovcloudapi.net"
}
else {
    $VaultURL = "https://$($Env:VAULT_NAME).vault.azure.net"
    $RawVaultURL = "https%3A%2F%2F" + "vault.azure.net"
}

$uri = $identityEndpoint + '&resource=' + $RawVaultURL + '&principalId=' + $Env:MI_PRINCIPAL_ID
$headers = @{
    secret = $Env:IDENTITY_HEADER
    "Content-Type" = "application/x-www-form-urlencoded"
}

$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Access values from Key Vault with token
$accessToken = $Response.access_token
$headers2 = @{
    Authorization = "Bearer $accessToken"
}

$PrivKey = (Invoke-RestMethod -Uri "$($VaultURL)/Secrets/$($Env:CERT_NAME)/?api-version=7.4" -Headers $headers2).Value
$PFX_BYTES = [Convert]::FromBase64String($PrivKey)
Write-Output "Installing cert"
# Install certificate by decoding env variable
$PFX_FILE = '.\certificate.pfx'
[IO.File]::WriteAllBytes($PFX_FILE, $PFX_BYTES)
$CertificateThumbPrint = (Import-PfxCertificate -FilePath $PFX_FILE -CertStoreLocation cert:\CurrentUser\My).Thumbprint
Write-Output "  CERT: $CertificateThumbPrint"

# Set up az copy using env vars
$Env:AZCOPY_SPA_CERT_PASSWORD = ""
$Env:AZCOPY_SPA_APPLICATION_ID= $Env:APP_ID
$Env:AZCOPY_TENANT_ID=$Env:TENANT_ID
$Env:AZCOPY_AUTO_LOGIN_TYPE="SPN"
$Env:AZCOPY_SPA_CERT_PATH=$PFX_FILE
$Env:AZCOPY_ACTIVE_DIRECTORY_ENDPOINT = if ($Env:IS_GOV -eq "true") {"https://login.microsoftonline.us"} else {"https://login.microsoftonline.com"}

Write-Output "Grabbing tenant config files"
New-Item -Path "input" -ItemType Directory | Out-Null
.\azcopy copy "$Env:TENANT_INPUT/*" 'input' --include-pattern "*.yaml;*.yml;*.json" --output-level essential
if ($LASTEXITCODE -gt 0) {
    throw "Error reading config files"
}

$OutPathPrefix = "$($Env:REPORT_OUTPUT)/$(Get-Date -Format "yyyy/MM/dd")/"
$TenantCount = 0
$Files = @()
$ErrorTenants = @()

Foreach ($tenantConfig in $(Get-ChildItem 'input\')) {
    try {
        $Organization = $tenantConfig.BaseName.split("_")[0]
        $TenantCount += 1
        Write-Output "Running ScubaGear for $($tenantConfig.BaseName)"

        $Params = @{
            CertificateThumbPrint = $CertificateThumbPrint;
            AppID = if ($null -ne $Env:SECONDARY_APP_ID -and $Organization.EndsWith($Env:SECONDARY_APP_TLD)) {$Env:SECONDARY_APP_ID} else {$Env:APP_ID};
            Organization = $Organization;
            OutPath = ".\reports\$($Organization)"; # The folder path where the output will be stored
            OPAPath = "."
            ConfigFilePath = $tenantConfig.FullName
            Quiet = $true;
        }
        Invoke-SCuBA @Params

        Write-Output "  Appending metadata"
        $ResultsFile = Get-ChildItem -Path ".\reports\$($Organization)\*\ScubaResults*.json"
        $JsonResults = Get-Content -Path $ResultsFile.FullName | ConvertFrom-Json
        $JsonResults.MetaData | Add-Member -NotePropertyName "RunType" -NotePropertyValue $Env:RUN_TYPE
        $JsonResults | ConvertTo-Json -Compress -Depth 100 | Out-File -Encoding UTF8 $ResultsFile.FullName

        Write-Output "  Starting Upload"
        if ("true" -eq $Env:OUTPUT_ALL_FILES) {
            $InPath = "$($ResultsFile.DirectoryName)\*"
            $RelOutPath = "$($Organization)-$([int]$(Get-Date).TimeOfDay.TotalSeconds)"
        }
        else {
            $InPath = $ResultsFile.FullName
            $RelOutPath = $ResultsFile.Name
        }
        if ($null -ne $Env:REPORT_SAS) {
            $RelOutPath += "?$($Env:REPORT_SAS)"
        }
        .\azcopy copy $InPath "$OutPathPrefix$RelOutPath" --output-level essential --recursive
        if ($LASTEXITCODE -gt 0) {
            throw "Error transferring files"
        }
        Write-Output "  Finished Upload to $OutPathPrefix$RelOutPath"
        $Files += $RelOutPath
        Remove-Item $ResultsFile

    } catch {
        $ErrorTenants += $Organization
        Write-Output "Error occurred while running on $($Organization)"
        Write-Output $_
    }

    if ("true" -eq $Env:DEBUG_LOG) {
        Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 10
        (Get-Ciminstance Win32_OperatingSystem).FreePhysicalMemory
    }
}

if ("true" -ne $Env:SKIP_AUDIT_LOG) {
    $Audit = [PSCustomObject]@{
        date = (Get-Date).ToUniversalTime().ToString('s')
        source = "ScubaConnect"
        filenames = $files
    }
    $AuditFile = "ScubaAudit_$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mm-ss')).json"
    $Audit | ConvertTo-Json -Compress -Depth 100 | Out-File -Encoding UTF8 $AuditFile
    .\azcopy copy $AuditFile "$OutPathPrefix$AuditFile" --output-level essential --recursive
    Write-Output "Uploaded audit log to $OutPathPrefix$AuditFile"
}

Write-Output "Finished running on $TenantsCount tenants. Encountered $($ErrorTenants.Count) ErrorTenants"
if ($ErrorTenants.Count -gt 0) {
    Write-Output "Tenants with errors:`n  $($ErrorTenants -join "`n  ")"
    exit 1
}
exit 0
