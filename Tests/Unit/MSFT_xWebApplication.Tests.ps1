﻿$Global:DSCModuleName = 'xWebAdministration'
$Global:DSCResourceName = 'MSFT_xWebApplication'

#region HEADER
if ( (-not (Test-Path -Path '.\DSCResource.Tests\')) -or `
     (-not (Test-Path -Path '.\DSCResource.Tests\TestHelper.psm1')) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git')
}
else
{
    & git @('-C',(Join-Path -Path (Get-Location) -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module .\DSCResource.Tests\TestHelper.psm1 -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit
#endregion

try
{
    InModuleScope -ModuleName $global:DSCResourceName -ScriptBlock {
        
        $MockParameters = @{
            Website                  = 'MockSite'
            Name                     = 'MockApp'
            WebAppPool               = 'MockPool'
            PhysicalPath             = 'C:\MockSite\MockApp'
            SSlFlags                 = 'Ssl'
            PreloadEnabled           = 'True'
            ServiceAutoStartProvider = 'MockServiceAutoStartProvider'
            ServiceAutoStartEnabled  = 'True'
            ApplicationType          = 'MockApplicationType'
        }

        $GetWebConfigurationOutput = @(
                @{
                    SectionPath = 'MockSectionPath'
                    PSPath      = 'MockPSPath'
                    sslFlags    = 'ssl'
                    Collection  = @(
                                [PSCustomObject]@{Name = 'MockServiceAutoStartProvider' ;Type = 'MockApplicationType'}   
                    )
                }
            )

        Describe "$Global:DSCResourceName\CheckDependencies" {
            
            Context 'WebAdminstration module is not installed' {
                Mock -CommandName Get-Module -MockWith {
                    return $null
                }

                It 'should throw an error' {
                    {
                        CheckDependencies
                    } | Should Throw 'Please ensure that WebAdministration module is installed.'
                }
            }
        }

        Describe "$Global:DSCResourceName\Get-TargetResource" {

        function Get-WebApplication {}
        function Get-WebConfiguration {}
        function Get-WebConfigurationProperty {}

            Context 'Absent should return correctly' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return $null
                }

                Mock -CommandName Get-WebConfiguration -MockWith {$GetWebConfigurationOutput}

                It 'should return Absent' {
                    $Result = Get-TargetResource @MockParameters
                    $Result.Ensure | Should Be 'Absent'
                }
            }

            Context 'Present should return correctly' {
                
                Mock -CommandName Get-WebConfiguration -MockWith {$GetWebConfigurationOutput}

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = $MockParameters.PhysicalPath
                        SslFlags                 = $MockParameters.SslFlags
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        Count = 1
                    }
                }

                It 'should return Present' {
                    $Result = Get-TargetResource @MockParameters
                    $Result.Ensure | Should Be 'Present'
                }
            }
        }

        Describe "how $Global:DSCResourceName\Test-TargetResource responds to Ensure = 'Absent'" {
            
            function Get-WebApplication {}
            function Get-WebConfiguration {}

            Context 'Web Application does not exist' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return $null
                }

                It 'should return True' {
                    $Result = Test-TargetResource -Ensure 'Absent' @MockParameters
                    $Result | Should Be $true
                }

            }

            Context 'Web Application exists' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return @{Count = 1}
                }

                It 'should return False' {
                    $Result = Test-TargetResource -Ensure 'Absent' @MockParameters
                    $Result | Should Be $false
                }
            }
        }

        Describe "how $Global:DSCResourceName\Test-TargetResource responds to Ensure = 'Present'" {
            
            function Get-WebApplication {}
            function Get-WebConfiguration {}
            Function Get-WebConfigurationProperty {}

            Context 'Web Application does not exist' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return $null
                }

                It 'should return False' {
                    $Result = Test-TargetResource -Ensure 'Present' @MockParameters
                    $Result | Should Be $false
                }
            }

            Context 'Web Application exists and is in the desired state' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = $MockParameters.PhysicalPath
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }

                Mock Get-WebConfiguration -MockWith { $GetWebConfigurationOutput }

                It 'should return True' {
                    $Result = Test-TargetResource -Ensure 'Present' @MockParameters
                    $Result | Should Be $true
                }
            }

            Context 'Web Application exists but has a different WebAppPool' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = 'MockPoolOther'
                        PhysicalPath             = $MockParameters.PhysicalPath
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }

                It 'should return False' {
                    $Result = Test-TargetResource -Ensure 'Present' @MockParameters
                    $Result | Should Be $False
                }
            }

            Context 'Web Application exists but has a different PhysicalPath' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = 'C:\MockSite\MockAppOther'
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        Count = 1
                    }
                }

                It 'should return False' {
                    $Result = Test-TargetResource -Ensure 'Present' @MockParameters
                    $Result | Should Be $False
                }
            }

            Context 'Check Preload is different' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = $MockParameters.PhysicalPath
                        PreloadEnabled           = 'false'
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        Count = 1
                        }
                    }

                $Result = Test-TargetResource -Ensure 'Present' @MockParameters

                It 'should return False' {
                    $Result | Should Be $false
                }

            }

            Context 'Check ServiceAutoStartEnabled is different' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = $MockParameters.PhysicalPath
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ServiceAutoStartEnabled  = 'false'
                        Count = 1
                        }
                    }

                $Result = Test-TargetResource -Ensure 'Present' @MockParameters

                It 'should return False' {
                    $Result | Should Be $false
                }

            }
            
            Context 'Check ServiceAutoStartProvider is different' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = $MockParameters.PhysicalPath
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled
                        ServiceAutoStartProvider = 'ServiceAutoStartProviderOther'
                        ApplicationType          = 'ApplicationTypeOther'
                        Count = 1
                        }
                    }

                

                $Result = Test-TargetResource -Ensure 'Present' @MockParameters

                It 'should return False' {
                    $Result | Should Be $false
                }

            }     
            
        }

        Describe "how $Global:DSCResourceName\Set-TargetResource responds to Ensure = 'Absent'" {
            
            function Remove-WebApplication {}
            function Get-WebConfiguration {}
            function Get-WebConfigurationProperty {}
            function Set-WebConfigurationProperty {}

            
            Context 'Web Application exists' {
                Mock -CommandName Remove-WebApplication

                It 'should call expected mocks' {
                    $Result = Set-TargetResource -Ensure 'Absent' @MockParameters
                    Assert-MockCalled -CommandName Remove-WebApplication -Exactly 1
                }
            }
        }

        Describe "how $Global:DSCResourceName\Set-TargetResource responds to Ensure = 'Present'" {
            
            function Remove-WebApplication {}
            function Get-WebConfiguration {}
            function Get-WebConfigurationProperty {}
            function Set-WebConfigurationProperty {}
            function Get-WebApplication {}
            function Set-WebConfiguration {}
            Function New-WebApplication {}
            Function Set-ItemProperty {}
            Function Add-WebConfiguration {}
                        
            Context 'Web Application does not exist' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return $null
                }

                Mock -CommandName New-WebApplication
                Mock -CommandName Set-ItemProperty
                Mock -CommandName Add-WebConfiguration
                #Mock -CommandName Confirm-UniqueServiceAutoStartProviders {return $false}

                It 'should call expected mocks' {
                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters
                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName New-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-ItemProperty -Exactly 3
                    Assert-MockCalled -CommandName Add-WebConfiguration -Exactly 1
                    #Assert-MockCalled -CommandName Confirm-UniqueServiceAutoStartProviders -Exactly 1
                }
            }

            Context 'Web Application exists but has a different WebAppPool' {
                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = 'MockPoolOther'
                        PhysicalPath             = $MockParameters.PhysicalPath
                        ItemXPath                = ("/system.applicationHost/sites/site[@name='{0}']/application[@path='/{1}']" -f $MockParameters.Website, $MockParameters.Name)
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }

                Mock -CommandName Set-WebConfigurationProperty
                Mock -CommandName Set-ItemProperty

                It 'should call expected mocks' {
                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters

                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-WebConfigurationProperty -Exactly 1
                }

            }

            Context 'Web Application exists but has a different PhysicalPath' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             = 'C:\MockSite\MockAppOther'
                        ItemXPath                = ("/system.applicationHost/sites/site[@name='{0}']/application[@path='/{1}']" -f $MockParameters.Website, $MockParameters.Name)
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }

                Mock -CommandName Set-WebConfigurationProperty
                Mock -CommandName Add-WebConfiguration

                It 'should call expected mocks' {

                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters

                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-WebConfigurationProperty -Exactly 1
                }
            }

            Context 'Web Application exists but has Preload not set' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             =  $MockParameters.PhysicalPath
                        ItemXPath                = ("/system.applicationHost/sites/site[@name='{0}']/application[@path='/{1}']" -f $MockParameters.Website, $MockParameters.Name)
                        PreloadEnabled           = 'false'
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }

                Mock -CommandName Set-WebConfigurationProperty
                Mock -CommandName Set-ItemProperty

                It 'should call expected mocks' {

                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters

                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-ItemProperty -Exactly 1
                }
            }

            Context 'Web Application exists but has ServiceAutoStartEnabled not set' {

                Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             =  $MockParameters.PhysicalPath
                        ItemXPath                = ("/system.applicationHost/sites/site[@name='{0}']/application[@path='/{1}']" -f $MockParameters.Website, $MockParameters.Name)
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = 'false'
                        ServiceAutoStartProvider = $MockParameters.ServiceAutoStartProvider    
                        ApplicationType          = $MockParameters.ApplicationType
                        Count = 1
                    }
                }



                Mock -CommandName Set-WebConfigurationProperty
                Mock -CommandName Set-ItemProperty

                It 'should call expected mocks' {

                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters

                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-ItemProperty -Exactly 1
                }
            }

            Context 'Web Application exists but has different ServiceAutoStartProvider' {

                
                $GetWebConfigurationOutput = @(
                    @{
                        SectionPath = 'MockSectionPath'
                        PSPath      = 'MockPSPath'
                        Collection  = @(
                                    [PSCustomObject]@{Name = 'OtherMockServiceAutoStartProvider' ;Type = 'OtherMockApplicationType'}   
                        )
                    }
                )

               Mock -CommandName Get-WebApplication -MockWith {
                    return @{
                        ApplicationPool          = $MockParameters.WebAppPool
                        PhysicalPath             =  $MockParameters.PhysicalPath
                        ItemXPath                = ("/system.applicationHost/sites/site[@name='{0}']/application[@path='/{1}']" -f $MockParameters.Website, $MockParameters.Name)
                        PreloadEnabled           = $MockParameters.PreloadEnabled
                        ServiceAutoStartEnabled  = $MockParameters.ServiceAutoStartEnabled 
                        ServiceAutoStartProvider = 'OtherServiceAutoStartProvider'
                        ApplicationType          = 'OtherApplicationType'
                        
                        Count = 1
                    }
                }
                Mock -CommandName Get-WebConfiguration -MockWith {return $GetWebConfigurationOutput}
                Mock -CommandName Set-ItemProperty
                Mock -CommandName Add-WebConfiguration
                
                It 'should call expected mocks' {

                    $Result = Set-TargetResource -Ensure 'Present' @MockParameters

                    Assert-MockCalled -CommandName Get-WebApplication -Exactly 1
                    Assert-MockCalled -CommandName Set-ItemProperty -Exactly 1
                    Assert-MockCalled -CommandName Add-WebConfiguration -Exactly 1
                }
            
            }
        
        }
      
        Describe "$Global:DSCResourceName\Confirm-UniqueServiceAutoStartProviders" {
            
            Function Get-WebConfiguration {}

            $MockParameters = @{
                Name = 'MockServiceAutoStartProvider'
                Type = 'MockApplicationType'
            }

            Context 'Expected behavior' {

                $GetWebConfigurationOutput = @(
                    @{
                        SectionPath = 'MockSectionPath'
                        PSPath      = 'MockPSPath'
                        Collection  = @(
                                   [PSCustomObject]@{Name = 'MockServiceAutoStartProvider' ;Type = 'MockApplicationType'}   
                        )
                    }
                )

                Mock -CommandName Get-WebConfiguration -MockWith {return $GetWebConfigurationOutput}

                It 'should not throw an error' {
                    {Confirm-UniqueServiceAutoStartProviders -ServiceAutoStartProvider $MockParameters.Name -ApplicationType 'MockApplicationType'} |
                    Should Not Throw
                }

                It 'should call Get-WebConfiguration once' {
                    Assert-MockCalled -CommandName Get-WebConfiguration -Exactly 1
                }

            }

            Context 'Conflicting Global Property' {
                                     
                $GetWebConfigurationOutput = @(
                    @{
                        SectionPath = 'MockSectionPath'
                        PSPath      = 'MockPSPath'
                        Collection  = @(
                                   [PSCustomObject]@{Name = 'MockServiceAutoStartProvider' ;Type = 'MockApplicationType'}   
                        )
                    }
                )

                Mock -CommandName Get-WebConfiguration -MockWith {return $GetWebConfigurationOutput}

                It 'should return Throw' {

                $ErrorId = 'ServiceAutoStartProviderFailure'
                $ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $ErrorMessage = $LocalizedData.ErrorWebsiteTestAutoStartProviderFailure, 'ScriptHalted'
                $Exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $ErrorMessage
                $ErrorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $Exception, $ErrorId, $ErrorCategory, $null

                {Confirm-UniqueServiceAutoStartProviders -ServiceAutoStartProvider $MockParameters.Name -ApplicationType 'MockApplicationType2'} |
                Should Throw $ErrorRecord
                }

            }

            Context 'ServiceAutoStartProvider does not exist' {

                $GetWebConfigurationOutput = @(
                    @{
                        Name = ''
                        Type = ''
                        
                    }
                )

                Mock -CommandName Get-WebConfiguration  -MockWith {return $GetWebConfigurationOutput}

                It 'should return False' {
                    Confirm-UniqueServiceAutoStartProviders -ServiceAutoStartProvider $MockParameters.Name -ApplicationType  'MockApplicationType' |
                    Should Be $false
                }

            }

            Context 'ServiceAutoStartProvider does exist' {

                $GetWebConfigurationOutput = @(
                    @{
                        SectionPath = 'MockSectionPath'
                        PSPath      = 'MockPSPath'
                        Collection  = @(
                                   [PSCustomObject]@{Name = 'MockServiceAutoStartProvider' ;Type = 'MockApplicationType'}   
                        )
                    }
                )
                
                Mock -CommandName Get-WebConfiguration -MockWith {return $GetWebConfigurationOutput}

                It 'should return True' {
                    Confirm-UniqueServiceAutoStartProviders -ServiceAutoStartProvider $MockParameters.Name -ApplicationType  'MockApplicationType' |
                    Should Be $true
                }

            }

        } 

        Describe "$Global:DSCResourceName\Get-AuthenticationInfo" {
           
           function Get-WebConfigurationProperty {}

            Context 'Expected behavior' {

                Mock -CommandName Get-WebConfigurationProperty -MockWith { return 'False'}

                It 'should not throw an error' {
                    { Get-AuthenticationInfo -site $MockParameters.Website -name $MockParameters.Name } |
                    Should Not Throw
                }

                It 'should call Get-WebConfigurationProperty four times' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 4
                }
            }

            Context 'AuthenticationInfo is false' {

                $GetWebConfigurationOutput = @(
                    @{
                        Value = 'False'
                    }
                )

                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}

                
                It 'should all be false' {
                    $result = Get-AuthenticationInfo -site $MockParameters.Website -name $MockParameters.Name 
                    $result.Anonymous | Should be False
                    $result.Digest | Should be False
                    $result.Basic | Should be False
                    $result.Windows | Should be False
                }

                It 'should call Get-WebConfigurationProperty four times' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 4
                }
            }

            Context 'AuthenticationInfo is true' {
                
                $GetWebConfigurationOutput = @(
                    @{
                        Value = 'True'
                    }
                )
                
                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}
     
                It 'should all be true' {
                    $result = Get-AuthenticationInfo -site $MockParameters.Website -name $MockParameters.Name 
                    $result.Anonymous | Should be True
                    $result.Digest | Should be True
                    $result.Basic | Should be True
                    $result.Windows | Should be True
                }

                It 'should call Get-WebConfigurationProperty four times' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 4
                }
            }
        }

        Describe "$Global:DSCResourceName\Get-DefaultAuthenticationInfo" {
       
            Context 'Expected behavior' {

                It 'should not throw an error' {
                    { Get-DefaultAuthenticationInfo }|
                    Should Not Throw
                }

            }
           
            Context 'Get-DefaultAuthenticationInfo should produce a false CimInstance' {
               
                It 'should all be false' {
                    $result = Get-DefaultAuthenticationInfo
                    $result.Anonymous | Should be False
                    $result.Digest | Should be False
                    $result.Basic | Should be False
                    $result.Windows | Should be False
                }
            }           
        }

        Describe "$Global:DSCResourceName\Get-SslFlags" {
        function Get-WebConfiguration {}
         
            Context 'Expected behavior' {

                Mock -CommandName Get-WebConfiguration -MockWith {$GetWebConfigurationOutput}

                It 'should not throw an error' {
                    { Get-SslFlags -Location (${MockParameters}.Website + '\' + ${MockParameters}.Name) }|
                    Should Not Throw
                }

                It 'should call Get-WebConfiguration once' {
                    Assert-MockCalled -CommandName Get-WebConfiguration -Exactly 1
                }

            }

            Context 'SslFlags do not exist' {

                Mock -CommandName Get-WebConfiguration -MockWith {return ''}

                It 'should return nothing' {
                    Get-SslFlags -Location (${MockParameters}.Website + '\' + ${MockParameters}.Name) |
                    Should BeNullOrEmpty
                }

            }

            Context 'SslFlags do exist' {
                
                Mock -CommandName Get-WebConfiguration -MockWith {$GetWebConfigurationOutput}

                It 'should return SslFlags' {
                    Get-SslFlags -Location (${MockParameters}.Website + '\' + ${MockParameters}.Name) |
                    Should Be 'Ssl'
                }
            }
        }

        Describe "$Global:DSCResourceName\Set-Authentication" {

        Context 'Expected behavior' {
            Function Set-WebConfigurationProperty {}

            Mock -CommandName Set-WebConfigurationProperty

            It 'should not throw an error' {
                    { Set-Authentication -Site $MockParameters.Website -Name $MockParameters.Name -Type Basic -Enabled $true }|
                    Should Not Throw
                }

            It 'should call Set-WebConfigurationProperty once' {
                    Assert-MockCalled -CommandName Set-WebConfigurationProperty -Exactly 1
                }    
            }
        }

        Describe "$Global:DSCResourceName\Set-AuthenticationInfo" {
        
        Context 'Expected behavior' {
            Function Set-WebConfigurationProperty {}

            Mock -CommandName Set-WebConfigurationProperty

            $AuthenticationInfo = New-CimInstance -ClassName MSFT_xWebApplicationAuthenticationInformation `
                                                  -ClientOnly `
                                                  -Property @{Anonymous='true';Basic='false';Digest='false';Windows='false'}

            It 'should not throw an error' {
                    { Set-AuthenticationInfo  -Site $MockParameters.Website -Name $MockParameters.Name -AuthenticationInfo $AuthenticationInfo }|
                    Should Not Throw
                }

            It 'should call should call expected mocks' {
                    Assert-MockCalled -CommandName Set-WebConfigurationProperty -Exactly 4
                }    
            }       
        }
        
        Describe "$Global:DSCResourceName\Test-AuthenticationEnabled" {
        
        Context 'Expected behavior' {

            $GetWebConfigurationOutput = @(
                    @{
                        Value = 'False'
                    }
                )
            Function Get-WebConfigurationProperty {}

            Mock -CommandName Get-WebConfigurationProperty -MockWith {$GetWebConfigurationOutput}

            It 'should not throw an error' {
                    { Test-AuthenticationEnabled  -Site $MockParameters.Website -Name $MockParameters.Name -Type 'Basic'}|
                    Should Not Throw
                }

            It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 1
                }    
            }

        Context 'AuthenticationInfo is false' {

                $GetWebConfigurationOutput = @(
                    @{
                        Value = 'False'
                    }
                )

                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}

                
                It 'should return false' {
                    Test-AuthenticationEnabled -site $MockParameters.Website -name $MockParameters.Name -Type 'Basic' | Should be False
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 1
                }
            }

        Context 'AuthenticationInfo is true' {
                
                $GetWebConfigurationOutput = @(
                    @{
                        Value = 'True'
                    }
                )
                
                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}
     
                It 'should all be true' {
                    Test-AuthenticationEnabled -site $MockParameters.Website -name $MockParameters.Name -Type 'Basic' | Should be True
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 1
                }
            }   
        }
        
        Describe "$Global:DSCResourceName\Test-AuthenticationInfo" {

        Function Get-WebConfigurationProperty {}

        Mock -CommandName Get-WebConfigurationProperty -MockWith {$GetWebConfigurationOutput}

        $GetWebConfigurationOutput = @(
                    @{
                        Value = 'False'
                    }
                )

        $AuthenticationInfo = New-CimInstance -ClassName MSFT_xWebApplicationAuthenticationInformation `
                                    -ClientOnly `
                                    -Property @{Anonymous='false';Basic='true';Digest='false';Windows='false'}
        
        Context 'Expected behavior' {


            It 'should not throw an error' {
                    { Test-AuthenticationInfo  -Site $MockParameters.Website -Name $MockParameters.Name -AuthenticationInfo $AuthenticationInfo }|
                    Should Not Throw
                }

            It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 2
                }    
            }

        Context 'Return False when AuthenticationInfo is not correct' {

                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}

                
                It 'should return false' {
                    Test-AuthenticationInfo -site $MockParameters.Website -name $MockParameters.Name -AuthenticationInfo $AuthenticationInfo | Should be False
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 2
                }
            }

        Context 'Return True when AuthenticationInfo is correct' {
                
                $GetWebConfigurationOutput = @(
                    @{
                        Value = 'True'
                    }
                )
      
                $AuthenticationInfo = New-CimInstance -ClassName MSFT_xWebApplicationAuthenticationInformation `
                                    -ClientOnly `
                                    -Property @{Anonymous='true';Basic='true';Digest='true';Windows='true'}
                
                Mock -CommandName Get-WebConfigurationProperty -MockWith { $GetWebConfigurationOutput}
     
                It 'should return true' {
                    Test-AuthenticationInfo -site $MockParameters.Website -name $MockParameters.Name -AuthenticationInfo $AuthenticationInfo | Should be True
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Get-WebConfigurationProperty -Exactly 4
                }
            }     
        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
