if($env:OS -ne 'Windows_NT'){Write-Host "This script is designed to run on Windows NT-based operating systems.";exit}

$regPath="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if(Test-Path $regPath){Remove-Item $regPath -Recurse;Write-Host "Legacy context menu disabled."}else{New-Item -Path $regPath -Force|Out-Null;Set-ItemProperty -Path $regPath -Name "(Default)" -Value "" -Type String;Write-Host "Legacy context menu enabled."}

Stop-Process -Name explorer -Force
Start-Sleep -Milliseconds 500
if(-not (Get-Process 'explorer' -ErrorAction SilentlyContinue)){Start-Process explorer}
