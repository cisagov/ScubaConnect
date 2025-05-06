FROM mcr.microsoft.com/windows/servercore:ltsc2022
SHELL ["powershell"]


ARG SCUBAGEAR_VERSION=1.5.0
ARG OPA_VERSION=1.3.0
# Get static URL for current version: curl -s -D- https://aka.ms/downloadazcopy-v10-windows | grep ^Location
# https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10?tabs=dnf#obtain-a-static-download-link
ARG AZCOPY_URL=https://azcopyvnext-awgzd8g7aagqhzhe.b02.azurefd.net/releases/release-10.29.0-20250428/azcopy_windows_amd64_10.29.0.zip 

LABEL scubagear_version=${SCUBAGEAR_VERSION}

WORKDIR /app

# download azcopy exe to workdir
RUN $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri $Env:AZCOPY_URL -OutFile AzCopy.zip -UseBasicParsing
RUN Expand-Archive .\AzCopy.zip ./AzCopy -Force
RUN $item = Get-ChildItem .\AzCopy\*\azcopy.exe; Move-Item -Path $item -Destination .
RUN Remove-Item AzCopy.zip; Remove-Item -r .\AzCopy

# Needed for setup module installs
RUN Install-PackageProvider -Name NuGet -Force
RUN Install-Module -Name ScubaGear -RequiredVersion $Env:SCUBAGEAR_VERSION -Force
RUN Initialize-SCuBA -Scope AllUsers -NoOPA
COPY run_container.ps1 .

# manually install OPA, grant ContainerUser execute permissions, then switch to user
ENV OPA_NAME="opa_windows_amd64.exe"
RUN $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://openpolicyagent.org/downloads/v$($Env:OPA_VERSION)/opa_windows_amd64.exe -OutFile $Env:OPA_NAME -UseBasicParsing
RUN if ((Get-FileHash $Env:OPA_NAME -Algorithm SHA256).Hash -ne ([System.Text.Encoding]::ASCII.GetString((Invoke-WebRequest -Uri https://openpolicyagent.org/downloads/v$($Env:OPA_VERSION)/opa_windows_amd64.exe.sha256 -UseBasicParsing).Content) -split ' ')[0]) { exit 1 }
RUN icacls.exe $env:OPA_NAME /grant 'User Manager\ContainerUser:RX'
USER ContainerUser

CMD [ "powershell", ".\\run_container.ps1" ]
