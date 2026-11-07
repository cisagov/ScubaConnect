<#
.SYNOPSIS
Install-GearConnect

.DESCRIPTION
Interactively with user credentials registers the ScubaConnect multi-tenant application within the
target tenant with the permissions for the ScubaConnect instance to run ScubaGear from its own tenant.

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
	Version : 0.3
	The user running this script needs Global Administrator, or Privileged Role Administrator plus
	Fabric Administrator, to complete all steps.
	No PowerShell modules are required. Runs on Windows PowerShell 5.1 and PowerShell 7+ on
	Windows, macOS, and Linux. Sign-in happens in the system browser.
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

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core') {
	# Windows PowerShell 5.1 does not enable TLS 1.2 by default
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
	# Windows PowerShell 5.1 can serialize arrays as {"value":[...],"Count":n} without this
	Remove-TypeData System.Array -ErrorAction SilentlyContinue
}

### CLOUD ENDPOINTS (match ScubaGear's endpoint catalog) ###
$Cloud = @{
	commercial = @{
		Login         = "https://login.microsoftonline.com"
		Graph         = "https://graph.microsoft.com"
		Bap           = "https://api.bap.microsoft.com"
		BapScope      = "https://service.powerapps.com//.default"
		PowerBI       = "https://api.powerbi.com"
		PowerBIScope  = "https://analysis.windows.net/powerbi/api/.default"
		PowerBIPortal = "https://app.powerbi.com"
	}
	gcc = @{
		Login         = "https://login.microsoftonline.com"
		Graph         = "https://graph.microsoft.com"
		Bap           = "https://gov.api.bap.microsoft.us"
		BapScope      = "https://gov.service.powerapps.us//.default"
		PowerBI       = "https://api.powerbigov.us"
		PowerBIScope  = "https://analysis.usgovcloudapi.net/powerbi/api/.default"
		PowerBIPortal = "https://app.powerbigov.us"
	}
	gcchigh = @{
		Login         = "https://login.microsoftonline.us"
		Graph         = "https://graph.microsoft.us"
		Bap           = "https://high.api.bap.microsoft.us"
		BapScope      = "https://high.service.powerapps.us//.default"
		PowerBI       = "https://api.high.powerbigov.us"
		PowerBIScope  = "https://high.analysis.usgovcloudapi.net/powerbi/api/.default"
		PowerBIPortal = "https://app.high.powerbigov.us"
	}
}[$M365Environment]

# Well-known public clients (same as ScubaGear): Microsoft Graph Command Line Tools and Azure PowerShell
$GraphClientId = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
$AdminClientId = "1950a258-227b-4e31-a9cf-717495945fc2"

### OUTPUT HELPERS ###
$script:StepCount = 5
$script:Step = 0

function Write-Step([string]$Message) {
	$script:Step++
	Write-Host
	Write-Host "[$($script:Step)/$($script:StepCount)] $Message" -ForegroundColor Cyan
}

# Prints a green success line
function Write-Done([string]$Message) {
	Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Note([string]$Message) {
	Write-Host "  $Message" -ForegroundColor DarkGray
}

### AUTH HELPERS ###
$script:TenantId = "organizations"
$script:LoginHint = $null
$script:RefreshTokens = @{}

function ConvertTo-Base64Url([byte[]]$Bytes) {
	[Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function ConvertFrom-JwtPayload([string]$Jwt) {
	$Payload = $Jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
	$Payload = $Payload.PadRight($Payload.Length + (4 - $Payload.Length % 4) % 4, '=')
	[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload)) | ConvertFrom-Json
}

function Get-ApiErrorMessage($ErrorRecord) {
	if ($ErrorRecord.ErrorDetails.Message) { $ErrorRecord.ErrorDetails.Message } else { $ErrorRecord.Exception.Message }
}

# Gets an access token. The first call per client opens the system browser (OAuth authorization code + PKCE,
# redirected to a temporary localhost listener); later calls reuse that client's refresh token silently.
function Get-GearToken([string]$ClientId, [string]$Scope) {
	$Scope = "$Scope openid profile offline_access"
	$TokenUri = "$($Cloud.Login)/$($script:TenantId)/oauth2/v2.0/token"

	if ($script:RefreshTokens[$ClientId]) {
		$Body = @{
			client_id     = $ClientId
			grant_type    = "refresh_token"
			refresh_token = $script:RefreshTokens[$ClientId]
			scope         = $Scope
		}
	}
	else {
		$Bytes = New-Object byte[] 32
		[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Bytes)
		$Verifier = ConvertTo-Base64Url $Bytes
		$Challenge = ConvertTo-Base64Url ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes($Verifier)))
		$State = [guid]::NewGuid().ToString()

		# Listen on IPv4 and (if available) IPv6 loopback, since browsers may resolve localhost to either
		$Listeners = @([Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0))
		$Listeners[0].Start()
		$Port = $Listeners[0].LocalEndpoint.Port
		try {
			$Listener6 = [Net.Sockets.TcpListener]::new([Net.IPAddress]::IPv6Loopback, $Port)
			$Listener6.Start()
			$Listeners += $Listener6
		}
		catch { Write-Verbose "IPv6 loopback unavailable: $_" }
		$RedirectUri = "http://localhost:$Port"

		$Query = @{
			client_id             = $ClientId
			response_type         = "code"
			response_mode         = "query"
			redirect_uri          = $RedirectUri
			scope                 = $Scope
			state                 = $State
			code_challenge        = $Challenge
			code_challenge_method = "S256"
		}
		if ($script:LoginHint) { $Query.login_hint = $script:LoginHint } else { $Query.prompt = "select_account" }
		$AuthUri = "$($Cloud.Login)/$($script:TenantId)/oauth2/v2.0/authorize?" +
			(($Query.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join '&')

		Write-Note "Opening browser to sign in..."
		try { Start-Process $AuthUri }
		catch { Write-Warning "Could not open a browser. Sign in by browsing to:`n$AuthUri" }

		$Params = $null
		$Deadline = (Get-Date).AddMinutes(5)
		try {
			while (-not $Params) {
				if ((Get-Date) -gt $Deadline) { throw "Timed out waiting for browser sign-in." }
				$Ready = $Listeners | Where-Object { $_.Pending() } | Select-Object -First 1
				if (-not $Ready) { Start-Sleep -Milliseconds 200; continue }

				$Client = $Ready.AcceptTcpClient()
				try {
					$Stream = $Client.GetStream()
					# Browsers may open idle pre-connect sockets; don't block on them forever
					$Stream.ReadTimeout = 10000
					$Reader = New-Object IO.StreamReader($Stream)
					$RequestLine = $Reader.ReadLine()
					while ($Reader.ReadLine()) { } # discard headers
					$Received = @{}
					$Path = "$RequestLine".Split(' ')[1]
					if ($Path -and $Path.Contains('?')) {
						foreach ($Pair in $Path.Substring($Path.IndexOf('?') + 1).Split('&')) {
							$Key, $Value = $Pair.Split('=', 2)
							$Received[[Uri]::UnescapeDataString($Key)] = [Uri]::UnescapeDataString("$Value".Replace('+', ' '))
						}
					}
					# Ignore unrelated requests (e.g. favicon)
					if ($Received.state -eq $State) {
						$Params = $Received
						$Status = "200 OK"
						$Html = "<html><body><p>Sign-in finished. You can close this tab and return to PowerShell.</p></body></html>"
					}
					else {
						$Status = "404 Not Found"
						$Html = ""
					}
					$Response = [Text.Encoding]::UTF8.GetBytes(
						"HTTP/1.1 $Status`r`nContent-Type: text/html; charset=utf-8`r`n" +
						"Content-Length: $([Text.Encoding]::UTF8.GetByteCount($Html))`r`nConnection: close`r`n`r`n$Html")
					$Stream.Write($Response, 0, $Response.Length)
				}
				catch { Write-Verbose "Ignoring unusable browser connection: $_" }
				finally { $Client.Close() }
			}
		}
		finally { $Listeners | ForEach-Object { $_.Stop() } }

		if ($Params.error) { throw "Sign-in failed: $($Params.error): $($Params.error_description)" }
		$Body = @{
			client_id     = $ClientId
			grant_type    = "authorization_code"
			code          = $Params.code
			redirect_uri  = $RedirectUri
			code_verifier = $Verifier
			scope         = $Scope
		}
	}

	try {
		$Token = Invoke-RestMethod -Method Post -Uri $TokenUri -Body $Body
	}
	catch {
		throw "Token request failed: $(Get-ApiErrorMessage $_)"
	}
	if ($Token.refresh_token) { $script:RefreshTokens[$ClientId] = $Token.refresh_token }
	if ($script:TenantId -eq "organizations" -and $Token.id_token) {
		$Claims = ConvertFrom-JwtPayload $Token.id_token
		$script:TenantId = $Claims.tid
		$script:LoginHint = $Claims.preferred_username
	}
	$Token.access_token
}

# Invokes a REST API with a bearer token, surfacing the API's error message on failure.
function Invoke-Api {
	param(
		[string]$Method = "Get",
		[Parameter(Mandatory = $true)][string]$Uri,
		[Parameter(Mandatory = $true)][string]$Token,
		$Body
	)
	$Request = @{ Method = $Method; Uri = $Uri; Headers = @{ Authorization = "Bearer $Token" } }
	if ($null -ne $Body) {
		$Request.Body = ConvertTo-Json -InputObject $Body -Depth 10
		$Request.ContentType = "application/json"
	}
	try {
		Invoke-RestMethod @Request
	}
	catch {
		throw "$($Method.ToUpper()) $Uri failed: $(Get-ApiErrorMessage $_)"
	}
}

### ESTABLISH GRAPH CONNECTION ###
Write-Host "ScubaConnect installer ($M365Environment)" -ForegroundColor Cyan
Write-Step "Signing in"
$GraphScope = @("Application.Read.All", "RoleManagement.ReadWrite.Directory", "Group.ReadWrite.All" |
	ForEach-Object { "$($Cloud.Graph)/$_" }) -join ' '
$GraphToken = Get-GearToken -ClientId $GraphClientId -Scope $GraphScope
Write-Done "Signed in as $($script:LoginHint) (tenant $($script:TenantId))"

### ADD APP TO TENANT IF NEEDED (requires user consent) ###
Write-Step "Adding ScubaConnect app to tenant"
$SpUri = "$($Cloud.Graph)/v1.0/servicePrincipals?`$filter=$([Uri]::EscapeDataString("appId eq '$AppID'"))"
$AppSpId = (Invoke-Api -Uri $SpUri -Token $GraphToken).value.id
if ($null -eq $AppSpId) {
	Write-Host "  App isn't in the tenant yet. Approve the consent page opening in your browser." -ForegroundColor Yellow
	Start-Process "$($Cloud.Login)/$($script:TenantId)/adminconsent?client_id=$($AppID)"
	Write-Host -NoNewLine '  Once app shows in "Enterprise applications" in Azure, press any key to continue...' -ForegroundColor Cyan
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
	Write-Host
	$AppSpId = (Invoke-Api -Uri $SpUri -Token $GraphToken).value.id
	if ($null -eq $AppSpId) { throw "ScubaConnect app $AppID was not found in the tenant. Complete admin consent and rerun." }
	Write-Done "App added to tenant"
}
else {
	Write-Done "App is already in the tenant"
}
Write-Note "Service principal: $AppSpId"

### GRANT GLOBAL READER ###
Write-Step "Granting Global Reader role"
# static UUID for global reader. See https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference
$GLOBAL_READER_ROLE_ID = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
$RoleUri = "$($Cloud.Graph)/v1.0/roleManagement/directory/roleAssignments"
$RoleFilterUri = "$($RoleUri)?`$filter=$([Uri]::EscapeDataString("roleDefinitionId eq '$GLOBAL_READER_ROLE_ID' and principalId eq '$AppSpId'"))"

if ((Invoke-Api -Uri $RoleFilterUri -Token $GraphToken).value) {
	Write-Done "Global Reader role is already assigned"
}
else {
	$RoleParams = @{
		"@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
		principalId = $AppSpId
		directoryScopeId = "/"
		roleDefinitionId = $GLOBAL_READER_ROLE_ID
	}
	$null = Invoke-Api -Method Post -Uri $RoleUri -Token $GraphToken -Body $RoleParams
	if ((Invoke-Api -Uri $RoleFilterUri -Token $GraphToken).value) {
		Write-Done "Global Reader role assigned"
	}
	else {
		Write-Warning "Global Reader role was assigned but is not visible yet. Verify it in Entra ID."
	}
}

### ADD AS POWERAPPS ADMIN ###
Write-Step "Registering ScubaConnect app as PowerApps admin"
$AdminToken = Get-GearToken -ClientId $AdminClientId -Scope $Cloud.BapScope
$AdminAppsUri = "$($Cloud.Bap)/providers/Microsoft.BusinessAppPlatform/adminApplications"
$ApiVersion = "api-version=2020-10-01"
function Test-PowerAppAdmin {
	(Invoke-Api -Uri "$($AdminAppsUri)?$ApiVersion" -Token $AdminToken).value.applicationId -contains $AppID
}

if (Test-PowerAppAdmin) {
	Write-Done "App is already a PowerApps admin"
}
else {
	$null = Invoke-Api -Method Put -Uri "$AdminAppsUri/$($AppID)?$ApiVersion" -Token $AdminToken
	if (Test-PowerAppAdmin) {
		Write-Done "App registered as PowerApps admin"
	}
	else {
		Write-Warning "App was registered but is not in the PowerApps admin list yet. Verify it in the Power Platform admin center."
	}
}

### CONFIGURE POWERBI ACCESS ###
Write-Step "Configuring Power BI read-only admin API access"
$SecurityGroupName = "ScubaConnectSecurityGroup"

# Part 1: plain security group (not role-assignable) containing the ScubaConnect SP
$GroupUri = "$($Cloud.Graph)/v1.0/groups"
$SecGroup = (Invoke-Api -Uri "$($GroupUri)?`$top=1&`$filter=$([Uri]::EscapeDataString("displayName eq '$SecurityGroupName'"))" -Token $GraphToken).value |
	Select-Object -First 1
if ($null -eq $SecGroup) {
	$GroupParams = @{
		displayName     = $SecurityGroupName
		description     = "Grants ScubaConnect read-only access to Power BI admin APIs"
		securityEnabled = $true
		mailEnabled     = $false
		mailNickname    = $SecurityGroupName
	}
	$SecGroup = Invoke-Api -Method Post -Uri $GroupUri -Token $GraphToken -Body $GroupParams
	Write-Done "Created security group $SecurityGroupName"
}
else {
	Write-Done "Using existing security group $SecurityGroupName"
}
Write-Note "Group ID: $($SecGroup.id)"

try {
	$MemberParams = @{ "@odata.id" = "$($Cloud.Graph)/v1.0/directoryObjects/$AppSpId" }
	$null = Invoke-Api -Method Post -Uri "$GroupUri/$($SecGroup.id)/members/`$ref" -Token $GraphToken -Body $MemberParams
	Write-Done "Added app to $SecurityGroupName"
}
catch {
	if ("$_" -like "*already exist*") {
		Write-Done "App is already a member of $SecurityGroupName"
	}
	else {
		throw
	}
}

# Part 2: allow the group in the 'Service principals can access read-only admin APIs' tenant setting
$SettingName = "AllowServicePrincipalsUseReadAdminAPIs"
$PropagationNote = "Power BI setting changes can take up to 15 minutes to take effect."
try {
	$PowerBIToken = Get-GearToken -ClientId $AdminClientId -Scope $Cloud.PowerBIScope
	$Setting = (Invoke-Api -Uri "$($Cloud.PowerBI)/v1/admin/tenantsettings" -Token $PowerBIToken).tenantSettings |
		Where-Object { $_.settingName -eq $SettingName }
	$Groups = @(if ($Setting -and $Setting.enabledSecurityGroups) { $Setting.enabledSecurityGroups })

	if ($Setting.enabled -and $Groups.Count -eq 0) {
		Write-Done "Power BI setting is already enabled for the entire organization"
	}
	elseif ($Setting.enabled -and $Groups.graphId -contains $SecGroup.id) {
		Write-Done "Power BI setting is already enabled for $SecurityGroupName"
	}
	else {
		if ($Groups.graphId -notcontains $SecGroup.id) {
			$Groups += [PSCustomObject]@{ graphId = $SecGroup.id; name = $SecurityGroupName }
		}
		$Update = @{ enabled = $true; enabledSecurityGroups = $Groups }
		# Preserve the rest of the existing setting
		foreach ($Property in "excludedSecurityGroups", "properties", "delegateToCapacity", "delegateToDomain", "delegateToWorkspace") {
			if ($Setting -and $null -ne $Setting.$Property) { $Update[$Property] = $Setting.$Property }
		}
		$null = Invoke-Api -Method Post -Uri "$($Cloud.PowerBI)/v1/admin/tenantsettings/$SettingName/update" -Token $PowerBIToken -Body $Update
		Write-Done "Enabled 'Service principals can access read-only admin APIs' for $SecurityGroupName"
		Write-Note $PropagationNote
	}
}
catch {
	if ("$_" -like "*FeatureNotAvailable*") {
		Write-Host "  Power BI does not support changing this setting via API in this tenant; complete it manually below." -ForegroundColor Yellow
	}
	else {
		Write-Warning "Could not update the Power BI tenant setting automatically: $_"
	}
	Write-Host @"
  In the Power BI Admin portal (requires Fabric Administrator or Global Administrator):
    1. Go to 'Tenant settings' then scroll down to 'Admin API settings'
    2. Enable 'Service principals can access read-only admin APIs'
    3. Under 'Apply to', select 'Specific security groups' and add '$SecurityGroupName'
    4. Click Apply
"@ -ForegroundColor Yellow
	Start-Process "$($Cloud.PowerBIPortal)/admin-portal/tenantSettings"
	Write-Host -NoNewLine '  Press S to skip (e.g. tenant has no Power BI), or any other key once the setting is applied...' -ForegroundColor Cyan
	$Key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	Write-Host
	if ("$($Key.Character)" -eq 's') {
		Write-Note "Skipped Power BI setup. Rerun this script if Power BI is added later."
	}
	else {
		Write-Note $PropagationNote
	}
}

Write-Host
Write-Host "Done!" -ForegroundColor Green
