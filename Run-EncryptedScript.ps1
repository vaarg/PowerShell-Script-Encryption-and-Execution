param(
    [Parameter(Mandatory)]
    [string]$PayloadPath,

    [Parameter(ValueFromRemainingArguments)]
    [object[]]$PayloadArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $payloadText = Unprotect-CmsMessage -Path $PayloadPath
    $payloadBlock = [scriptblock]::Create($payloadText)

    & $payloadBlock @PayloadArgs
}
finally {
    Remove-Variable payloadText -Force -ErrorAction SilentlyContinue
    Remove-Variable payloadBlock -Force -ErrorAction SilentlyContinue
    [GC]::Collect()
}
