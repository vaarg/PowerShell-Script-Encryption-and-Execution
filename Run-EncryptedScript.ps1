param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$PayloadPath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$PfxPath,

    [Parameter()]
    [ValidateSet("Execute", "DotSource", "DynamicModule")]
    [string]$Mode = "Execute",

    [Parameter()]
    [string]$CommandName,

    [Parameter(ValueFromRemainingArguments)]
    [object[]]$PayloadArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$importedCert = $null
$thumbprint = $null
$pfxPassword = $null
$payloadText = $null
$payloadBlock = $null
$dynamicModule = $null

try {
    $pfxPassword = Read-Host "PFX password" -AsSecureString

    $importedCert = Import-PfxCertificate `
        -FilePath $PfxPath `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -Password $pfxPassword

    if (-not $importedCert -or -not $importedCert.Thumbprint) {
        throw "PFX import failed or did not return a thumbprint."
    }

    $thumbprint = $importedCert.Thumbprint

    $payloadText = Unprotect-CmsMessage -Path $PayloadPath

    if ([string]::IsNullOrWhiteSpace($payloadText)) {
        throw "CMS payload decrypted to empty content."
    }

    $payloadBlock = [scriptblock]::Create($payloadText)

    switch ($Mode) {
        "Execute" {
            & $payloadBlock @PayloadArgs
        }

        "DotSource" {
            # Equivalent to: . .\script.ps1
            # Loads functions/variables into the current runner scope.
            . $payloadBlock

            if ($CommandName) {
                $cmd = Get-Command $CommandName -ErrorAction Stop
                & $cmd @PayloadArgs
            }
        }

        "DynamicModule" {
            # Equivalent-ish to importing an in-memory .psm1.
            # Cleaner than dot-sourcing into the runner's own scope.
            $dynamicModule = New-Module -ScriptBlock $payloadBlock

            Import-Module $dynamicModule -Force -ErrorAction Stop

            if ($CommandName) {
                $cmd = Get-Command $CommandName -ErrorAction Stop
                & $cmd @PayloadArgs
            }
        }
    }
}
finally {
    if ($dynamicModule) {
        Remove-Module $dynamicModule -Force -ErrorAction SilentlyContinue
    }

    if ($thumbprint) {
        Remove-Item "Cert:\CurrentUser\My\$thumbprint" `
            -Force `
            -ErrorAction SilentlyContinue
    }

    Remove-Variable payloadText -Force -ErrorAction SilentlyContinue
    Remove-Variable payloadBlock -Force -ErrorAction SilentlyContinue
    Remove-Variable pfxPassword -Force -ErrorAction SilentlyContinue
    Remove-Variable importedCert -Force -ErrorAction SilentlyContinue
    Remove-Variable thumbprint -Force -ErrorAction SilentlyContinue
    Remove-Variable dynamicModule -Force -ErrorAction SilentlyContinue

    [GC]::Collect()
}
