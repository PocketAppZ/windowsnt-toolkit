$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "This script requires administrative privileges to run."
    Write-Warning "Please run PowerShell as an administrator and try again."
    exit
}

Push-Location

$luarocksUrl = 'https://luarocks.org/releases/luarocks-3.11.1-windows-64.zip'
$luaExecUrl = 'https://versaweb.dl.sourceforge.net/project/luabinaries/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip'
$luaLibUrl = 'https://versaweb.dl.sourceforge.net/project/luabinaries/5.1.5/Windows%20Libraries/Dynamic/lua-5.1.5_Win64_dll17_lib.zip'

$installDir = "C:\Program Files\LuaRocks"
$luaExecDir = "C:\Program Files\Lua\5.1"
$luaLibDir = "$luaExecDir\lib"
$luaIncludeDir = "$luaLibDir\include"

function DirectoryIsEmpty {
    param([string]$directory)
    $items = Get-ChildItem -Path $directory -Force
    return ($items.Count -eq 0)
}

function ExecutablesInstalled {
    param([string]$directory)
    $executables = @('lua51.exe', 'luac51.exe')
    foreach ($exe in $executables) {
        $exePath = Join-Path -Path $directory -ChildPath $exe
        if (-not (Test-Path $exePath -PathType Leaf)) {
            return $false
        }
    }
    return $true
}

function DownloadAndExtractWithCurl {
    param([string]$url, [string]$destination)
    
    $uri = New-Object System.Uri($url)
    $downloadedFileName = [System.IO.Path]::GetFileName($uri.LocalPath)
    $downloadedFilePath = Join-Path -Path $destination -ChildPath $downloadedFileName
    
    if (-not (Test-Path $destination -PathType Container)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }
    
    $downloadComplete = $false
    $attempts = 0
    
    do {
        try {
            & curl.exe -L -o $downloadedFilePath --url $url
            $downloadComplete = $true
        }
        catch {
            Write-Error "Failed to download $url. $_"
            $attempts++
            if ($attempts -ge 3) {
                Write-Error "Download failed after 3 attempts. Aborting."
                return
            }
            Start-Sleep -Seconds 5
        }
    } while (-not $downloadComplete)
    
    Start-Sleep -Seconds 1
    
    try {
        Expand-Archive -Path $downloadedFilePath -DestinationPath $destination -Force -ErrorAction Stop
        
        # Check contents after extraction
        $archiveContents = Get-ChildItem -Path (Join-Path -Path $destination -ChildPath "*") -Force
        
        if ($archiveContents.Count -eq 1 -and $archiveContents[0].PSIsContainer) {
            # If there's a single directory, move its contents
            $extractedDir = $archiveContents[0].FullName
            Move-Item -Path "$extractedDir\*" -Destination $destination -Force
        }
        elseif ($archiveContents.Count -eq 1 -and -not $archiveContents[0].PSIsContainer) {
            # If there's a single file, move it directly
            Move-Item -Path $archiveContents[0].FullName -Destination $destination -Force
        }
        else {
            Write-Warning "The extracted archive does not contain a single directory. Please verify the contents manually."
        }
    }
    catch {
        Write-Error "Failed to extract $downloadedFilePath. $_"
        return
    }
    
    Remove-Item -Path $downloadedFilePath -Force
    Write-Output "Successfully extracted to $destination"
}

function RemoveDirectoryIfExists {
    param([string]$dir)
    Write-Output "Attempting to remove directory: $dir"
    if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path $dir)) {
        Write-Output "Removing $dir..."
        Remove-Item -Path $dir -Recurse -Force
    }
    else {
        Write-Output "Directory $dir does not exist or is not accessible."
    }
}

function AddToPathIfNeeded {
    param([string]$pathToAdd)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $paths = $currentPath -split ';'
    if ($paths -notcontains $pathToAdd) {
        Write-Output "Adding $pathToAdd to PATH..."
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$pathToAdd", "Machine")
    }
}

function RemoveFromPath {
    param([string]$pathToRemove)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $paths = $currentPath -split ';'
    $updatedPaths = $paths | Where-Object { $_ -ne $pathToRemove }
    $newPath = ($updatedPaths -join ';')
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
}

$action = Read-Host "Do you want to install or uninstall LuaRocks and Lua 5.1.5? (install/uninstall)"
switch ($action) {
    'install' {
        RemoveDirectoryIfExists -dir $installDir
        RemoveDirectoryIfExists -dir $luaExecDir

        Write-Output "Installing LuaRocks..."
        DownloadAndExtractWithCurl -url $luarocksUrl -destination $installDir

        $sourceDir = Join-Path -Path $installDir -ChildPath "luarocks-3.11.1-windows-64"
        $destinationDir = $installDir
        Move-Item -Path (Join-Path -Path $sourceDir -ChildPath "luarocks.exe") -Destination $destinationDir -Force
        Move-Item -Path (Join-Path -Path $sourceDir -ChildPath "luarocks-admin.exe") -Destination $destinationDir -Force

        Write-Output "Installing Lua 5.1.5 executables..."
        DownloadAndExtractWithCurl -url $luaExecUrl -destination $luaExecDir

        Write-Output "Installing Lua 5.1.5 DLLs and libs..."
        DownloadAndExtractWithCurl -url $luaLibUrl -destination $luaLibDir

        try {
            # system-wide scope
            & "$installDir\luarocks.exe" config lua_version 5.1 --scope=system
            & "$installDir\luarocks.exe" config variables.LUA "$luaExecDir\lua5.1.exe" --scope=system
            & "$installDir\luarocks.exe" config variables.LUA_INCDIR "$luaIncludeDir" --scope=system

            # user scope
            & "$installDir\luarocks.exe" config lua_version 5.1 --scope=user
            & "$installDir\luarocks.exe" config variables.LUA "$luaExecDir\lua5.1.exe" --scope=user
            & "$installDir\luarocks.exe" config variables.LUA_INCDIR "$luaIncludeDir" --scope=user

            Write-Output "LuaRocks configured to use Lua 5.1 at $luaExecDir"
        }
        catch {
            Write-Error "Failed to configure LuaRocks for Lua 5.1. $_"
        }

        AddToPathIfNeeded -pathToAdd $installDir
        AddToPathIfNeeded -pathToAdd $luaExecDir

        Write-Output "LuaRocks and Lua 5.1.5 have been installed and configured successfully."
    }
    'uninstall' {
        RemoveDirectoryIfExists -dir $installDir
        RemoveDirectoryIfExists -dir $luaExecDir
        RemoveDirectoryIfExists -dir $luaLibDir

        RemoveFromPath -pathToRemove $installDir
        RemoveFromPath -pathToRemove $luaExecDir

        Write-Output "LuaRocks and Lua 5.1.5 have been uninstalled successfully."
        Write-Warning "Open a new session to use lua5.1.exe and luarocks."
    }
    default {
        Write-Output "Invalid action specified. Please run the script again and choose 'install' or 'uninstall'."
    }
}

Pop-Location
