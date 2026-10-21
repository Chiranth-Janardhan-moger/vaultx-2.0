# PowerShell script to detect accidental plaintext logging of sensitive fields
param (
    [string]$SearchDir = "lib"
)

Write-Host "Scanning $SearchDir for plaintext secret logging patterns..." -ForegroundColor Cyan

$sensitivePatterns = @(
    "(print|debugPrint|log)\s*\(.*(password|masterKey|privateKey|sharedSecret|seedPhrase|cardNumber|pin|cvv|secret).*\)"
)

$violations = @()

$files = Get-ChildItem -Path $SearchDir -Recurse -Filter "*.dart" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $lines = Get-Content $file.FullName
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        # Skip comments
        if ($line.Trim().StartsWith("//") -or $line.Trim().StartsWith("/*") -or $line.Trim().StartsWith("*")) {
            continue
        }
        foreach ($pattern in $sensitivePatterns) {
            if ($line -match $pattern) {
                # Check for explicit exemption comment
                if ($line -notmatch "//\s*security-exempt") {
                    $violations += [PSCustomObject]@{
                        File = $file.FullName
                        Line = $lineNum
                        Content = $line.Trim()
                        Pattern = $pattern
                    }
                }
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "ERROR: Found $($violations.Count) sensitive logging pattern violation(s):" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  $($v.File):$($v.Line) -> $($v.Content)" -ForegroundColor Yellow
    }
    exit 1
} else {
    Write-Host "SUCCESS: Zero sensitive logging violations found in $SearchDir." -ForegroundColor Green
    exit 0
}
