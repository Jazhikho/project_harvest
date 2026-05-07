param(
    [string]$Test = "all",
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"

function Resolve-GodotExecutable {
    param([string]$OverridePath)

    if ($OverridePath -ne "") {
        if (Test-Path $OverridePath) {
            return (Resolve-Path $OverridePath).Path
        }
        throw "Provided Godot executable path does not exist: $OverridePath"
    }

    try {
        $fromScoop = (& scoop which godot-mono).Trim()
        if ($fromScoop -ne "") {
            return $fromScoop
        }
    }
    catch {
    }

    $fromPath = (Get-Command godot-mono -ErrorAction SilentlyContinue)
    if ($null -ne $fromPath) {
        return $fromPath.Source
    }

    throw "Unable to resolve Godot executable. Install Scoop package 'godot-mono' or pass -GodotExe <path>."
}

function Get-TestScripts {
    param([string]$RequestedTest)

    $allTests = @(
        "res://tests/test_final_gate_fallback.gd",
        "res://tests/test_final_gate_transition.gd",
        "res://tests/test_gate_key_spawn.gd",
        "res://tests/test_pause_input_escape.gd",
        "res://tests/test_save_manager_puzzle_repair.gd",
        "res://tests/test_tile_manager_ghost_connection.gd"
    )

    if ($RequestedTest -eq "all") {
        return $allTests
    }

    if ($RequestedTest -like "res://*") {
        return @($RequestedTest)
    }

    $normalized = $RequestedTest
    if (-not $normalized.EndsWith(".gd")) {
        $normalized = "$normalized.gd"
    }
    if (-not $normalized.StartsWith("test_")) {
        $normalized = "test_$normalized"
    }

    return @("res://tests/$normalized")
}

$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotPath = Resolve-GodotExecutable -OverridePath $GodotExe
$testScripts = Get-TestScripts -RequestedTest $Test

Write-Host "Using Godot: $godotPath"
Write-Host "Project path: $projectPath"

$failed = @()

foreach ($scriptPath in $testScripts) {
    Write-Host ""
    Write-Host "Running: $scriptPath"
    & $godotPath --headless --path $projectPath -s $scriptPath
    if ($LASTEXITCODE -ne 0) {
        $failed += $scriptPath
    }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($failedTest in $failed) {
        Write-Host " - $failedTest" -ForegroundColor Red
    }
    exit 1
}

Write-Host "All requested tests passed." -ForegroundColor Green
exit 0
