# Convert an evaluation install to the retail-channel edition named in
# $env:TARGET_EDITION, using the KMS client key (GVLK) in $env:PRODUCT_KEY.
# Used by windows2022-bare: the Server 2022 media is the evaluation ISO, so
# setup installs ServerStandardEval and cannot take a GVLK at install time.
#
# DISM /Set-Edition stages the change and needs a reboot to finish; the
# windows-restart provisioner that follows in windows.pkr.hcl does that.
#
# Idempotent: if DISM already reports the target edition, nothing is done.
# With $env:EDITION_VERIFY_ONLY = "1" the script only asserts the edition and
# throws if it does not match (run after the reboot as a gate).

$ErrorActionPreference = 'Stop'

$target = $env:TARGET_EDITION
$key    = $env:PRODUCT_KEY
if (-not $target) { throw "TARGET_EDITION is not set." }

function Get-CurrentEdition {
    $out = & dism.exe /online /Get-CurrentEdition /English
    if ($LASTEXITCODE -ne 0) {
        throw "DISM /Get-CurrentEdition exited with code $LASTEXITCODE"
    }
    $line = $out | Where-Object { $_ -match '^\s*Current Edition\s*:' } | Select-Object -First 1
    if (-not $line) { throw "Could not parse DISM /Get-CurrentEdition output." }
    return ($line -split ':', 2)[1].Trim()
}

$current = Get-CurrentEdition
Write-Host "Current edition: $current (target: $target)"

if ($current -eq $target) {
    Write-Host "Edition already $target - skipping."
    exit 0
}

if ($env:EDITION_VERIFY_ONLY -eq '1') {
    throw "Edition is $current, expected $target after Set-Edition and reboot."
}

if (-not $key) { throw "PRODUCT_KEY is not set." }

Write-Host "Running DISM /Set-Edition:$target (this can take several minutes)..."
& dism.exe /online "/Set-Edition:$target" "/ProductKey:$key" /AcceptEula /NoRestart
$rc = $LASTEXITCODE

# 3010 = success, reboot required (expected with /NoRestart).
if ($rc -ne 0 -and $rc -ne 3010) {
    throw "DISM /Set-Edition exited with code $rc"
}
Write-Host "DISM /Set-Edition exit code: $rc. Reboot pending to complete the change."
exit 0
