<#
.Description
This function gets the Application Insights key to be used for storing telemetry

.Functionality
Internal, Hidden
#>
function Get-M365DSCApplicationInsightsTelemetryClient
{
    [CmdletBinding()]
    param()

    if ($null -eq $Global:M365DSCTelemetryEngine)
    {
        $AI = "$PSScriptRoot/../Dependencies/Microsoft.ApplicationInsights.dll"
        [Reflection.Assembly]::LoadFile($AI) | Out-Null

        $InstrumentationKey = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryInstrumentationKey', `
                [System.EnvironmentVariableTarget]::Machine)

        if ($null -eq $InstrumentationKey)
        {
            $InstrumentationKey = 'e670af5d-fd30-4407-a796-8ad30491ea7a'
        }
        $TelClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
        $TelClient.InstrumentationKey = $InstrumentationKey

        $Global:M365DSCTelemetryEngine = $TelClient
    }
    return $Global:M365DSCTelemetryEngine
}

<#
.Description
This function sends telemetry information to Application Insights

.Functionality
Internal
#>
function Add-M365DSCTelemetryEvent
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.String]
        $Type,

        [Parameter()]
        [System.Collections.Generic.Dictionary[[System.String], [System.String]]]
        $Data,

        [Parameter()]
        [System.Collections.Generic.Dictionary[[System.String], [System.Double]]]
        $Metrics
    )
    $TelemetryEnabled = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryEnabled', `
            [System.EnvironmentVariableTarget]::Machine)

    if ($null -eq $TelemetryEnabled -or $TelemetryEnabled -eq $true)
    {
        $TelemetryClient = Get-M365DSCApplicationInsightsTelemetryClient

        try
        {
            $ProjectName = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryProjectName', `
                    [System.EnvironmentVariableTarget]::Machine)

            if ($null -ne $ProjectName)
            {
                $Data.Add('ProjectName', $ProjectName)
            }

            if (-not $Data.ContainsKey('Tenant'))
            {
                if (-not [System.String]::IsNullOrEmpty($Data.Principal))
                {
                    if ($Data.Principal -like '*@*.*')
                    {
                        $principalValue = $Data.Principal.Split('@')[1]
                        $Data.Add('Tenant', $principalValue)
                    }
                }
                elseif (-not [System.String]::IsNullOrEmpty($Data.TenantId))
                {
                    $principalValue = $Data.TenantId
                    $Data.Add('Tenant', $principalValue)
                }
            }

            $Data.Remove('TenandId') | Out-Null
            $Data.Remove('Principal') | Out-Null

            # Capture PowerShell Version Info
            $Data.Add('PSMainVersion', $PSVersionTable.PSVersion.Major.ToString() + '.' + $PSVersionTable.PSVersion.Minor.ToString())
            $Data.Add('PSVersion', $PSVersionTable.PSVersion.ToString())
            $Data.Add('PSEdition', $PSVersionTable.PSEdition.ToString())

            if ($null -ne $PSVersionTable.BuildVersion)
            {
                $Data.Add('PSBuildVersion', $PSVersionTable.BuildVersion.ToString())
            }

            if ($null -ne $PSVersionTable.CLRVersion)
            {
                $Data.Add('PSCLRVersion', $PSVersionTable.CLRVersion.ToString())
            }

            # Capture Console/Host Information
            if ($host.Name -eq 'ConsoleHost' -and $null -eq $env:WT_SESSION)
            {
                $Data.Add('PowerShellAgent', 'Console')
            }
            elseif ($host.Name -eq 'Windows PowerShell ISE Host')
            {
                $Data.Add('PowerShellAgent', 'ISE')
            }
            elseif ($host.Name -eq 'ConsoleHost' -and $null -ne $env:WT_SESSION)
            {
                $Data.Add('PowerShellAgent', 'Windows Terminal')
            }
            elseif ($host.Name -eq 'ConsoleHost' -and $null -eq $env:WT_SESSION -and `
                    $null -ne $env:BUILD_BUILDID -and $env:SYSTEM -eq 'build')
            {
                $Data.Add('PowerShellAgent', 'Azure DevOPS')
                $Data.Add('AzureDevOPSPipelineType', 'Build')
                $Data.Add('AzureDevOPSAgent', $env:POWERSHELL_DISTRIBUTION_CHANNEL)
            }
            elseif ($host.Name -eq 'ConsoleHost' -and $null -eq $env:WT_SESSION -and `
                    $null -ne $env:BUILD_BUILDID -and $env:SYSTEM -eq 'release')
            {
                $Data.Add('PowerShellAgent', 'Azure DevOPS')
                $Data.Add('AzureDevOPSPipelineType', 'Release')
                $Data.Add('AzureDevOPSAgent', $env:POWERSHELL_DISTRIBUTION_CHANNEL)
            }
            elseif ($host.Name -eq 'Default Host' -and `
                    $null -ne $env:APPSETTING_FUNCTIONS_EXTENSION_VERSION)
            {
                $Data.Add('PowerShellAgent', 'Azure Function')
                $Data.Add('AzureFunctionWorkerVersion', $env:FUNCTIONS_WORKER_RUNTIME_VERSION)
            }
            elseif ($host.Name -eq 'CloudShell')
            {
                $Data.Add('PowerShellAgent', 'Cloud Shell')
            }

            if ($null -ne $Data.Resource)
            {
                if ($Data.Resource.StartsWith('MSFT_AAD') -or $Data.Resource.StartsWith('AAD'))
                {
                    $Data.Add('Workload', 'Azure Active Directory')
                }
                elseif ($Data.Resource.StartsWith('MSFT_EXO') -or $Data.Resource.StartsWith('EXO'))
                {
                    $Data.Add('Workload', 'Exchange Online')
                }
                elseif ($Data.Resource.StartsWith('MSFT_Intune') -or $Data.Resource.StartsWith('Intune'))
                {
                    $Data.Add('Workload', 'Intune')
                }
                elseif ($Data.Resource.StartsWith('MSFT_O365') -or $Data.Resource.StartsWith('O365'))
                {
                    $Data.Add('Workload', 'Office 365 Admin')
                }
                elseif ($Data.Resource.StartsWith('MSFT_OD') -or $Data.Resource.StartsWith('OD'))
                {
                    $Data.Add('Workload', 'OneDrive for Business')
                }
                elseif ($Data.Resource.StartsWith('MSFT_Planner') -or $Data.Resource.StartsWith('Planner'))
                {
                    $Data.Add('Workload', 'Planner')
                }
                elseif ($Data.Resource.StartsWith('MSFT_PP') -or $Data.Resource.StartsWith('PP'))
                {
                    $Data.Add('Workload', 'Power Platform')
                }
                elseif ($Data.Resource.StartsWith('MSFT_SC') -or $Data.Resource.StartsWith('SC'))
                {
                    $Data.Add('Workload', 'Security and Compliance Center')
                }
                elseif ($Data.Resource.StartsWith('MSFT_SPO') -or $Data.Resource.StartsWith('SPO'))
                {
                    $Data.Add('Workload', 'SharePoint Online')
                }
                elseif ($Data.Resource.StartsWith('MSFT_Teams') -or $Data.Resource.StartsWith('Teams'))
                {
                    $Data.Add('Workload', 'Teams')
                }
                $Data.Resource = $Data.Resource.Replace('MSFT_', '')
            }

            [array]$version = (Get-Module 'Microsoft365DSC').Version | Sort-Object -Descending
            $Data.Add('M365DSCVersion', $version[0].ToString())

            # OS Version
            try
            {
                if ($null -eq $Global:M365DSCOSInfo)
                {
                    $Global:M365DSCOSInfo = (Get-ComputerInfo -Property OSName -ErrorAction SilentlyContinue).OSName
                }
                $Data.Add('M365DSCOSVersion', $Global:M365DSCOSInfo)
            }
            catch
            {
                Write-Verbose -Message $_
            }

            # LCM Metadata Information
            try
            {
                $LCMInfo = Get-DscLocalConfigurationManager -ErrorAction Stop

                $certificateConfigured = $false
                if (-not [System.String]::IsNullOrEmpty($LCMInfo.CertificateID))
                {
                    $certificateConfigured = $true
                }

                $partialConfiguration = $false
                if (-not [System.String]::IsNullOrEmpty($LCMInfo.PartialConfigurations))
                {
                    $partialConfiguration = $true
                }
                $Data.Add('LCMUsesPartialConfigurations', $partialConfiguration)
                $Data.Add('LCMCertificateConfigured', $certificateConfigured)
                $Data.Add('LCMConfigurationMode', $LCMInfo.ConfigurationMode)
                $Data.Add('LCMConfigurationModeFrequencyMins', $LCMInfo.ConfigurationModeFrequencyMins)
                $Data.Add('LCMRefreshMode', $LCMInfo.RefreshMode)
                $Data.Add('LCMState', $LCMInfo.LCMState)
                $Data.Add('LCMStateDetail', $LCMInfo.LCMStateDetail)

                if ([System.String]::IsNullOrEmpty($Type))
                {
                    if ($Global:M365DSCExportInProgress)
                    {
                        $Type = 'Export'
                    }
                    elseif ($LCMInfo.LCMStateDetail -eq 'LCM is performing a consistency check.' -or `
                            $LCMInfo.LCMStateDetail -eq 'LCM exécute une vérification de cohérence.' -or `
                            $LCMInfo.LCMStateDetail -eq 'LCM führt gerade eine Konsistenzüberprüfung durch.')
                    {
                        $Type = 'MonitoringScheduled'
                    }
                    elseif ($LCMInfo.LCMStateDetail -eq 'LCM is testing node against the configuration.')
                    {
                        $Type = 'MonitoringManual'
                    }
                    elseif ($LCMInfo.LCMStateDetail -eq 'LCM is applying a new configuration.' -or `
                            $LCMInfo.LCMStateDetail -eq 'LCM applique une nouvelle configuration.')
                    {
                        $Type = 'ApplyingConfiguration'
                    }
                    else
                    {
                        $Type = 'Undetermined'
                    }
                }
            }
            catch
            {
                Write-Verbose -Message $_
            }

            $M365DSCTelemetryEventId = (New-GUID).ToString()
            $Data.Add('M365DSCTelemetryEventId', $M365DSCTelemetryEventId)

            if ([System.String]::IsNullOrEMpty($Type))
            {
                if ((-not [System.String]::IsNullOrEmpty($Data.Method) -and $Data.Method -eq 'Export-TargetResource') -or $Global:M365DSCExportInProgress)
                {
                    $Type = 'Export'
                }
            }

            $TelemetryClient.TrackEvent($Type, $Data, $Metrics)
        }
        catch
        {
            try
            {
                $TelemetryClient.TrackEvent('Error', $Data, $Metrics)
            }
            catch
            {
                Write-Error $_
            }
        }
    }
}

<#
.Description
This function configures the telemetry feature of M365DSC

.Parameter Enabled
Enables or disables telemetry collection.

.Parameter InstrumentationKey
Specifies the Instrumention Key to be used to send the telemetry to.

.Parameter ProjectName
Specifies the name of the project to store the telemetry data under.

.Example
Set-M365DSCTelemetryOption -Enabled $false

.Functionality
Public
#>
function Set-M365DSCTelemetryOption
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.Boolean]
        $Enabled,

        [Parameter()]
        [System.String]
        $InstrumentationKey,

        [Parameter()]
        [System.String]
        $ProjectName
    )

    if ($null -ne $Enabled)
    {
        [System.Environment]::SetEnvironmentVariable('M365DSCTelemetryEnabled', $Enabled, `
                [System.EnvironmentVariableTarget]::Machine)
    }

    if ($null -ne $InstrumentationKey)
    {
        [System.Environment]::SetEnvironmentVariable('M365DSCTelemetryInstrumentationKey', $InstrumentationKey, `
                [System.EnvironmentVariableTarget]::Machine)
    }

    if ($null -ne $ProjectName)
    {
        [System.Environment]::SetEnvironmentVariable('M365DSCTelemetryProjectName', $ProjectName, `
                [System.EnvironmentVariableTarget]::Machine)
    }
}

<#
.Description
This function gets the configuration for the M365DSC telemetry feature

.Example
Get-M365DSCTelemetryOption

.Functionality
Public
#>
function Get-M365DSCTelemetryOption
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    try
    {
        return @{
            Enabled            = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryEnabled', `
                    [System.EnvironmentVariableTarget]::Machine)
            InstrumentationKey = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryInstrumentationKey', `
                    [System.EnvironmentVariableTarget]::Machine)
            ProjectName        = [System.Environment]::GetEnvironmentVariable('M365DSCTelemetryProjectName', `
                    [System.EnvironmentVariableTarget]::Machine)
        }
    }
    catch
    {
        throw $_
    }
}

<#
.Description
This function converts the data which is send to Application Insights to the correct format.

.Functionality
Internal
#>
function Format-M365DSCTelemetryParameters
{
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory = $true)]
        [System.String]
        $ResourceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $CommandName,

        [parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Parameters
    )
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()

    try
    {
        $data.Add('Resource', $ResourceName)
        $data.Add('Method', $CommandName)
        if ($Parameters.Credential)
        {
            try
            {
                $data.Add('Principal', $Parameters.Credential.UserName)
                $data.Add('Tenant', $Parameters.Credential.UserName.Split('@')[1])
            }
            catch
            {
                Write-Verbose -Message $_
            }
        }
        elseif ($Parameters.ApplicationId)
        {
            $data.Add('Principal', $Parameters.ApplicationId)
            $data.Add('Tenant', $Parameters.TenantId)
        }
        elseif (-not [System.String]::IsNullOrEmpty($TenantId))
        {
            $data.Add('Tenant', $Parameters.TenantId)
        }
        $data.Add('ConnectionMode', (Get-M365DSCAuthenticationMode -Parameters $Parameters))
    }
    catch
    {
        Write-Verbose -Message $_
    }
    return $data
}

Export-ModuleMember -Function @(
    'Add-M365DSCTelemetryEvent',
    'Format-M365DSCTelemetryParameters',
    'Get-M365DSCTelemetryOption',
    'Set-M365DSCTelemetryOption'
)
