Install-WindowsFeature -name Web-Server -IncludeManagementTools
Remove-Item  C:\inetpub\wwwroot\iisstart.htm
Add-Content -Path "C:\inetpub\wwwroot\iisstart.htm" -Value $("Hello evrybody from " + $env:computername)