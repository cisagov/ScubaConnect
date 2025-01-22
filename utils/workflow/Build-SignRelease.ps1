function Use-AzureSignTool {
  <#
    .SYNOPSIS
      AzureSignTool is a utility for signing code that is used to secure ScubaGear.
      https://github.com/vcsjones/AzureSignTool
      Throws an error if there was an error signing the files.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ [uri]::IsWellFormedUriString($_, 'Absolute') -and ([uri] $_).Scheme -in 'https' })]
    [System.Uri]
    $AzureKeyVaultUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $CertificateName,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ [uri]::IsWellFormedUriString($_, 'Absolute') -and ([uri] $_).Scheme -in 'http', 'https' })]
    $TimeStampServer = 'http://timestamp.digicert.com',

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    $FileList
  )

  Write-Warning "Using the AzureSignTool method..."

  $SignArguments = @(
    'sign',
    '-coe',
    '-fd', "sha256",
    '-tr', $TimeStampServer,
    '-kvu', $AzureKeyVaultUrl,
    '-kvc', $CertificateName,
    '-kvm'
    '-ifl', $FileList
  )

  Write-Warning "The files to sign are in the temp file $FileList"
  # Make sure the AzureSignTool can be called.
  # Get-Command returns a System.Management.Automation.ApplicationInfo object
  $NumberOfCommands = (Get-Command AzureSignTool) # Should return 1
  if ($NumberOfCommands -eq 0) {
    $ErrorMessage = "Failed to find the AzureSignTool on this system."
    Write-Error = $ErrorMessage
    throw $ErrorMessage
  }

  $ToolPath = (Get-Command AzureSignTool).Path

  Write-Warning "The path to AzureSignTool is $ToolPath"
  # & is the call operator that executes a command, script, or function.
  $Results = & $ToolPath $SignArguments
  # Test the results for failures.
  # If there are no failures, the $SuccessPattern string will be the last
  # line in the results.
  # Warning: This is a brittle test, because it depends upon a specific string.
  $SuccessPattern = 'Failed operations: 0'
  $FoundNoFailures = $Results | Select-String -Pattern $SuccessPattern -Quiet
  if ($FoundNoFailures -eq $true) {
    Write-Warning "Signed the file list without errors."
  }
  else {
    $ErrorMessage = "Failed to sign the file list without errors."
    Write-Error $ErrorMessage
    throw $ErrorMessage
  }
}

function New-ArrayOfFilePaths {
  <#
    .DESCRIPTION
      Creates an array of the files to sign
      Throws an error if no matching files can be found.
      Returns the array.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $ModuleDestinationPath
  )

  $FileExtensions = "*.ps1", "*.psm1", "*.psd1"  # Array of extensions to match on
  $ArrayOfFilePaths = @()
  $ArrayOfFilePaths = Get-ChildItem -Recurse -Path $ModuleDestinationPath -Include $FileExtensions

  #
  # Files to sign. Hardcoded as the number of files to sign is 1 to few.
  # Since we don't need to sign every PowerShell file.
  #
  $FilesToSign = @("Install-GearConnect.ps1")

  # Filter files to the scripts we want to sign
  $ArrayOfFilePaths = $ArrayOfFilePaths | Where-Object { $FilesToSign -contains $_ }

  if ($ArrayOfFilePaths.Length -gt 0) {
    Write-Warning "Found $($ArrayOfFilePaths.Count) files to sign"
  }
  else {
    $ErrorMessage = "Failed to find any .ps1, .psm1, or .psd1 files."
    Write-Error = $ErrorMessage
    throw $ErrorMessage
  }

  return $ArrayOfFilePaths
}

function New-FileList {
  <#
    .DESCRIPTION
      Creates a file that contains a list of all the files to sign
      Throws an error if the file is not created.
      Returns the name of the file.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [array]
    $ArrayOfFilePaths
  )
  $FileListPath = New-TemporaryFile
  $ArrayOfFilePaths.FullName | Out-File -FilePath $($FileListPath.FullName) -Encoding utf8 -Force
  $FileListFileName = $FileListPath.FullName

  # Verify that the file exists
  if (Test-Path -Path $FileListPath) {
    Write-Warning "The list file exists."
  }
  else {
    $ErrorMessage = "Failed to find the list file."
    Write-Error = $ErrorMessage
    throw $ErrorMessage
  }

  return $FileListFileName
}

function New-ScubaReleaseAsset {
  <#
  .SYNOPSIS
  Sign the module.
  .PARAMETER $AzureKeyVaultUrl
  The URL for the KeyVault in Azure.
  .PARAMETER $CertificateName
  The name of the certificate stored in the KeyVault.
  .PARAMETER $ReleaseVersion
  The version number of the release (e.g., 1.5.1).
  .PARAMETER $RootFolderName
  The name of the root folder.
  .EXCEPTIONS
  System.IO.DirectoryNotFoundException
  Thrown if $RootFolderName does not exist.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $AzureKeyVaultUrl,

    [Parameter(Mandatory = $true)]
    [string]
    $CertificateName,

    [Parameter(Mandatory = $true)]
    [string]
    $ReleaseVersion,

    [Parameter(Mandatory = $true)]
    [string]
    $RootFolderName
  )

  Write-Warning "Signing the module with AzureSignTool..."

  # Verify that $RootFolderName exists
  Write-Warning "The root folder name is $RootFolderName"
  if (Test-Path -Path $RootFolderName) {
    Write-Warning "Directory exists"
  }
  else {
    Write-Warning "Directory does not exist; throwing an exception..."
    throw [System.IO.DirectoryNotFoundException] "Directory not found: $RootFolderName"
  }

  # Remove non-release files, like the .git dir, required for non-Windows machines
  Remove-Item -Recurse -Force $RootFolderName -Include .git*
  Write-Warning "Creating an array of the files to sign..."
  $ArrayOfFilePaths = New-ArrayOfFilePaths `
    -ModuleDestinationPath $RootFolderName

  Write-Warning "Creating a file with a list of the files to sign..."
  $FileListFileName = New-FileList `
    -ArrayOfFilePaths $ArrayOfFilePaths

  Write-Warning "Calling AzureSignTool function to sign scripts, manifest, and modules..."
  Use-AzureSignTool `
    -AzureKeyVaultUrl $AzureKeyVaultUrl `
    -CertificateName $CertificateName `
    -FileList $FileListFileName

  # This creates the release asset
  # TODO: Separate GearConnect and GogglesConnect into separate assets
  $ReleaseName = "ScubaConnect"
  Move-Item -Path $RootFolderName -Destination "$ReleaseName-$ReleaseVersion" -Force
  Compress-Archive -Path "$ReleaseName-$ReleaseVersion" -DestinationPath "$ReleaseName-$ReleaseVersion.zip"
}
