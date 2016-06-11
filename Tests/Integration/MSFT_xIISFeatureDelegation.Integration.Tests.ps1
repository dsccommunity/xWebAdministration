
$script:DSCModuleName = 'xWebAdministration'
$script:DSCResourceName = 'MSFT_xIISFeatureDelegation'

#region HEADER

[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
$repoSource = (Get-Module -Name $Global:DSCModuleName -ListAvailable)

# If module was obtained from the gallery install test folder from the gallery instead of cloning from git
if (($null -ne $repoSource) -and ($repoSource[0].RepositorySourceLocation.Host -eq 'www.powershellgallery.com'))
{
    if ( -not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'Tests\DscResourceTestHelper')) )
    {
        $choice = 'y'

        # If user wants to skip prompt - set this environment variale equal to 'true'
        if ($env:getDscTestHelper -ne $true)
        {
            $choice = read-host "In order to run this test you need to install a helper module, continue with installation? (Y/N)"
        }

        if ($choice -eq 'y')
        {
            # Install test folders from gallery
            Save-Module -Name 'DscResourceTestHelper' -Path (Join-Path -Path $moduleRoot -ChildPath 'Tests')
        }

        else 
        {
            Write-Error "Unable to run tests without the required helper module - Exiting test"
            return
        }
        
    }

    $testModuleVer = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath '\Tests\DscResourceTestHelper')
    Import-Module (Join-Path -Path $moduleRoot -ChildPath "Tests\DscResourceTestHelper\$testModuleVer\TestHelper.psm1") -Force
} 
# Otherwise module was cloned from github
else
{
    # Get common tests and test helpers from gitHub rather than installing them from the gallery
    # This ensures that developers always have access to the most recent DscResource.Tests folder 
    $testHelperPath = (Join-Path -Path $moduleRoot -ChildPath '\Tests\DscResource.Tests\DscResourceTestHelper\TestHelper.psm1')
    if (-not (Test-Path -Path $testHelperPath))
    {
        # Clone test folders from gitHub
        $dscResourceTestsPath = Join-Path -Path $moduleRoot -ChildPath '\Tests\DscResource.Tests'
        & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',$dscResourceTestsPath)
        
        # TODO get rid of this section once we update all other resources and merge the gitDependency branch with the main branch on DscResource.Tests
        Push-Location
        Set-Location $dscResourceTestsPath
        & git checkout gitDependency
        Pop-Location
    }

    Import-Module $testHelperPath -Force
}

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

[string] $tempName = "$($script:DSCResourceName)_" + (Get-Date).ToString("yyyyMMdd_HHmmss")

try
{
    # Now that xWebAdministration should be discoverable load the configuration data
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile

    $null = Backup-WebConfiguration -Name $tempName

    Describe "$($script:DSCResourceName)_Integration" {
        # Allow Feature Delegation
        # for this test we are using the anonymous Authentication feature, which is installed by default, but has Feature Delegation set to denied by default
        if ((Get-WindowsOptionalFeature �Online | Where-Object {$_.FeatureName -eq "IIS-Security" -and $_.State -eq "Enabled"}).Count -eq 1)
        {
            if ((Get-WebConfiguration /system.webserver/security/authentication/anonymousAuthentication iis:\).OverrideModeEffective -eq 'Deny')
            {
                It 'Allow Feature Delegation'{
                    {
                        &($script:DSCResourceName + '_AllowDelegation') -OutputPath $TestEnvironment.WorkingFolder
                        Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force
                    } | Should not throw

                    (Get-WebConfiguration /system.webserver/security/authentication/anonymousAuthentication iis:\).OverrideModeEffective  | Should be 'Allow'
                }
            }
        }

        # It 'Deny Feature Delegation' {
        #     {
        #         # this test doesn't really test the resource if it defaultDocument
        #         # is already Deny (not the default)
        #         # well it doesn't test the Set Method, but does test the Test method
        #         # What if the default document module is not installed?

        #         Invoke-Expression -Command "$($script:DSCResourceName)_DenyDelegation -OutputPath `$TestEnvironment.WorkingFolder"
        #         Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force

        #         # Now lets try to add a new default document on site level, this should fail
        #         # get the first site, it doesn't matter which one, it should fail.
        #         $siteName = (Get-ChildItem iis:\sites | Select -First 1).Name
        #         Add-WebConfigurationProperty `
        #             -PSPath "MACHINE/WEBROOT/APPHOST/$siteName" `
        #             -Filter 'system.webServer/defaultDocument/files' `
        #             -Name '.' `
        #             -Value @{Value = 'pesterpage.cgi'}

        #         # remove it again, should also fail, but if both work we at least cleaned it up,
        #         # it would be better to backup and restore the web.config file.
        #         Remove-WebConfigurationProperty  `
        #             -PSPath "MACHINE/WEBROOT/APPHOST/$siteName" `
        #             -Filter 'system.webServer/defaultDocument/files' `
        #             -Name '.' `
        #             -AtElement @{Value = 'pesterpage.cgi'}
        #     } | Should Not Throw
        # }

        It 'Deny Feature Delegation' -test {
        {
            # this test doesn't really test the resource if it defaultDocument
            # is already Deny (not the default)
            # well it doesn't test the Set Method, but does test the Test method
            # What if the default document module is not installed?

            Invoke-Expression -Command "$($script:DSCResourceName)_DenyDelegation -OutputPath `$TestEnvironment.WorkingFolder"
            Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force

            # Now lets try to add a new default document on site level, this should fail
            # get the first site, it doesn't matter which one, it should fail.
            $siteName = (Get-ChildItem iis:\sites | Select-Object -First 1).Name
            Add-WebConfigurationProperty -pspath "MACHINE/WEBROOT/APPHOST/$siteName"  -filter "system.webServer/defaultDocument/files" -name "." -value @{value='pesterpage.cgi'}

            # remove it again, should also fail, but if both work we at least cleaned it up, it would be better to backup and restore the web.config file.
            Remove-WebConfigurationProperty  -pspath "MACHINE/WEBROOT/APPHOST/$siteName"  -filter "system.webServer/defaultDocument/files" -name "." -AtElement @{value='pesterpage.cgi'} } | should throw
        }

        #region DEFAULT TESTS
        # TODO: This will need to be corrected in a future PR.
        # It 'should be able to call Get-DscConfiguration without throwing' {
        #     { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        # }
        #endregion
    }
}
finally
{
    #region FOOTER
    Restore-WebConfiguration -Name $tempName
    Remove-WebConfigurationBackup -Name $tempName

    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
