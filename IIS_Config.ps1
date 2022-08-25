Install-WindowsFeature -name Web-Server -IncludeManagementTools
Remove-Item  C:\inetpub\wwwroot\iisstart.html
New-Item -ItemType File -Name 'index.html' -Path 'C:\inetpub\wwwroot\'
Add-Content -Path "C:\inetpub\wwwroot\index.html" -Value $("
<!DOCTYPE html>
<html>
    <head>
         <title>IIS MyWebsite Demo</title>
    </head>
    <body>
        <h1>IIS MyWebsite Demo</h1>
        <h2>Hello evrybody from + $env:computername </h2>
    </body>
</html> ")
