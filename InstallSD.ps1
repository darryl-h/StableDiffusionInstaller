# Requires -Version 5
# Author: Darryl H (https://github.com/darryl-h)
# Date: 2022-10-08
# Version: 0.1
# Execute with: Powershell -noprofile -executionpolicy bypass -File .\installSD.ps1

#################
# Start Logging #
#################
Start-Transcript -Path ".\SD_Install.log" -Append -IncludeInvocationHeader

##############################
# Disable Progress Indicator #
##############################
# This needs to be disabled while downloading with Invoke-WebRequest, otherwise it's far too slow
$ProgressPreference = 'SilentlyContinue'

function Get-InstalledApps
{
    # The value of the [IntPtr] property is 4 in a 32-bit process, and 8 in a 64-bit process.
    if ([IntPtr]::Size -eq 4) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

function InstallSoftwareFromWeb
{
    $FriendlyName = $args[0]
    $DownloadURL = $args[1]
    $DownloadFilename = $args[2]
    $Arguments = $args[3]
    $DisplayName = $args[4]
    $ErrorDownloadURL = $args[5]
    $InstallerFile = $args[6]
    # Banner
    Write-Host "$FriendlyName" -ForegroundColor Cyan
    # Check to see if software is already installed
    $PreCheck = Get-InstalledApps | where {$_.DisplayName -like "$DisplayName"}
    If ($PreCheck -eq $null) {
        Write-Host "`t$FriendlyName Not Found, Proceeding with Installation" -ForegroundColor Green
        Write-Host "`tDownloading $FriendlyName"
        Start-BitsTransfer -Source $DownloadURL -Destination "$($ENV:Temp)\$DownloadFilename"
        $InstallerExtension = [IO.Path]::GetExtension("$($ENV:Temp)\$DownloadFilename")
        Else {
            Write-Host "`tInstalling $FriendlyName"
            # Start-Process -FilePath "C:\Users\Administrator\Downloads\$DownloadFilename" -ArgumentList $Arguments -Wait
            $proc = Start-Process -FilePath "$($ENV:Temp)\$DownloadFilename" -ArgumentList $Arguments -Passthru
            do {start-sleep -Milliseconds 500}
            until ($proc.HasExited)
        }
        # Backup Download Method
        # Invoke-WebRequest -Uri "$DownloadURL" -OutFile $DownloadFilename -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
        Start-Sleep -s 5
        If ($DisplayName -eq 'SkipVerify') {
            Write-Host "`tWARNING: Installation Verification Overridden (SkipVerify)" -ForegroundColor Yellow
            Write-Host "`tNOTE: If the software did not install properly, please see: $ErrorDownloadURL" -ForegroundColor Yellow
            Remove-Item "$($ENV:Temp)\$DownloadFilename"
        }
        Else {
            $TargetSoftwareInstalled = Get-InstalledApps | where {$_.DisplayName -like "$DisplayName"}
            If ($TargetSoftwareInstalled -eq $null) {
                Write-Host "`tERROR: $FriendlyName Not Installed -- Install Manually from $ErrorDownloadURL" -ForegroundColor Red
            }
            Else {
                Write-Host "`tSUCCESS: $FriendlyName Installed!" -ForegroundColor Green
                Remove-Item $($ENV:Temp)\$DownloadFilename
            }
        }
    }
    Else {
    Write-Host "`tWARNING: $FriendlyName already installed, skipping..." -ForegroundColor Yellow
    }
}

####################
# Install Software # 
####################
# InstallSoftwareFromWeb  <FriendlyName>   <DownloadURL>                                                                                         <DownloadFileName>           <Installation_Arguments>                            <Software DisplayName> <ErrorDownloadURL>                                         <Installer Path and FileName (Required for compressed downloads)>
InstallSoftwareFromWeb    'Python 3.10'    'https://www.python.org/ftp/python/3.10.7/python-3.10.7-amd64.exe'                                    'python-3.10.7-amd64.exe'    'InstallAllUsers=1 PrependPath=1 Include_test=0'    'Python 3.10*'          'https://www.python.org/downloads/release/python-3107/'
InstallSoftwareFromWeb    'Git'            'https://github.com/git-for-windows/git/releases/download/v2.38.0.windows.1/Git-2.38.0-64-bit.exe'    'Git-2.38.0-64-bit.exe'      '/VERYSILENT'                                       git                    'https://git-scm.com/download/win'
#####################################
# INSTALL STABLE DIFFUSION SOFTWARE #
#####################################
Write-Host "`tGit cloning Stable Diffusion"
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

Write-Host "`tDownloading Models (4GB -- This can take some time)"
Start-BitsTransfer -Source https://www.googleapis.com/storage/v1/b/aai-blog-files/o/sd-v1-4.ckpt?alt=media -Destination .\stable-diffusion-webui\models\Stable-diffusion\sd-v1-4.ckpt

Write-Host "`tDownloading PyTorch file"
Start-BitsTransfer -Source https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth -Destination .\stable-diffusion-webui\GFPGANv1.4.pth