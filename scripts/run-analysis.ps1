param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('project-alpha', 'project-beta', 'project-gamma')]
    [string]$Project
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$projectDir = Join-Path $root $Project
$buildDir = Join-Path $projectDir 'build'
$workspaceDir = Join-Path $root ".cpptest-workspaces\$Project"
$reportDir = Join-Path $root "reports\$Project"
$cpptestcli = if ($env:CPPTEST_CLI) { $env:CPPTEST_CLI } else { 'C:\eclipse-cdt-2025-6\eclipse\cpptest\cpptestcli.exe' }
$configDir = if ($env:CPPTEST_CONFIG_DIR) { $env:CPPTEST_CONFIG_DIR } else { 'C:\eclipse-cdt-2025-6\eclipse\cpptest\configs\builtin' }
$gcc = if ($env:DEMO_GCC) { $env:DEMO_GCC } else { 'C:\MinGW\bin\gcc.exe' }
$gccForCpptest = $gcc -replace '\\', '/'
$gppForCpptest = (Join-Path (Split-Path -Parent $gcc) 'g++.exe') -replace '\\', '/'

$configName = switch ($Project) {
    'project-alpha' { 'MISRA C 2023 (MISRA C 2012).properties' }
    'project-beta' { 'Flow Analysis Standard.properties' }
    'project-gamma' { 'SEI CERT C Rules.properties' }
}
$testConfig = Join-Path $configDir $configName

Remove-Item $workspaceDir, $reportDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $buildDir, $workspaceDir, $reportDir | Out-Null

& cmake -S $projectDir -B $buildDir -G 'MinGW Makefiles' `
    '-DCMAKE_BUILD_TYPE=Debug' `
    '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' `
    "-DCMAKE_C_COMPILER=$gcc"
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed for $Project" }

& cmake --build $buildDir --clean-first
if ($LASTEXITCODE -ne 0) { throw "Build failed for $Project" }

Write-Output "ANALYSIS_START project=$Project timestamp=$([DateTimeOffset]::Now.ToString('o')) pid=$PID"
& $cpptestcli `
    -data $workspaceDir `
    '-J-Xmx1024m' `
    -config $testConfig `
    -bdf (Join-Path $buildDir 'compile_commands.json') `
    -report $reportDir `
    -property bdf.import.compiler.family=gcc_6 `
    -property "bdf.import.c.compiler.exec=$gccForCpptest" `
    -property "bdf.import.cpp.compiler.exec=$gppForCpptest" `
    -property "bdf.import.linker.exec=$gccForCpptest" `
    -property report.dtp.publish=false `
    -property console.verbosity.level=high
$analysisExitCode = $LASTEXITCODE
Write-Output "ANALYSIS_END project=$Project timestamp=$([DateTimeOffset]::Now.ToString('o')) exitCode=$analysisExitCode"

if ($analysisExitCode -ne 0) {
    throw "C/C++test analysis failed for $Project with exit code $analysisExitCode"
}
