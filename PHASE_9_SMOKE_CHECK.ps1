param(
    [string]$BackendBaseUrl = "http://localhost:8081",
    [string]$WebBaseUrl = "http://localhost:3000",
    [string]$FlutterApkPath = "C:\Users\HP\All_Projects\campus_mart_flutter\campus_mart_app\build\app\outputs\flutter-apk\app-debug.apk"
)

$ErrorActionPreference = "Stop"
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details
    )

    $results.Add([pscustomobject]@{
        Check   = $Name
        Passed  = $Passed
        Details = $Details
    }) | Out-Null
}

function Invoke-JsonCheck {
    param(
        [string]$Name,
        [string]$Url,
        [scriptblock]$Assert
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers @{ Accept = "application/json" }
        $json = $response.Content | ConvertFrom-Json
        & $Assert $response $json
        Add-Result -Name $Name -Passed $true -Details "HTTP $($response.StatusCode)"
    } catch {
        Add-Result -Name $Name -Passed $false -Details $_.Exception.Message
    }
}

Invoke-JsonCheck -Name "Backend health" -Url "$BackendBaseUrl/api/public/health" -Assert {
    param($response, $json)
    if ($response.StatusCode -ne 200 -or $json.status -ne "UP") {
        throw "Unexpected health response"
    }
}

Invoke-JsonCheck -Name "Backend readiness" -Url "$BackendBaseUrl/api/public/ready" -Assert {
    param($response, $json)
    if ($response.StatusCode -ne 200 -or $json.status -ne "UP" -or $json.checks.database -ne "UP") {
        throw "Unexpected readiness response"
    }
}

Invoke-JsonCheck -Name "Items pagination" -Url "$BackendBaseUrl/api/items/paginated?page=0&pageSize=3&sort=newest" -Assert {
    param($response, $json)
    if ($response.StatusCode -ne 200 -or $null -eq $json.content) {
        throw "Paginated items payload missing"
    }
}

try {
    $response = Invoke-WebRequest -Uri $WebBaseUrl -UseBasicParsing
    if ($response.StatusCode -ne 200) {
        throw "Unexpected status code $($response.StatusCode)"
    }
    Add-Result -Name "Web root" -Passed $true -Details "HTTP $($response.StatusCode)"
} catch {
    Add-Result -Name "Web root" -Passed $false -Details $_.Exception.Message
}

if (Test-Path -LiteralPath $FlutterApkPath) {
    Add-Result -Name "Flutter APK" -Passed $true -Details "Found at $FlutterApkPath"
} else {
    Add-Result -Name "Flutter APK" -Passed $false -Details "APK not found at $FlutterApkPath"
}

$results | Format-Table -AutoSize

if ($results.Passed -contains $false) {
    exit 1
}
