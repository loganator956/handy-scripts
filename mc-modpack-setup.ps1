function Install-ModrinthVersion {
    param (
        $VersionID,
        $Blacklist
    )
    
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
        Install-ModrinthVersion -VersionID $Dependency.version_id -Blacklist $Blacklist
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
        $profile = $profiles.$ID
        $profile.name = $MCProfile.name
        $profile.type = $MCProfile.type
        $profile.created = $MCProfile.created
        $profile.lastUsed = $MCProfile.lastUsed
        $profile.icon = $MCProfile.icon
        $profile.lastVersionId = $MCProfile.lastVersionId
        $profile.gameDir = $MCProfile.gameDir
    }
    else {
        $profiles | Add-Member -MemberType NoteProperty -Name $ID -Value $MCProfile
    }
    $data.profiles = $profiles
    $s = $data | ConvertTo-Json 
    $s | Set-Content -Path $ProfFile
}

$r = Read-Host -Prompt "Have you ran minecraft launcher and signed in? [y/N]"
if ($r -ne "y") {
    exit
}

$ApiUserAgent = "loganator956/handy-scripts"
$SourceList = Invoke-WebRequest -Uri $args[0] | ConvertFrom-Json
$SourceList[0].MinecraftProfile[0].gameDir = $SourceList[0].MinecraftProfile[0].gameDir.Replace("//REPLACEWITHDOCS", [Environment]::GetFolderPath("MyDocuments"))
$DestinationStorage = $SourceList[0].MinecraftProfile[0].gameDir
if ((Test-Path -Path $MCProfile.gameDir) -eq $false) {
    New-Item -Path $MCProfile.gameDir -ItemType Directory
}
if ((Test-Path -Path "$DestinationStorage\mods") -eq $false) {
    New-Item -Path "$DestinationStorage\mods" -ItemType Directory
}
$JavaPath = "C:\Program Files\Eclipse Adoptium\jre-20.0.1.9-hotspot\bin\java.exe"

$InstalledModrinthProjectsList = New-Object Collections.Generic.List[string]

# Install-ModLoader -URL $SourceList.ModLoader

Disable-Mods -ModDir "$DestinationStorage\mods"

foreach ($source in $SourceList.Mods) {
    if ($Source.Source -eq "modrinth") {
        Install-ModrinthVersion -VersionID $Source.VersionID -Blacklist $SourceList.ModBlacklist
    }
    elseif ($Source.Source -eq "curseforge") {
        Install-Curseforge -url $source.URL
    }
}
Create-LauncherProfile -MCProfile $SourceList.MinecraftProfile[0] -ID $SourceList.ProfileUUID