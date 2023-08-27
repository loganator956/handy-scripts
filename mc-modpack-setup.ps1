function Install-ModrinthVersion {
    param (
        $VersionID
    )
    $response = Invoke-WebRequest -Uri https://api.modrinth.com/v2/version/$VersionID -Headers @{"User-Agent" = $ApiUserAgent } -Method Get
    $content = $response.Content | ConvertFrom-Json
    # Get file
    $project = Get-Project -ProjectID $content.project_id
    $title = $project.title
    $fileName = Split-Path $content.files[0].url -Leaf
    Write-Host "Downloading $title to $fileName"
    if ((Test-Path -Path "$DestinationStorage\mods") -eq $false) {
        New-Item -Path "$DestinationStorage\mods" -ItemType Directory
    }
    Invoke-WebRequest -Uri $content.files[0].url -OutFile "$DestinationStorage\mods\$fileName"

    # Process Dependencies
    foreach ($Dependency in $content.dependencies) {
        Install-ModrinthVersion -VersionID $Dependency.version_id
    }
}

function Install-Curseforge {
    param (
        $url
    )
    
    $fileName = Split-Path $url -Leaf
    if ((Test-Path -Path "$DestinationStorage\mods") -eq $false) {
        New-Item -Path "$DestinationStorage\mods" -ItemType Directory
    }
    Invoke-WebRequest -Uri $url -OutFile "$DestinationStorage\mods\$fileName"
}

function Get-Project {
    param (
        $ProjectID
    )
    $response = Invoke-WebRequest -Uri https://api.modrinth.com/v2/project/$ProjectID -Headers @{"User-Agent" = $ApiUserAgent } -Method Get
    $content = $response.Content | ConvertFrom-Json
    return $content
}

function Install-ModLoader {
    param (
        $URL
    )
    #TODO: Check if modloader version is already installed or not
    Write-Host "Downloading "$URL
    Install-Java
    $fileName = Split-Path $URL -Leaf
    Invoke-WebRequest -Uri $URL -OutFile $fileName
    Start-Process -FilePath $JavaPath -Wait -ArgumentList "-jar $fileName"
    Remove-Item -Path $fileName
}

function Install-Java {
    if ((Test-Path -Path $JavaPath) -eq $false) {
        winget.exe install --exact --id EclipseAdoptium.Temurin.20.JRE --version 20.0.1.9
    }
}

$r = Read-Host -Prompt "Have you ran minecraft launcher and signed in? [y/N]"
if ($r -ne "y") {
    exit
}

$ApiUserAgent = "loganator956/handy-scripts"
$DestinationStorage = $args[1]
$SourceList = Invoke-WebRequest -Uri $args[0] | ConvertFrom-Json

$JavaPath = "C:\Program Files\Eclipse Adoptium\jre-20.0.1.9-hotspot\bin\java.exe"

Install-ModLoader -URL $SourceList.ModLoader

foreach ($source in $SourceList.Mods) {
    if ($Source.Source -eq "modrinth") {
        Install-ModrinthVersion -VersionID $Source.VersionID
    }
    elseif ($Source.Source -eq "curseforge") {
        Install-Curseforge -url $source.URL
    }
}