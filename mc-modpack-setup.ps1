function Install-ModrinthVersion {
    param (
        $VersionID,
        $Blacklist
    )

    Write-Host "Installing modrinth" $VersionID
    
    $response = Invoke-WebRequest -Uri https://api.modrinth.com/v2/version/$VersionID -Headers @{"User-Agent" = $ApiUserAgent } -Method Get
    $content = $response.Content | ConvertFrom-Json
    # Get file
    if ($InstalledModrinthProjectsList.Contains($content.project_id)) {
        Write-Host "Already installed "$content.project_id
        return
    }
    if ($Blacklist.Contains($content.project_id)) {
        Write-Host "Ignoring "$content.project_id
        return
    }
    $project = Get-Project -ProjectID $content.project_id
    $InstalledModrinthProjectsList.Add($content.project_id)
    $title = $project.title
    $fileName = Split-Path $content.files[0].url -Leaf
    Write-Host "Downloading $title to $fileName"
    if ((Test-Path -Path "$DestinationStorage\mods") -eq $false) {
        New-Item -Path "$DestinationStorage\mods" -ItemType Directory
    }
    Invoke-WebRequest -Uri $content.files[0].url -OutFile "$DestinationStorage\mods\$fileName"

    # Process Dependencies
    foreach ($Dependency in $content.dependencies) {
        Write-Host "Installing modrinth dependency" $Dependency
        if ($Dependency.version_id -eq $null) {
            Write-Warning -Message ($Dependency.project_id + " has no version_id set. Manually add this dependency to the json file")
            continue
        }
        Install-ModrinthVersion -VersionID $Dependency.version_id -Blacklist $Blacklist
    }
}

function Install-ModrinthShader {
    param (
        $VersionID
    )

    Write-Host "Installing modrinth shader" $VersionID
    
    $response = Invoke-WebRequest -Uri https://api.modrinth.com/v2/version/$VersionID -Headers @{"User-Agent" = $ApiUserAgent } -Method Get
    $content = $response.Content | ConvertFrom-Json
    # Get file
    if ($InstalledModrinthProjectsList.Contains($content.project_id)) {
        Write-Host "Already installed "$content.project_id
        return
    }
    $project = Get-Project -ProjectID $content.project_id
    $InstalledModrinthProjectsList.Add($content.project_id)
    $title = $project.title
    $fileName = Split-Path $content.files[0].url -Leaf
    Write-Host "Downloading $title to $fileName"
    if ((Test-Path -Path "$DestinationStorage\shaderpacks") -eq $false) {
        New-Item -Path "$DestinationStorage\shaderpacks" -ItemType Directory
    }
    Invoke-WebRequest -Uri $content.files[0].url -OutFile "$DestinationStorage\shaderpacks\$fileName"
}

function Install-Curseforge {
    param (
        $url
    )
    Write-Host "Installing curseforge" $url
    
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
        $URL,
        $Arguments
    )
    #TODO: Check if modloader version is already installed or not
    Write-Host "Downloading "$URL
    Install-Java
    $fileName = Split-Path $URL -Leaf
    Invoke-WebRequest -Uri $URL -OutFile $fileName
    Start-Process -FilePath $JavaPath -Wait -ArgumentList "-jar $fileName $Arguments"
    Remove-Item -Path $fileName
}

function Install-Java {
    if ((Test-Path -Path $JavaPath) -eq $false) {
        winget.exe install --exact --id EclipseAdoptium.Temurin.20.JRE --version 20.0.1.9
    }
}

function Disable-Mods {
    param (
        $ModDir
    )
    foreach ($child in (Get-ChildItem -Path $ModDir)) {
        if ($child.FullName.EndsWith(".DISABLED")) {
            continue
        }
        $newName = $child.FullName + ".DISABLED"
        if (Test-Path -Path $newName) {
            Remove-Item -Path $newName
        }
        $child.MoveTo($newName)
    }
}

function Create-LauncherProfile {
    param (
        $MCProfile,
        $ID
    )
    $ProfFile = "$Env:APPDATA\.minecraft\launcher_profiles.json"
    $data = Get-Content -Path $ProfFile | ConvertFrom-Json
    $profiles = $data.profiles
    $found = $false
    foreach ($member in ($profiles | Get-Member)) {
        if ($member.Name -eq $ID) {
            $found = $true
            break
        }
    }

    # $MCProfile.gameDir = $MCProfile.gameDir.Replace("//REPLACEWITHDOCS", [Environment]::GetFolderPath("MyDocuments"))

    if ($found -eq $true) {
        $prof = $profiles.$ID
        $prof.name = $MCProfile.name
        $prof.type = $MCProfile.type
        $prof.created = $MCProfile.created
        $prof.lastUsed = $MCProfile.lastUsed
        $prof.icon = $MCProfile.icon
        $prof.lastVersionId = $MCProfile.lastVersionId
        $prof.gameDir = $MCProfile.gameDir
    }
    else {
        $profiles | Add-Member -MemberType NoteProperty -Name $ID -Value $MCProfile
    }
    $data.profiles = $profiles
    $s = $data | ConvertTo-Json 
    $s | Set-Content -Path $ProfFile
}

$jsonPath = $args[0]
if ($jsonPath -eq $null) {
    $jsonPath = $MC_JSON_PATH
}
if ($jsonPath -eq $null) {
    $jsonPath = Read-Host -Prompt "JsonPath not provided, please enter a URL"
}

$r = Read-Host -Prompt "Have you ran minecraft launcher and signed in? [y/N]"
if ($r -ne "y") {
    exit
}

$ApiUserAgent = "loganator956/handy-scripts"



$SourceList = Invoke-WebRequest -Uri $jsonPath | ConvertFrom-Json
$SourceList[0].MinecraftProfile[0].gameDir = $SourceList[0].MinecraftProfile[0].gameDir.Replace("//REPLACEWITHDOCS", [Environment]::GetFolderPath("MyDocuments"))
$DestinationStorage = $SourceList[0].MinecraftProfile[0].gameDir
if ((Test-Path -Path $DestinationStorage) -eq $false) {
    New-Item -Path $DestinationStorage -ItemType Directory
}
if ((Test-Path -Path "$DestinationStorage\mods") -eq $false) {
    New-Item -Path "$DestinationStorage\mods" -ItemType Directory
}
if ((Test-Path -Path "$DestinationStorage\shaderpacks") -eq $false) {
    New-Item -Path "$DestinationStorage\shaderpacks" -ItemType Directory
}
$JavaPath = "C:\Program Files\Eclipse Adoptium\jre-20.0.1.9-hotspot\bin\java.exe"

$InstalledModrinthProjectsList = New-Object Collections.Generic.List[string]

Install-ModLoader -URL $SourceList.ModLoader $SourceList.ModLoaderInstallArgs

Disable-Mods -ModDir "$DestinationStorage\mods"

foreach ($source in $SourceList.Mods) {
    if ($source.Source -eq "modrinth") {
        Install-ModrinthVersion -VersionID $source.VersionID -Blacklist $SourceList.ModBlacklist
    }
    elseif ($source.Source -eq "curseforge") {
        Install-Curseforge -url $source.URL
    }
}

foreach ($shader in $SourceList.Shaders){
    if ($shader.Source -eq "modrinth") {
        Install-ModrinthShader -VersionID $shader.VersionID
    }
}
Create-LauncherProfile -MCProfile $SourceList.MinecraftProfile[0] -ID $SourceList.ProfileUUID