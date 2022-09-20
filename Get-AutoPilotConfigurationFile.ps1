
$module = Get-Module -ListAvailable -Name AzureAD
if (-not $module) {
    Install-Module AzureAD
}
$module = Get-Module -ListAvailable -Name Microsoft.Graph.Intune
if (-not $module) {
    Install-Module Microsoft.Graph.Intune
}
$module = Get-Module -ListAvailable -Name WindowsAutoPilotIntune
if (-not $module) {
    Install-Module WindowsAutopilotIntune
}

Import-Module AzureAD
Import-Module Microsoft.Graph.Intune
Import-Module WindowsAutopilotIntune

Connect-MSGraph
$AutopilotProfile = Get-AutopilotProfile
$AutopilotProfile | ForEach-Object {
  $_ | ConvertTo-AutopilotConfigurationJSON | Set-Content -Encoding Ascii "$PSScriptRoot\$($_.displayName).json"
}