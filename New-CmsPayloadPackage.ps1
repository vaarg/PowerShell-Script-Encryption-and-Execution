param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$PayloadPath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$PfxPath,

    [Parameter(ValueFromRemainingArguments)]
    [object[]]$PayloadArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$importedCert = $null
$thumbprint = $null
$payloadText = $null
$payloadBlock = $null
$pfxPassword = $null

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

    & $payloadBlock @PayloadArgs
}
finally {
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

    [GC]::Collect()
}
