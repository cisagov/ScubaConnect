# increase output width to avoid wrapping in LAW
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 25)
$ErrorActionPreference = "Stop"

Get-ChildItem env:

# Get app certificate from vault
$VaultName = $Env:VaultName
$CertName = $Env:CertName

# Retrieve an Access Token
if (($Env:Vnet -eq 'Yes') -and $Env:IDENTITY_ENDPOINT -like "http://10.92.0.*:2377/metadata/identity/oauth2/token?api-version=1.0") {
    $identityEndpoint = "http://169.254.128.1:2377/metadata/identity/oauth2/token?api-version=1.0"
} else {
    $identityEndpoint = $Env:IDENTITY_ENDPOINT
}

$identityHeader = $Env:IDENTITY_HEADER
$principalId    = $Env:MIPrincipalID

if ($Env:IS_GOV) {
    $VaultURL = "https://$($VaultName).vault.usgovcloudapi.net"
    $RawVaultURL = "https%3A%2F%2F" + "vault.usgovcloudapi.net"
}
else {
    $VaultURL = "https://$($VaultName).vault.azure.net"
    $RawVaultURL = "https%3A%2F%2F" + "vault.azure.net"    
}

$uri = $identityEndpoint + '&resource=' + $RawVaultURL + '&principalId=' + $principalId
$headers = @{
    secret = $identityHeader
    "Content-Type" = "application/x-www-form-urlencoded"
}
$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# Access values from Key Vault with token
$accessToken = $Response.access_token
$headers2 = @{
    Authorization = "Bearer $accessToken"
}

$PrivKey = (Invoke-RestMethod -Uri "$($VaultURL)/Secrets/$($CertName)/?api-version=7.4" -Headers $headers2).Value

# Decode the Base64 string
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
$Env:AZCOPY_ACTIVE_DIRECTORY_ENDPOINT = $Env:IS_GOV ? "https://login.microsoftonline.us" : "https://login.microsoftonline.com"

# Print scuba version to console for debugging
Invoke-SCuBA -Version

Write-Output "Grabbing tenant config files"
.\azcopy copy "$Env:TENANT_INPUT/*" 'input' --output-level quiet
if ($LASTEXITCODE -gt 0) {
    throw "Error reading config files"
}

$total_count = 0
$error_count = 0

Foreach ($tenantConfig in $(Get-ChildItem 'input\')) {
    $total_count += 1
    try {
        $org = $tenantConfig.BaseName.split("_")[0]
        Write-Output "Running ScubaGear for $($tenantConfig.BaseName)"

        $params = @{
            CertificateThumbPrint = $CertificateThumbPrint; # Certificate Hash; Needed for SP auth
            AppID = $Env:APP_ID; # App ID; Needed for Service Principal Auth
            Organization = $org; # primary domain of the tenantConfig needed for Service Principal Auth
            OutPath = ".\reports\$($org)"; # The folder path where the output will be stored
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
        $OutPath = "$($Env:REPORT_OUTPUT)/$($ResultsFile.Name)"
        .\azcopy copy $ResultsFile.FullName $OutPath --output-level quiet
        if ($LASTEXITCODE -gt 0) {
            throw "Error transferring files"
        }
        Write-Output "  Finished Upload to $OutPath"
        Remove-Item $ResultsFile
    
    } catch {
        $error_count += 1
        Write-Output "Error occurred while running on $($org)"
        Write-Output $_
    }

    if ($Env:DEBUG_LOG -eq "true") {
        Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 10
        (Get-Ciminstance Win32_OperatingSystem).FreePhysicalMemory
    }
}

Write-Output "Finished running on $total_count tenants. Encountered $error_count errors"
if ($error_count -gt 0) {
    exit 1
}
exit 0
