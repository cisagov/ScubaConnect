<#
.SYNOPSIS
Install-GearConnect

.DESCRIPTION
Interactively with user credentials registers the ScubaConnect multi-tenant application within the target tenant with the permissions for CISA to run ScubaGear from the application home tenant.

.Parameter AppID
This parameter provides the App ID for the application to install.
This will be provided to you along with the script

.Parameter M365Environment
This parameter is used to authenticate to the different commercial/government environments.
Valid values include "commercial", "gcc", or "gcchigh".
- For M365 tenants with E3/E5 licenses enter the value **"commercial"**.
- For M365 Government Commercial Cloud tenants with G3/G5 licenses enter the value **"gcc"**.
- For M365 Government Commercial Cloud High tenants enter the value **"gcchigh"**.
Default value is 'gcc'.

.Example
Install-GearConnect -AppID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Registers the ScubaConnect multi-tenant application for a GCC tenant.

.Example
Install-GearConnect -AppID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -M365Environment gcchigh
Registers the ScubaConnect multi-tenant application for a GCCHigh tenant.

.NOTES
    Author : CISA
    Version : 0.1
#>


param (      
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]
	$AppID,

	[Parameter(Mandatory = $false)]
	[ValidateSet("commercial", "gcc", "gcchigh", IgnoreCase = $false)]
	[ValidateNotNullOrEmpty()]
	[string]
	$M365Environment = "gcc"
)

# 
# Check if necessary dependencies are installed
# 
#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ModuleList')]
$ModuleList = @(
	@{
		# Install-Module
		ModuleName = 'PowerShellGet'
		ModuleVersion = [version] '2.1.0'
		MaximumVersion = [version] '2.99.99999'
    },
    @{
		# Connect-MgGraph, Disconnect-MgGraph
        ModuleName = 'Microsoft.Graph.Authentication'
        ModuleVersion = [version] '2.12.0'
        MaximumVersion = [version] '2.99.99999'
    },
	@{
		# Get-MgServicePrincipal
        ModuleName = 'Microsoft.Graph.Applications'
        ModuleVersion = [version] '2.12.0'
        MaximumVersion = [version] '2.99.99999'
    },
	@{
		# New-MgRoleManagementDirectoryRoleAssignment
        ModuleName = 'Microsoft.Graph.Identity.Governance'
        ModuleVersion = [version] '2.12.0'
        MaximumVersion = [version] '2.99.99999'
    },
	@{
		# Add-PowerAppsAccount, New-PowerAppManagementApp
        ModuleName = 'Microsoft.PowerApps.Administration.PowerShell'
        ModuleVersion = [version] '2.0.0'
        MaximumVersion = [version] '2.99.99999'
    }
)

Write-Output "Checking for required script dependencies"
foreach ($Module in $ModuleList) {
    $InstalledModuleVersions = Get-Module -ListAvailable -Name $($Module.ModuleName)
    $FoundAcceptableVersion = $false

    foreach ($ModuleVersion in $InstalledModuleVersions) {
        if ($ModuleVersion.Version -ge $Module.ModuleVersion){
            $FoundAcceptableVersion = $true
            break;
        }
    }
    if (-not $FoundAcceptableVersion) {
		Write-Output "Installing required dependency: $($Module.ModuleName)" 
		Install-Module -Name $Module.ModuleName `
		-Force `
		-AllowClobber `
		-Scope CurrentUser `
		-MaximumVersion $Module.MaximumVersion
    }
}

# Establish Graph PowerShell connection
Write-Output "Connecting..."
$EnvMap = @{commercial = "Global"; gcc = "Global"; gcchigh = "USGov"}
Connect-MgGraph -Scopes "Application.Read.All","RoleManagement.ReadWrite.Directory" -Environment $EnvMap[$M365Environment] -NoWelcome
Write-Output $("#"*50)

# get service principical ID for ScubaConnect app. If null, open consent page to add app
$AppSpId = (Get-MgServicePrincipal -Filter "appId eq '$($AppID)'").Id
if ($null -eq $AppSpId) {
	Write-Output "App doesn't exist in tenant. Consent to app in browser."
	$TldMap = @{commercial = "com"; gcc = "com"; gcchigh = "us"}
	Start-Process "https://login.microsoftonline.$($TldMap[$M365Environment])/common/adminconsent?client_id=$($AppID)"
	Write-Host -NoNewLine 'Once app shows in "Enterprise applications" in Azure, press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
	$AppSpId = (Get-MgServicePrincipal -Filter "appId eq '$($AppID)'").Id
	Write-Host
}
Write-Output "ScubaConnect App Service Principal: $AppSpId"
Write-Output $("#"*50)

Write-Output "Granting ScubaConnect App Global Reader role"
# static UUID for global reader. See https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference
$GLOBAL_READER_ROLE_ID = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
$RoleParams = @{
	"@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
	PrincipalId = $AppSpId
	DirectoryScopeId = "/"
	RoleDefinitionId = $GLOBAL_READER_ROLE_ID
}
New-MgRoleManagementDirectoryRoleAssignment -BodyParameter $RoleParams | Out-Null
Write-Output "Checking Global Reader role. If added you should see one row output below without errors"
Get-MgRoleManagementDirectoryRoleAssignment -Filter "RoleDefinitionId eq '$GLOBAL_READER_ROLE_ID' and PrincipalId eq '$AppSpId'"
Write-Output $("#"*50)

Write-Output "Adding ScubaConnect app as PowerApps Admin"
Import-Module Microsoft.PowerApps.Administration.PowerShell -DisableNameChecking
$EndpointMap = @{commercial = "prod"; gcc = "usgov"; gcchigh = "usgovhigh"}
Add-PowerAppsAccount -Endpoint $EndpointMap[$M365Environment]
New-PowerAppManagementApp -ApplicationId $AppID | Out-Null

Write-Output "Checking PowerApps admin. If added correctly you should see the App ID below"
Get-PowerAppManagementApp -ApplicationId $AppId

Write-Output $("#"*50)
Write-Output "Done! Disconnecting"
Disconnect-MgGraph | Out-Null
