$config = @'
{
    "CloudAssignedTenantId":  "",
    "CloudAssignedAutopilotUpdateTimeout":  1800000,
    "CloudAssignedAutopilotUpdateDisabled":  1,
    "CloudAssignedForcedEnrollment":  1,
    "Version":  2049,
    "Comment_File":  "Profile Hybrid Join AutoPilot",
    "CloudAssignedAadServerData":  "{\"ZeroTouchConfig\":{\"CloudAssignedTenantUpn\":\"\",\"ForcedEnrollment\":1,\"CloudAssignedTenantDomain\":\"\"}}",
    "CloudAssignedOobeConfig":  1310,
    "CloudAssignedDomainJoinMethod":  1,
    "ZtdCorrelationId":  "",
    "CloudAssignedLanguage":  "en-US",
    "CloudAssignedTenantDomain":  ""
}
'@
Out-File -InputObject $config -FilePath $env:windir\Provisioning\Autopilot\AutopilotConfigurationFile.json -Encoding ascii
