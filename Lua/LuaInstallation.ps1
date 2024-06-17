# URLs for downloads
$luarocksUrl = 'https://luarocks.org/releases/luarocks-3.11.1-windows-64.zip'
$luaExecUrl = 'https://versaweb.dl.sourceforge.net/project/luabinaries/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip'
$luaLibUrl = 'https://versaweb.dl.sourceforge.net/project/luabinaries/5.1.5/Windows%20Libraries/Dynamic/lua-5.1.5_Win64_dll17_lib.zip'

# Destination directories
$installDir = "C:\Program Files\LuaRocks"
$luaExecDir = "C:\Program Files\Lua\5.1"
$luaLibDir = "C:\Program Files\Lua\5.1"

# Function to check if directory is empty
function DirectoryIsEmpty {
    param(
        [string]$directory
    )
    $items = Get-ChildItem -Path $directory -Force
    return ($items.Count -eq 0)
}

# Function to check if executables are installed
function ExecutablesInstalled {
    param(
        [string]$directory
    )
    $executables = @('lua51.exe', 'luac51.exe')
    
    foreach ($exe in $executables) {
        $exePath = Join-Path -Path $directory -ChildPath $exe
        if (-not (Test-Path $exePath -PathType Leaf)) {
            return $false
        }
    }
    
    return $true
}

# Function to download and extract ZIP files using curl
function DownloadAndExtractWithCurl {
    param(
        [string]$url,
        [string]$destination
    )

    # Extract filename from URL
    $uri = New-Object System.Uri($url)
    $downloadedFileName = [System.IO.Path]::GetFileName($uri.LocalPath)

    # File path for downloaded file
    $downloadedFilePath = Join-Path -Path $destination -ChildPath $downloadedFileName

    # Create destination directory if it does not exist
    if (-not (Test-Path $destination -PathType Container)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }

    # Download file using curl
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
            Start-Sleep -Seconds 5  # Wait before retrying
        }
    } while (-not $downloadComplete)

    # Ensure file is fully written
    Start-Sleep -Seconds 1  # Adjust if needed

    # Extract ZIP file
    try {
        Expand-Archive -Path $downloadedFilePath -DestinationPath $destination -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to extract $downloadedFilePath. $_"
        return
    }

    # Remove the ZIP file after extraction
    Remove-Item -Path $downloadedFilePath -Force

    # Output success message
    Write-Output "Successfully extracted to $destination"
}

# Function to remove directory if it exists
function RemoveDirectoryIfExists {
    param(
        [string]$dir
    )
    if (Test-Path $dir) {
        Write-Output "Removing $dir..."
        Remove-Item -Path $dir -Recurse -Force
    }
}

# Function to add directory to PATH if not already present
function AddToPathIfNeeded {
    param(
        [string]$pathToAdd
    )

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $paths = $currentPath -split ';'

    if ($paths -notcontains $pathToAdd) {
        Write-Output "Adding $pathToAdd to PATH..."
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$pathToAdd", "Machine")
    }
}

# Confirm reinstall
$reinstallAll = Read-Host "Do you want to reinstall LuaRocks and Lua 5.1.5 and configure LuaRocks to use Lua 5.1? (Y/N)"
if ($reinstallAll -eq 'Y') {
    # Remove existing directories
    RemoveDirectoryIfExists -dir $installDir
    RemoveDirectoryIfExists -dir $luaExecDir
    RemoveDirectoryIfExists -dir $luaLibDir

    # Reinstall LuaRocks
    Write-Output "Installing LuaRocks..."
    DownloadAndExtractWithCurl -url $luarocksUrl -destination $installDir

    # Move luarocks.exe and luarocks-admin.exe to the correct location
    $sourceDir = Join-Path -Path $installDir -ChildPath "luarocks-3.11.1-windows-64"
    $destinationDir = $installDir
    Move-Item -Path (Join-Path -Path $sourceDir -ChildPath "luarocks.exe") -Destination $destinationDir -Force
    Move-Item -Path (Join-Path -Path $sourceDir -ChildPath "luarocks-admin.exe") -Destination $destinationDir -Force
    Write-Output "Installing Lua 5.1.5 executables..."
    DownloadAndExtractWithCurl -url $luaExecUrl -destination $luaExecDir
    Write-Output "Installing Lua 5.1.5 DLLs and libs..."
    DownloadAndExtractWithCurl -url $luaLibUrl -destination $luaLibDir


    $luaExecDir = "C:\Program Files\Lua\5.1"
    $luaExecDir = $luaExecDir.Trim('"')

    try {
        & "$installDir\luarocks.exe" config --scope system lua_version 5.1
        & "$installDir\luarocks.exe" --local config variables.LUA "$luaExecDir\lua5.1.exe"
        Write-Output "LuaRocks configured to use Lua 5.1 at $luaExecDir"
    }
    catch {
        Write-Error "Failed to configure LuaRocks for Lua 5.1. $_"
    }

    # Add LuaRocks and Lua 5.1.5 executables to PATH if not already added
    AddToPathIfNeeded -pathToAdd $installDir
    AddToPathIfNeeded -pathToAdd $luaExecDir

    Write-Output "LuaRocks and Lua 5.1.5 have been reinstalled and configured successfully."
}
else {
    Write-Output "Installation aborted."
}
