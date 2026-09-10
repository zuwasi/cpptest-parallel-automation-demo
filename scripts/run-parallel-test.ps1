$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'logs'
$projects = @('project-alpha', 'project-beta', 'project-gamma')

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$runs = foreach ($project in $projects) {
    $stdout = Join-Path $logDir "$project.stdout.log"
    $stderr = Join-Path $logDir "$project.stderr.log"
    Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

    $process = Start-Process powershell.exe -PassThru `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'run-analysis.ps1'), '-Project', $project) `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    [pscustomobject]@{
        Project = $project
        Process = $process
        Stdout = $stdout
    }
}

foreach ($run in $runs) {
    $run.Process.WaitForExit()
    $run | Add-Member ExitCode $run.Process.ExitCode

    $log = Get-Content $run.Stdout -Raw
    $startMatch = [regex]::Match($log, 'ANALYSIS_START[^\r\n]*timestamp=(\S+)')
    $endMatch = [regex]::Match($log, 'ANALYSIS_END[^\r\n]*timestamp=(\S+)')
    if (-not ($startMatch.Success -and $endMatch.Success)) {
        throw "Analysis timestamps are missing from $($run.Stdout)"
    }
    $run | Add-Member AnalysisStart ([DateTimeOffset]::Parse($startMatch.Groups[1].Value))
    $run | Add-Member AnalysisEnd ([DateTimeOffset]::Parse($endMatch.Groups[1].Value))
}

$latestStart = ($runs.AnalysisStart | Sort-Object -Descending | Select-Object -First 1)
$earliestEnd = ($runs.AnalysisEnd | Sort-Object | Select-Object -First 1)
$allOverlapped = $latestStart -lt $earliestEnd

$summary = foreach ($run in $runs) {
    [pscustomobject]@{
        project = $run.Project
        analysisStart = $run.AnalysisStart.ToString('o')
        analysisEnd = $run.AnalysisEnd.ToString('o')
        durationSeconds = [Math]::Round(($run.AnalysisEnd - $run.AnalysisStart).TotalSeconds, 2)
        exitCode = $run.ExitCode
        report = Join-Path $root "reports\$($run.Project)\report.html"
    }
}

$result = [pscustomobject]@{
    allThreeAnalysesOverlapped = $allOverlapped
    runs = $summary
}
$result | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $logDir 'parallel-test-result.json')
$result | ConvertTo-Json -Depth 4

if (-not $allOverlapped) {
    throw 'The three analysis processes did not overlap.'
}
if ($runs | Where-Object { $_.ExitCode -ne 0 }) {
    throw 'At least one analysis failed. Inspect the logs directory.'
}
