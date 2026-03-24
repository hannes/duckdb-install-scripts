<#
    .SYNOPSIS
    TODO

    .DESCRIPTION
    TODO
    
    .NOTES
    TODO
    Based on the chocolatey install script
#>

$duckdb_version = iwr "https://duckdb.org/data/latest_stable_version.txt"


Write-Host
Write-Host "*** DuckDB Windows installation script, version ${duckdb_version} ***"
Write-Host
Write-Host
Write-Host "         .;odxdl,            "
Write-Host "       .xXXXXXXXXKc          "
Write-Host "       0XXXXXXXXXXXd  cooo:  "
Write-Host "      ,XXXXXXXXXXXXK  OXXXXd "
Write-Host "       0XXXXXXXXXXXo  cooo:  "
Write-Host "       .xXXXXXXXXKc          "
Write-Host "         .;odxdl,  "
Write-Host 
Write-Host 


function TestDuckDB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $duckdb_output = & $Path -noheader -init NUL -csv -batch -s "SELECT version()"
    if ($duckdb_output -ne "v${duckdb_version}") {
        throw ("Version mismatch, ${duckdb_version} vs. ${duckdb_output}")
    }
}


# really powershell?!

$cli_path = Join-Path (Join-Path $env:LOCALAPPDATA -ChildPath "duckdb") -ChildPath "cli"
$local_install_dir = Join-Path $cli_path -ChildPath $duckdb_version

if (-not (Test-Path $local_install_dir -PathType Container)) {
    $null = New-Item -Path $local_install_dir -ItemType Directory
}
$duckdb_exec = Join-Path $local_install_dir -ChildPath "duckdb.exe"

if (Test-Path -Path ${duckdb_exec}) {
    TestDuckDB(${duckdb_exec})

    Write-Host "Destination binary ${duckdb_exec} already exists and seems to work."
    Write-Host
    Write-Host "To launch DuckDB now, type"
    Write-Host "${duckdb_exec}"
    return
}

$duckdb_arch = ''
$arch = (Get-CimInstance Win32_operatingsystem).OSArchitecture
if ($arch -eq '64-bit') {
    $duckdb_arch = 'windows-amd64'
}
if ($arch -eq 'ARM 64-bit Processor') {
    $duckdb_arch = 'windows-arm64'
}
# TODO is this enough?
if ($duckdb_arch -eq '') {
    throw "Architecture ${arch} is not supported. Sorry."
}


$duckdb_download_url = "https://install.duckdb.org/v${duckdb_version}/duckdb_cli-${duckdb_arch}.zip"

# if we don't have a temp dir, create one using system drive ('C:\') and 'temp' folder.
if (-not $env:TEMP) {
    $env:TEMP = Join-Path $env:SystemDrive -ChildPath 'temp'
}

# generate some randomness for the name of the temp download folder
$random_path_ele = (-join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_}))


$temp_dir = Join-Path $env:TEMP -ChildPath "duckdb_install_${random_path_ele}"

# create target dir if not present
if (-not (Test-Path $temp_dir -PathType Container)) {
    $null = New-Item -Path $temp_dir -ItemType Directory
}

$local_zip_file = Join-Path $temp_dir "duckdb.zip"

# actually doing the download
Invoke-WebRequest $duckdb_download_url -OutFile $local_zip_file


if (-not $local_zip_file) {
    throw ("Failed to download DuckDB")
}

Write-Host "Extracting $local_zip_file to $temp_dir"
Microsoft.PowerShell.Archive\Expand-Archive -Path $local_zip_file -DestinationPath $temp_dir -Force


$duckdb_exec_candidate = Join-Path $temp_dir "duckdb.exe"
if (-not $duckdb_exec_candidate) {
    throw ("Failed to download and/or unpack DuckDB")
}

TestDuckDB(${duckdb_exec_candidate})


Write-Host "Installing to ${local_install_dir}"
Copy-Item -Path $duckdb_exec_candidate -Destination $duckdb_exec -Force -ErrorAction SilentlyContinue

if (-not $duckdb_exec) {
    throw ("Failed to download and/or unpack DuckDB")
}
TestDuckDB(${duckdb_exec})

Write-Host "Successfully installed DuckDB binary to ${duckdb_exec}"
Write-Host
Write-Host "To launch DuckDB now, type"
Write-Host "${duckdb_exec}"

try {
    $WshShell = New-Object -COMObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\DuckDB.lnk")
    $Shortcut.TargetPath = ${duckdb_exec}
    $Shortcut.Save()
    Write-Host "There should also be a shortcut on your Desktop now."

} catch {
}

