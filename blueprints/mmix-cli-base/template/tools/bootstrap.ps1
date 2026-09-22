param(
    [Parameter(Mandatory=$true, Position=0)][string]$Command,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$Remaining
)
$ErrorActionPreference = 'Stop'
if ($Command -eq 'destroy') {
    if (Test-Path build) {
        if (((Get-Item build).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Refusing to delete a linked build directory'
        }
        Remove-Item -Recurse -Force build
    }
    Write-Output 'build/ removed'
    exit 0
}

foreach ($name in @('git', 'just')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite: $name; install it before validation"
    }
}
if (Test-Path Env:CC) {
    if ([string]::IsNullOrWhiteSpace($env:CC)) { throw 'CC must name one installed C compiler executable' }
    $compiler = Get-Command $env:CC -ErrorAction Stop
} else {
    $compiler = Get-Command cl.exe -ErrorAction Stop
}
if ([IO.Path]::GetFileNameWithoutExtension($compiler.Source) -ne 'cl') {
    throw 'Windows requires MSVC cl.exe; run from a Visual Studio Developer PowerShell'
}
$env:CC = $compiler.Source
if ($Command -eq 'check') {
    & git --version; if ($LASTEXITCODE -ne 0) { exit 1 }
    & just --version; if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Output "C compiler: MSVC $($compiler.Source)"
    Write-Output "platform: windows $env:PROCESSOR_ARCHITECTURE"
    exit 0
}
foreach ($path in @('build', 'build/tools', 'build/tools/mmix-guard.exe')) {
    if (Test-Path $path) {
        if (((Get-Item $path).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Refusing linked build outputs'
        }
    }
}
New-Item -ItemType Directory -Force build/tools | Out-Null
$sources = @(Get-ChildItem tools/guard/*.c | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { throw 'Missing local guard source' }
& $compiler.Source /nologo /std:c11 /W4 /WX /TC /Febuild/tools/mmix-guard.exe /Fobuild/tools/ @sources
if ($LASTEXITCODE -ne 0) { exit 1 }
& ./build/tools/mmix-guard.exe $Command @Remaining
exit $LASTEXITCODE
