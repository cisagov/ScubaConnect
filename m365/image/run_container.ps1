Write-Output "Installing cert"
# install certificate by decoding env variable
$PFX_FILE = '.\certificate.pfx'
$BYTES = [Convert]::FromBase64String($Env:PFX_B64)
[IO.File]::WriteAllBytes($PFX_FILE, $BYTES)
$CertificateThumbPrint = (Import-PfxCertificate -FilePath $PFX_FILE -CertStoreLocation cert:\CurrentUser\My).Thumbprint
Write-Output "  CERT: $CertificateThumbPrint"

$META_FIELDS = $Env:RUN_METADATA_FIELDS.Split("#")

# Set up az copy using env vars
$Env:AZCOPY_SPA_CERT_PASSWORD = ""
$Env:AZCOPY_SPA_APPLICATION_ID= $Env:APP_ID
$Env:AZCOPY_TENANT_ID=$Env:TENANT_ID
$Env:AZCOPY_AUTO_LOGIN_TYPE="SPN"
$Env:AZCOPY_SPA_CERT_PATH=$PFX_FILE

# Print scuba version to console for debugging
Invoke-SCuBA -Version

Write-Output "Grabbing tenants json file"
.\azcopy copy "$Env:TENANT_INPUT/*" 'input' --output-level quiet

Foreach ($tenantConfig in $(Get-ChildItem 'input\')) {
    try {
        $org = $tenantConfig.BaseName
        Write-Output "Running ScubaGear on $($org)"

        $params = @{
            CertificateThumbPrint = $CertificateThumbPrint; # Certificate Hash; Needed for SP auth
            AppID = $Env:APP_ID; # App ID; Needed for Service Principal Auth
            Organization = $org; # primary domain of the tenantConfig needed for Service Principal Auth
            OutPath = ".\reports\$($org)"; # The folder path where the output will be stored
            ConfigFilePath = $tenantConfig.FullName
            Quiet = $true;
            MergeJson = $true;
        }
        Invoke-SCuBA @params

        Write-Output "  Appending metadata"
        $JsonResults = Get-Content -Path ".\reports\$($org)\*\ScubaResults.json" | ConvertFrom-Json
        if ($META_FIELDS.count -gt 0) {
            $Config = Get-Content -Raw -Path $tenantConfig.FullName | ConvertFrom-Yaml
            Foreach ($field in $META_FIELDS) {
                $JsonResults.MetaData | add-member -NotePropertyName $field -NotePropertyValue $Config.$field
            }
        }
        $JsonResults.MetaData | add-member -NotePropertyName "RunType" -NotePropertyValue $Env:RUN_TYPE
        $JsonResults | ConvertTo-Json -Compress -Depth 100 | Out-File -Encoding UTF8 ".\reports\$($org)\ScubaResults.json"

        Write-Output "  Starting Upload"
        $OutPath = "$($Env:REPORT_OUTPUT)/ScubaResults-$($org)-$(Get-Date -Format "yyyy_MM_dd_HH_mm_ss").json"
        .\azcopy copy ".\reports\$($org)\ScubaResults.json" $OutPath --output-level quiet
        Write-Output "  Finished Upload to $OutPath"
    
    } catch {
        Write-Output "Error occurred while running on $($org)"
        Write-Output $_
    }
}

Write-Output "Finished running on all tenants"


