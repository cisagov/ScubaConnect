# increase output width to avoid wrapping in LAW
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 25)
$ErrorActionPreference = "Stop"

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

# Print scuba version to console for debugging
Invoke-SCuBA -Version

Write-Output "Grabbing tenant config files"
New-Item -Path "input" -ItemType Directory | Out-Null
.\azcopy copy "$Env:TENANT_INPUT/*" 'input' --include-pattern "*.yaml;*.yml;*.json" --output-level essential
if ($LASTEXITCODE -gt 0) {
    throw "Error reading config files"
}

# Parse output containers from environment variables.
if ($null -ne $Env:OUTPUT_CONTAINER_URLS) {
    # @(...) forces array context so single-element results aren't unwrapped to a scalar
    $OutputUrls = @($Env:OUTPUT_CONTAINER_URLS | ConvertFrom-Json)
    $OutputSasTokens = @($Env:OUTPUT_CONTAINER_SAS_TOKENS | ConvertFrom-Json)

    # Sanity check: both arrays must have the same length
    if ($OutputUrls.Count -ne $OutputSasTokens.Count) {
        throw "Configuration error: OUTPUT_CONTAINER_URLS has $($OutputUrls.Count) entries but OUTPUT_CONTAINER_SAS_TOKENS has $($OutputSasTokens.Count) entries. These must match."
    }
} elseif ($null -ne $Env:REPORT_OUTPUT) {
    # DEPRECATED path: legacy single-output variables used when Terraform has not been updated
    Write-Output "  WARNING: Using deprecated REPORT_OUTPUT/REPORT_SAS variables. Update your Terraform to use the new output variables."
    $OutputUrls = @($Env:REPORT_OUTPUT)
    $OutputSasTokens = @($(if ($null -ne $Env:REPORT_SAS) { $Env:REPORT_SAS } else { "" }))
} else {
    throw "No output configured. Set OUTPUT_CONTAINER_URLS (or the deprecated REPORT_OUTPUT)."
}

$total_count = 0
$error_count = 0

Foreach ($tenantConfig in $(Get-ChildItem 'input\')) {
    $total_count += 1
    try {
        $org = $tenantConfig.BaseName.split("_")[0]
        Write-Output "Running ScubaGear for $($tenantConfig.BaseName)"

        $params = @{
            CertificateThumbPrint = $CertificateThumbPrint;
            AppID = if ($null -ne $Env:SECONDARY_APP_ID -and $org.EndsWith($Env:SECONDARY_APP_TLD)) {$Env:SECONDARY_APP_ID} else {$Env:APP_ID}; 
            Organization = $org;
            OutPath = ".\reports\$($org)"; # The folder path where the output will be stored
            OPAPath = "."
            ConfigFilePath = $tenantConfig.FullName
            Quiet = $true;
        }
        Invoke-SCuBA @params

        Write-Output "  Appending metadata"
        $ResultsFile = Get-ChildItem -Path ".\reports\$($org)\*\ScubaResults*.json"
        $JsonResults = Get-Content -Path $ResultsFile.FullName | ConvertFrom-Json
        $JsonResults.MetaData | add-member -NotePropertyName "RunType" -NotePropertyValue $Env:RUN_TYPE
        $JsonResults | ConvertTo-Json -Compress -Depth 100 | Out-File -Encoding UTF8 $ResultsFile.FullName

        Write-Output "  Starting Upload"
        $DatePath = Get-Date -Format "yyyy/MM/dd"

        Write-Output "  Uploading to $($OutputUrls.Count) destination(s)"

        $uploadFailures = @()

        for ($i = 0; $i -lt $OutputUrls.Count; $i++) {
            $url = $OutputUrls[$i]
            $sasToken = $OutputSasTokens[$i]
            
            # Build paths based on output mode
            if ("true" -eq $Env:OUTPUT_ALL_FILES) {
                $InPath = "$($ResultsFile.DirectoryName)\*"
                $OutPath = "$url/$($DatePath)/$($org)-$([int]$(Get-Date).TimeOfDay.TotalSeconds)"
            }
            else {
                $InPath = $ResultsFile.FullName
                $OutPath = "$url/$($DatePath)/$($ResultsFile.Name)"
            }
            
            # Append SAS token if provided (non-empty string)
            if (![string]::IsNullOrEmpty($sasToken)) {
                $OutPath += "?$sasToken"
                Write-Output "    -> $url (using SAS token)"
            } else {
                Write-Output "    -> $url (using managed identity)"
            }
            
            .\azcopy copy $InPath $OutPath --output-level essential --recursive
            if ($LASTEXITCODE -gt 0) {
                $uploadFailures += $url
                Write-Output "    ERROR: Failed to upload to $url"
            } else {
                Write-Output "    SUCCESS: Uploaded to $url"
            }
        }

        # Fail if ANY upload failed - ensures user investigates
        if ($uploadFailures.Count -gt 0) {
            throw "Failed to upload results to $($uploadFailures.Count) of $($OutputUrls.Count) destination(s): $($uploadFailures -join ', ')"
        }

        Write-Output "  All uploads completed successfully"
        Remove-Item $ResultsFile
    
    } catch {
        $error_count += 1
        Write-Output "Error occurred while running on $($org)"
        Write-Output $_
    }

    if ("true" -eq $Env:DEBUG_LOG) {
        Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 10
        (Get-Ciminstance Win32_OperatingSystem).FreePhysicalMemory
    }
}

Write-Output "Finished running on $total_count tenants. Encountered $error_count errors"
if ($error_count -gt 0) {
    exit 1
}
exit 0
