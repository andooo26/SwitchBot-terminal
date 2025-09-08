param(
    [string]$Name,
    [string]$Action
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$EnvFile   = Join-Path $ScriptDir ".env"
$DevicesFile = Join-Path $ScriptDir "devices.json"
$URL = "https://api.switch-bot.com/v1.0"

# .envからAPI_KEYを読む
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "API_KEY=(.+)") {
            $env:API_KEY = $matches[1]
        }
    }
} else {
    Write-Host ".env がありません"
    exit 1
}

if (-not $Name) {
    Write-Host "引数を指定してください"
    exit 1
}

# list devices
if ($Name -eq "list" -and $Action -eq "devices") {
    Get-Content $DevicesFile
    exit 0
}

# set key
if ($Name -eq "set" -and $Action -eq "key") {
    $NewKey = Read-Host "Enter your API_KEY"
    "API_KEY=$NewKey" | Set-Content $EnvFile
    Write-Host "API_KEY を保存しました"
    exit 0
}

# set devices
if ($Name -eq "set" -and $Action -eq "devices") {
    $NewJson = Invoke-RestMethod -Method GET "$URL/devices" -Headers @{Authorization=$env:API_KEY}
    $NewJson | ConvertTo-Json -Depth 5 | Out-File $DevicesFile -Encoding utf8
    Write-Host "devices.json を更新しました"
    exit 0
}

# device検索
$Devices = Get-Content $DevicesFile | ConvertFrom-Json
$Device = ($Devices.body.deviceList + $Devices.body.infraredRemoteList) | Where-Object { $_.unique -eq $Name }

if (-not $Device) {
    Write-Host "デバイスが見つかりません"
    exit 1
}

$DeviceId = $Device.deviceId
$DeviceName = $Device.deviceName

switch ($Action) {
    "on" {
        Invoke-RestMethod -Method POST "$URL/devices/$DeviceId/commands" `
            -Headers @{Authorization=$env:API_KEY; "Content-Type"="application/json"} `
            -Body '{"command":"turnOn","parameter":"default","commandType":"command"}'
        Write-Host "$DeviceName を ON にしました"
    }
    "off" {
        Invoke-RestMethod -Method POST "$URL/devices/$DeviceId/commands" `
            -Headers @{Authorization=$env:API_KEY; "Content-Type"="application/json"} `
            -Body '{"command":"turnOff","parameter":"default","commandType":"command"}'
        Write-Host "$DeviceName を OFF にしました"
    }
    default {
        Write-Host "on/off を指定してください"
    }
}
