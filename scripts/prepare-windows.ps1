param([string]$FlutterPath = 'flutter')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    & $FlutterPath pub get
    if (-not (Test-Path '.flutter-plugins-dependencies')) { throw '依赖未解析成功。' }
    $pluginData = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $linkRoot = Join-Path (Get-Location) 'windows/flutter/ephemeral/.plugin_symlinks'
    New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
    foreach ($plugin in $pluginData.plugins.windows) {
        $linkPath = Join-Path $linkRoot $plugin.name
        if (-not (Test-Path -LiteralPath $linkPath)) {
            New-Item -ItemType Junction -Path $linkPath -Target $plugin.path | Out-Null
        }
    }
    Write-Output '插件联接已就绪，可以 flutter run -d windows。'
} finally { Pop-Location }
