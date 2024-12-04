FROM mcr.microsoft.com/windows/servercore:ltsc2022

ARG SCUBAGEAR_VERSION=1.4.0
ARG AZCOPY_URL=https://azcopyvnext.azureedge.net/releases/release-10.26.0-20240731/azcopy_windows_amd64_10.26.0.zip

WORKDIR /app

# download azcopy exe to workdir
# How URL is obtained for specific version: https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10?tabs=dnf#obtain-a-static-download-link
RUN powershell Invoke-WebRequest -Uri %AZCOPY_URL% -OutFile AzCopy.zip -UseBasicParsing
RUN powershell Expand-Archive .\AzCopy.zip ./AzCopy -Force
RUN powershell $item = Get-ChildItem .\AzCopy\*\azcopy.exe; Move-Item -Path $item -Destination .
RUN powershell Remove-Item AzCopy.zip; Remove-Item -r .\AzCopy

# Needed for setup module installs
RUN powershell Install-PackageProvider -Name NuGet -Force
RUN powershell Install-Module -Name ScubaGear -RequiredVersion %SCUBAGEAR_VERSION% -Force
RUN powershell Initialize-SCuBA
COPY run_container.ps1 .

CMD [ "powershell", ".\\run_container.ps1" ]

