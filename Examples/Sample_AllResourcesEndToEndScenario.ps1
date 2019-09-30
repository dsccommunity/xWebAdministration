### All resources (end-to-end scenario)

```powershell
# End to end sample for xWebAdministration

configuration Sample_EndToEndxWebAdministration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration

    Node $AllNodes.NodeName
    {
        # Create a Web Application Pool
        xWebAppPool NewWebAppPool
        {
            Name   = $Node.WebAppPoolName
            Ensure = "Present"
            State  = "Started"
        }

        #Create physical path website
        File NewWebsitePath
        {
            DestinationPath = $Node.PhysicalPathWebSite
            Type = "Directory"
            Ensure = "Present"
        }

        #Create physical path web application
        File NewWebApplicationPath
        {
            DestinationPath = $Node.PhysicalPathWebApplication
            Type = "Directory"
            Ensure = "Present"
        }

        #Create physical path virtual directory
        File NewVirtualDirectoryPath
        {
            DestinationPath = $Node.PhysicalPathVirtualDir
            Type = "Directory"
            Ensure = "Present"
        }

        #Create a New Website with Port
        xWebSite NewWebSite
        {
            Name   = $Node.WebSiteName
            Ensure = "Present"
            BindingInfo = MSFT_xWebBindingInformation
            {
                Protocol = "http"
                Port = $Node.Port
            }

            PhysicalPath = $Node.PhysicalPathWebSite
            State = "Started"
            DependsOn = @("[xWebAppPool]NewWebAppPool","[File]NewWebsitePath")
        }

        #Create a new Web Application
        xWebApplication NewWebApplication
        {
            Name = $Node.WebApplicationName
            Website = $Node.WebSiteName
            WebAppPool =  $Node.WebAppPoolName
            PhysicalPath = $Node.PhysicalPathWebApplication
            Ensure = "Present"
            DependsOn = @("[xWebSite]NewWebSite","[File]NewWebApplicationPath")
        }

        #Create a new virtual Directory
        xWebVirtualDirectory NewVirtualDir
        {
            Name = $Node.WebVirtualDirectoryName
            Website = $Node.WebSiteName
            WebApplication =  $Node.WebApplicationName
            PhysicalPath = $Node.PhysicalPathVirtualDir
            Ensure = "Present"
            DependsOn = @("[xWebApplication]NewWebApplication","[File]NewVirtualDirectoryPath")
        }

        #Create an empty web.config file
        File CreateWebConfig
        {
             DestinationPath = $Node.PhysicalPathWebSite + "\web.config"
             Contents = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>
                            <configuration>
                            </configuration>"
                    Ensure = "Present"
             DependsOn = @("[xWebVirtualDirectory]NewVirtualDir")
        }

        #Add an appSetting key1
        xWebConfigKeyValue ModifyWebConfig
        {
            Ensure = "Present"
            ConfigSection = "AppSettings"
            Key = "key1"
            Value = "value1"
            IsAttribute = $false
            WebsitePath = "IIS:\sites\" + $Node.WebsiteName
            DependsOn = @("[File]CreateWebConfig")
        }

        #Add a webApplicationHandler
        WebApplicationHandler WebHandlerTest
        {
            PSPath               = $Node.PSPath
            Name                 = 'ATest-WebHandler'
            Path                 = '*'
            Verb                 = '*'
            Modules              = 'IsapiModule'
            RequireAccess        = 'None'
            ScriptProcessor      = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll"
            ResourceType         = 'Unspecified'
            AllowPathInfo        = $false
            ResponseBufferLimit  = 0
            PhysicalPath         = $Node.PhysicalPathWebApplication
            Type                 = $null
            PreCondition         = $null
            Location             = 'Default Web Site/TestDir
    }
    }
}

#You can place the below in another file to create multiple websites using the same configuration block.
$Config = @{
    AllNodes = @(
        @{
            NodeName = "localhost";
            WebAppPoolName = "TestAppPool";
            WebSiteName = "TestWebSite";
            PhysicalPathWebSite = "C:\web\webSite";
            WebApplicationName = "TestWebApplication";
            PhysicalPathWebApplication = "C:\web\webApplication";
            WebVirtualDirectoryName = "TestVirtualDir";
            PhysicalPathVirtualDir = "C:\web\virtualDir";
            Port = 100
        }
    )
}

Sample_EndToEndxWebAdministration -ConfigurationData $config
Start-DscConfiguration ./Sample_EndToEndxWebAdministration -wait -Verbose
```

```powershell
configuration Sample_IISServerDefaults
{
    param
    (
        # Target nodes to apply the configuration
        [string[]]$NodeName = 'localhost'
    )

    # Import the module that defines custom resources
    Import-DscResource -Module xWebAdministration, PSDesiredStateConfiguration

    Node $NodeName
    {
         xWebSiteDefaults SiteDefaults
         {
            ApplyTo = 'Machine'
            LogFormat = 'IIS'
            LogTargetW3C = 'File,ETW'
            AllowSubDirConfig = 'true'
         }


         xWebAppPoolDefaults PoolDefaults
         {
            ApplyTo = 'Machine'
            ManagedRuntimeVersion = 'v4.0'
            IdentityType = 'ApplicationPoolIdentity'
         }
    }
}
```