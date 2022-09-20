# autopilot-import

Pick an AutoPilot import method.

## Offline Method

1. Set your AutoPilot deployment profile to "Convert all targeted devices to AutoPilot" and save.
2. Run Get-AutoPilotConfigurationFile.ps1 to obtain AutoPilot deployment profile in JSON format. 
3. Copy and paste contents into "Offline Method\AutoPilot.ps1" replacing the contents of $config.
4a. Copy contents of "Offline Method" to root of Windows Installer USB drive.
4b. Create SCCM/MDT task sequence and run script during Specialize pass.
5. Boot installer. Windows should install and run the script to copy over the profile.
6. You will be presented with region select screen when finished and will need to click next to get to the AutoPilot enrollment screen.

## Online Method

1. Create a new AzureAD App
2. Add the following API permissions:
```
Microsoft Graph -> Application Permissions ->
    DeviceManagementConfiguration.ReadWrite.All
    DeviceManagementManagedDevices.ReadWrite.All 
    DeviceManagementServiceConfig.ReadWrite.All
```
3. Grant admin consent for permissions
4. Create a client secret
5. Copy the client ID and Secret values to "Online Method\Auth.ps1" under corresponding variables
6. Copy the tenant ID to "Online Method\Auth.ps1" under corresponding variable
7a. Copy contents of "Online Method" to root of Windows Installer USB drive.
7b. Create SCCM/MDT task sequence and run script during Specialize pass.
8. Boot installer. Windows should install and run the script to upload the device to AutoPilot.
9. You will be presented with the AutoPilot enrollment screen when finished.
