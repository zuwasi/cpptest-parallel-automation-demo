$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Write-Output 'Opening C++test parallel automation dashboard at http://localhost:8765'
Start-Process 'http://localhost:8765'
python (Join-Path $root 'server.py')
