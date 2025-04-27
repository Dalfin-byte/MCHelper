# MCHelper - Minecraft Server Install Helper

# Function to display a loading bar
function Show-LoadingBar {
    param (
        [string]$Activity = "Processing...",
        [int]$Duration = 5
    )
    Write-Host "[$Activity]" -ForegroundColor Cyan
    for ($i = 0; $i -le 100; $i += 5) {
        Write-Progress -Activity $Activity -Status "$i% Complete" -PercentComplete $i
        Start-Sleep -Milliseconds ($Duration * 10)
    }
    Write-Host "[$Activity Complete]" -ForegroundColor Green
}

# Function to fetch the latest Vanilla server JAR URL
function Get-LatestVanillaURL {
    try {
        Write-Host "[Fetching latest Vanilla server URL...]" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        $latestRelease = $response.latest.release
        $versionInfo = $response.versions | Where-Object { $_.id -eq $latestRelease }
        $versionDetails = Invoke-RestMethod -Uri $versionInfo.url
        Write-Host "[Latest Vanilla server URL fetched successfully]" -ForegroundColor Green
        return $versionDetails.downloads.server.url
    } catch {
        Write-Host "[Error fetching the latest Vanilla server URL. Please check your internet connection.]" -ForegroundColor Red
        exit
    }
}

# Function to fetch the latest PaperMC version dynamically
function Get-LatestPaperVersion {
    try {
        Write-Host "[Fetching latest PaperMC version...]" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri "https://api.papermc.io/v2/projects/paper"
        Write-Host "[Latest PaperMC version fetched: $($response.versions[-1])]" -ForegroundColor Green
        return $response.versions[-1] # Get the latest version
    } catch {
        Write-Host "[Error fetching PaperMC version. Please check your internet connection.]" -ForegroundColor Red
        exit
    }
}

# Function to fetch the latest PaperMC build dynamically
function Get-LatestPaperBuild {
    param ([string]$version)
    try {
        Write-Host "[Fetching latest PaperMC build for version $version...]" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri "https://api.papermc.io/v2/projects/paper/versions/$version"
        Write-Host "[Latest PaperMC build fetched: $($response.builds[-1])]" -ForegroundColor Green
        return $response.builds[-1] # Get the latest build
    } catch {
        Write-Host "[Error fetching PaperMC build. Please check your internet connection.]" -ForegroundColor Red
        exit
    }
}

# Function to fetch the latest Forge installer URL
function Get-LatestForgeURL {
    try {
        Write-Host "[Fetching latest Forge installer URL...]" -ForegroundColor Cyan
        $response = Invoke-RestMethod -Uri "https://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json"
        $latestVersion = $response.promos["1.20.1-latest"] # Replace "1.20.1" with the desired Minecraft version
        Write-Host "[Latest Forge installer URL fetched successfully]" -ForegroundColor Green
        return "https://maven.minecraftforge.net/net/minecraftforge/forge/$latestVersion/forge-$latestVersion-installer.jar"
    } catch {
        Write-Host "[Error fetching the latest Forge installer URL. Please check your internet connection.]" -ForegroundColor Red
        exit
    }
}

# Function to download a file with retry logic
function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath,
        [int]$Retries = 3
    )
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            Write-Host "[Attempting to download: $Url (Attempt $attempt of $Retries)]" -ForegroundColor Cyan
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
            Write-Host "[Download successful: $OutputPath]" -ForegroundColor Green
            return
        } catch {
            Write-Host "[Download failed: $($_.Exception.Message)]" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    Write-Host "[Failed to download the file after $Retries attempts. Exiting...]" -ForegroundColor Red
    exit
}

# Welcome message
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   MCHELPER -- Minecraft Install Helper   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

# Step 1: Name the server
Write-Host "Please enter a name for your server:" -ForegroundColor Yellow
$serverName = Read-Host "Server Name"
if (-not [string]::IsNullOrWhiteSpace($serverName)) {
    New-Item -ItemType Directory -Path $serverName -Force | Out-Null
    Set-Location -Path $serverName
    Write-Host "[Server folder '$serverName' created.]" -ForegroundColor Green
} else {
    Write-Host "[Invalid server name. Exiting...]" -ForegroundColor Red
    exit
}

# Step 2: Ask for server type
Write-Host "Please select the server type:" -ForegroundColor Yellow
Write-Host "1. Vanilla"
Write-Host "2. Paper/Spigot"
Write-Host "3. Forge"
$serverType = Read-Host "Enter the number corresponding to your choice"

# Step 3: Determine download URL based on server type
$downloadUrl = ""
$serverFileName = "server.jar"
switch ($serverType) {
    "1" { 
        $downloadUrl = Get-LatestVanillaURL
        $serverFileName = "vanilla_server.jar"
    }
    "2" { 
        $latestVersion = Get-LatestPaperVersion
        $latestBuild = Get-LatestPaperBuild -version $latestVersion
        $downloadUrl = "https://api.papermc.io/v2/projects/paper/versions/$latestVersion/builds/$latestBuild/downloads/paper-$latestVersion-$latestBuild.jar"
        $serverFileName = "paper_server.jar"
    }
    "3" { 
        $downloadUrl = Get-LatestForgeURL
        $serverFileName = "forge_installer.jar"
    }
    default { 
        Write-Host "[Invalid choice. Exiting...]" -ForegroundColor Red
        exit
    }
}

# Step 4: Download the server file
Write-Host "[Downloading server files...]" -ForegroundColor Cyan
Download-File -Url $downloadUrl -OutputPath $serverFileName

# Step 5: Accept the EULA
Write-Host "To start the server, do you accept the Minecraft EULA? (https://www.minecraft.net/en-us/eula) (yes/no)" -ForegroundColor Yellow
$acceptEULA = Read-Host "Enter your choice"
if ($acceptEULA -eq "yes") {
    Set-Content -Path "eula.txt" -Value "eula=true"
    Write-Host "[EULA accepted.]" -ForegroundColor Green
} else {
    Write-Host "[You must accept the EULA to proceed. Exiting...]" -ForegroundColor Red
    exit
}

# Step 6: Customize server.properties (optional)
Write-Host "Would you like to customize server.properties? (yes/no)" -ForegroundColor Yellow
$customizeProperties = Read-Host "Enter your choice"
if ($customizeProperties -eq "yes") {
    Write-Host "[Customizing server.properties...]" -ForegroundColor Cyan
    $serverProperties = @(
        @{ Key = "motd"; Value = "Welcome to your Minecraft Server!" },
        @{ Key = "max-players"; Value = "20" },
        @{ Key = "difficulty"; Value = "normal" },
        @{ Key = "gamemode"; Value = "survival" },
        @{ Key = "pvp"; Value = "true" },
        @{ Key = "spawn-protection"; Value = "16" },
        @{ Key = "allow-nether"; Value = "true" },
        @{ Key = "enable-command-block"; Value = "false" },
        @{ Key = "server-port"; Value = "25565" },
        @{ Key = "server-ip"; Value = "" }
    )
    foreach ($property in $serverProperties) {
        $value = Read-Host "Enter value for $($property.Key) (default: $($property.Value))"
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $property.Value = $value
        }
    }
    $serverPropertiesContent = $serverProperties | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -Path "server.properties" -Value $serverPropertiesContent
    Write-Host "[server.properties customized.]" -ForegroundColor Green
}

# Step 7: Run the server
Write-Host "[Starting the Minecraft server...]" -ForegroundColor Cyan
Show-LoadingBar -Activity "Starting Server"
try {
    Start-Process "java" -ArgumentList "-Xmx1024M -Xms1024M -jar $serverFileName nogui"
    Write-Host "[Done! Your Minecraft Server Is Now Running]" -ForegroundColor Green
    Write-Host "[Thank you for using MCHELP for setting up your server.]" -ForegroundColor Green
} catch {
    Write-Host "[Failed to start the server. Please ensure Java is installed and configured correctly.]" -ForegroundColor Red
}