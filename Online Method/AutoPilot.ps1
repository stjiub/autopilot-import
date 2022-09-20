<#
.SYNOPSIS
Automates the importing of a device to AutoPilot during Windows installation.

.DESCRIPTION
Written to be used in conjunction with an autounattend.xml file during automated Windows
installation. This script is ran during the "Specialize" phase. It will check to see if the
device is already in AutoPilot and if not it will import the device and wait for an
AutoPilot profile to be assigned.

.PARAMETER ClientId
Azure app client id used to authenticate

.PARAMETER ClientSecret
Azure app client secret used to authenticate

.PARAMETER TenantId
Azure tenant id used to authenticate

.PARAMETER AuthFile
A file containing the ClientId, ClientSecret, and TenantId.

.PARAMETER GroupTag
Assign the device a specific AutoPilot group tag
#>

[cmdletbinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$AuthFile,

    [Parameter(Mandatory = $false)]
    [string]$GroupTag
)

begin {
    function Add-AutoPilotDevice {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$HardwareHash,
    
            [Parameter(Mandatory = $false)]
            [string]$Serial,
    
            [Parameter(Mandatory = $false)]
            [string]$GroupTag,
    
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Token,
    
            [Parameter(DontShow = $true)]
            [string]$GraphVersion = "beta"
        )
    
        process {
            $headers = @{
                Authorization = "$($Token.token_type) $($Token.access_token)"
            }
    
            $body = New-Object PSObject -Property @{
                "hardwareIdentifier" = $hash
            }
    
            if ($Serial) {
                Add-Member -InputObject $body -NotePropertyName "serialNumber" -NotePropertyValue $serial
            }
            
            # Add group tag
            if ($GroupTag) {
                Add-Member -InputObject $body -NotePropertyName "groupTag" -NotePropertyValue $GroupTag
            }
    
            $postSplat = @{
                Method = "Post"
                Uri = "https://graph.microsoft.com/$GraphVersion/devicemanagement/importedWindowsAutopilotDeviceIdentities"
                Headers = $headers
                ContentType = "application/json"
                Body = $body | ConvertTo-Json
            }
            
            $post = Invoke-RestMethod @postSplat
    
            return $post
        }
    }

    function Get-AutoPilotDevice {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Serial,
    
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Token
        )
    
        process {
            $headers = @{
                Authorization = "$($Token.token_type) $($Token.access_token)"
            }
    
            $encoded = [uri]::EscapeDataString($serial)
            $deviceSplat = @{
                Method = "Get"
                Uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$encoded')"
                Headers = $headers
            }
            $device = Invoke-RestMethod @deviceSplat
    
            return $device
        }
    }

    function Get-AutoPilotDeviceImportStatus {
        [cmdletbinding()]
        param(
            [Parameter (Mandatory = $true)]
            [string]$Id,
    
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Token
        )
    
        process {
            $headers = @{
                Authorization = "$($Token.token_type) $($Token.access_token)"
            }
    
            $statusSplat = @{
                Method = "Get"
                Uri = "https://graph.microsoft.com/beta/devicemanagement/importedWindowsAutopilotDeviceIdentities/$Id"
                Headers = $headers
            }
            $status = Invoke-RestMethod @statusSplat | Select-Object -ExpandProperty State
    
            return $status
        }
    }

    function Get-AutoPilotDeviceProfileStatus {
        [cmdletbinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$Id,
    
            [Parameter(Mandatory = $true)]
            [PSCustomObject]$Token
        )
    
        process {
            $headers = @{
                Authorization = "$($Token.token_type) $($Token.access_token)"
            }
    
            $profileSplat = @{
                Method = "Get"
                Uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($Id)?`$expand=deploymentProfile,intendedDeploymentProfile"
                Headers = $headers
            }
    
            $device = Invoke-RestMethod @profileSplat
    
            return $device.deploymentProfileAssignmentStatus
        }
    }

    function Get-DeviceHardwareHash {
        [cmdletbinding()]
        param()
    
        begin {
            $session = New-CimSession
        }
    
        process {
            try {
                $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
                if (-not $devDetail) { throw }
            }
            catch {
                Write-Error "Failed to retrieve the device's hardware hash..."
                return
            }
            $hash = $devDetail.DeviceHardwareData
            return $hash
        }
    
        end {
            Remove-CimSession $session
        }
    }

    function Get-DeviceSerialNumber {
        [cmdletbinding()]
        param()
    
        begin {
            $session = New-CimSession
        }
    
        process {
            $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
            return $serial
        }
    
        end {
            Remove-CimSession $session
        }
    }

    function Get-GraphToken {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory = $true)]
            $ClientId,
    
            [Parameter(Mandatory = $true)]
            $ClientSecret,
    
            [Parameter(Mandatory = $true)]
            $TenantId
        )
    
        process {
            $body = @{
                client_id = $ClientId
                client_secret = $ClientSecret
                grant_type = "client_credentials"
                scope = "https://graph.microsoft.com/.default"
            }
    
            $token = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body
    
            return $token
        }
    }
}

process {
    # If AuthFile is used and exists load it
    if (($AuthFile) -and (Test-Path $AuthFile)) {
        . $AuthFile
    }

    # Grab device identifiers
    $serial = Get-DeviceSerialNumber
    $hash = Get-DeviceHardwareHash

    # Authenticate with Graph for API token
    $token = Get-GraphToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
    if (-not $token.access_token) {
        Write-Host "Failed to obtain MSGraph access token. Check internet access and verify App Id/Secret." -ForegroundColor Red
        Start-Sleep -Seconds 15
    }

    # Check if device has already exists in AutoPilot first. Also if we receive an error
    # during the check it likely means the serial number is null or misformatted and we should
    # attempt to upload with hash only (ie. there were some PC's that had 'Default String' as
    # their serial number)
    try {
        $device = Get-AutoPilotDevice -Serial $serial -Token $token -ErrorAction Stop
        if ($device.value) {
            Write-Host "Device already exists in AutoPilot. Skipping import" -ForegroundColor Green
            exit
        }
    }
    catch {
        Write-Host "Failed to obtain device with serial number '$serial'. Importing with Hardware Hash only." -ForegroundColor Red
        $serial = $null
    }
    
    # Import to AutoPilot
    Write-Host "Importing device to AutoPilot..."
    $post = Add-AutoPilotDevice -HardwareHash $hash -Serial $serial -GroupTag $GroupTag -Token $token

    # Wait for import to complete before proceeding
    Write-Host "Waiting for device to show up in AutoPilot..."
    do {
        Write-Host "..."
        Start-Sleep 10
        $status = Get-AutoPilotDeviceImportStatus -Id $post.Id -Token $token
    } until ($status -notmatch "unknown")

    # Wait for AutoPilot profile to assign to device
    if ($serial) {
        $device = Get-AutoPilotDevice -Serial $serial -Token $token
        
        Write-Host "Waiting for enrollment profile to be assigned..."
        do {
            Write-Host "..."
            Start-Sleep 10
            $status = Get-AutoPilotDeviceProfileStatus -Id $device.value.Id -Token $token
        } until ($status.StartsWith("assigned"))
    }

    Write-Host "Profiles assigned to device." -ForegroundColor Green   
}

