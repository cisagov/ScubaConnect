# increase output width to avoid wrapping in LAW
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 25)
$ErrorActionPreference = "Stop"

Write-Output "Installing cert"
# Install certificate by decoding env variable
$PFX_FILE = '.\certificate.pfx'
$BYTES = [Convert]::FromBase64String($Env:PFX_B64)
[IO.File]::WriteAllBytes($PFX_FILE, $BYTES)
$CertificateThumbPrint = (Import-PfxCertificate -FilePath $PFX_FILE -CertStoreLocation cert:\CurrentUser\My).Thumbprint
Write-Output "  CERT: $CertificateThumbPrint"

# Set up az copy using env vars
$Env:AZCOPY_SPA_CERT_PASSWORD = ""
$Env:AZCOPY_SPA_APPLICATION_ID= $Env:APP_ID
$Env:AZCOPY_TENANT_ID=$Env:TENANT_ID
$Env:AZCOPY_AUTO_LOGIN_TYPE="SPN"
$Env:AZCOPY_SPA_CERT_PATH=$PFX_FILE

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
        Write-Output "Running ScubaGear on $($org)"

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
    
    } catch {
        $error_count += 1
        Write-Output "Error occurred while running on $($org)"
        Write-Output $_
    }
}

Write-Output "Finished running on $total_count tenants. Encountered $error_count errors"
if ($error_count -gt 0) {
    exit 1
}
exit 0
