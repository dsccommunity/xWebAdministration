Configuration Sample_xWebSiteAlive_ExpectedContent
{
    Import-DscResource -Module xWebAdministration
    
    xWebsite DefaultWebSite
    {
        Ensure       = 'Present'
        Name         = 'Default Web Site'
        State        = 'Started'
    }

    xWebSiteAlive WebSiteAlive
    {
        WebSiteName      = 'Default Web Site'
        RelativeUrl      = '/iisstart.htm'
        ValidStatusCodes = @(200)
        ExpectedContent  = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title>IIS Windows Server</title>
<style type="text/css">
<!--
body {
    color:#000000;
    background-color:#0072C6;
    margin:0;
}

#container {
    margin-left:auto;
    margin-right:auto;
    text-align:center;
    }

a img {
    border:none;
}

-->
</style>
</head>
<body>
<div id="container">
<a href="http://go.microsoft.com/fwlink/?linkid=66138&amp;clcid=0x409"><img src="iisstart.png" alt="IIS" width="960" height="600" /></a>
</div>
</body>
</html>
'@
    }
}
