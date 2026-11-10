param([string]$JdkPath = $env:JAVA_HOME, [string]$FlutterPath = 'flutter')
$ErrorActionPreference = 'Stop'
if (-not $JdkPath -or -not (Test-Path (Join-Path $JdkPath 'bin/java.exe'))) {
    throw '请通过 -JdkPath 指定本机 JDK 目录。'
}
$previousJava = $env:JAVA_HOME
$previousPath = $env:Path
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $env:JAVA_HOME = $JdkPath
    $env:Path = "$JdkPath/bin;$env:Path"
    & $FlutterPath build apk --debug
    if ($LASTEXITCODE -ne 0) { throw "构建失败，退出码 $LASTEXITCODE" }
} finally {
    $env:JAVA_HOME = $previousJava
    $env:Path = $previousPath
    Pop-Location
}
