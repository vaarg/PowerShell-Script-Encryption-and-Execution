param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SourceScriptPath,

    [Parameter()]
    [string]$OutputDirectory = ".\cms-package",

    [Parameter()]
    [string]$CertificateSubject = "CN=Automation Payload Encryption",

    [Parameter()]
    [string]$PayloadFileName = "payload.cms",

    [Parameter()]
    [string]$PublicCertFileName = "payload-encryption-public.cer",

    [Parameter()]
    [string]$PrivatePfxFileName = "payload-decryption.pfx"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve/create output directory.
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

if (-not (Test-Path $OutputDirectory -PathType Container)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$payloadOutPath = Join-Path $OutputDirectory $PayloadFileName
$publicCertOutPath = Join-Path $OutputDirectory $PublicCertFileName
$privatePfxOutPath = Join-Path $OutputDirectory $PrivatePfxFileName

# Prompt for PFX password.
$pfxPassword = Read-Host "PFX export password" -AsSecureString

# Create a document encryption certificate in the current user's personal store.
# CurrentUser avoids requiring admin rights in the normal case.
$cert = New-SelfSignedCertificate `
    -Subject $CertificateSubject `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsage KeyEncipherment, DataEncipherment `
    -Type DocumentEncryptionCert `
    -KeyExportPolicy Exportable

if (-not $cert -or -not $cert.Thumbprint) {
    throw "Certificate creation failed."
}

try {
    # Export public certificate for encryption.
    Export-Certificate `
        -Cert $cert `
        -FilePath $publicCertOutPath `
        -Force | Out-Null

    # Export private certificate/key for runtime decryption.
    Export-PfxCertificate `
        -Cert $cert `
        -FilePath $privatePfxOutPath `
        -Password $pfxPassword `
        -Force | Out-Null

    # Encrypt the source script using the public certificate.
    Protect-CmsMessage `
        -Path $SourceScriptPath `
        -To $publicCertOutPath `
        -OutFile $payloadOutPath

    Write-Host ""
    Write-Host "CMS payload package created:"
    Write-Host "  Payload:     $payloadOutPath"
    Write-Host "  Public cert: $publicCertOutPath"
    Write-Host "  Private PFX: $privatePfxOutPath"
    Write-Host ""
    Write-Host "Certificate thumbprint:"
    Write-Host "  $($cert.Thumbprint)"
}
finally {
    # Remove packaging-time certificate from CurrentUser store.
    # The PFX has already been exported for runtime use.
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" `
        -Force `
        -ErrorAction SilentlyContinue

    Remove-Variable pfxPassword -Force -ErrorAction SilentlyContinue
}
