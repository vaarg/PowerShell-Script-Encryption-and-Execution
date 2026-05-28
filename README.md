## New-CmsPayloadPackage.ps1

```PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\New-CmsPayloadPackage.ps1 -SourceScriptPath .\SensitiveScript.ps1
```
or:
```PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\New-CmsPayloadPackage.ps1 `
  -SourceScriptPath .\SensitiveScript.ps1 `
  -OutputDirectory .\package `
  -CertificateSubject "CN=Automation Payload Encryption"
```

Creates:
```
payload.cms
payload-decryption.pfx
payload-encryption-public.cer
```

## Run-EncryptedScript.ps1

```PowerShell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\runner.ps1 -PayloadPath .\payload.cms -PfxPath .\payload.pfx
```
And to pass args (after `--`):
```
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\runner.ps1 -PayloadPath .\payload.cms -PfxPath .\payload.pfx -- -Target "server01" -Mode "Audit"
```

Only the following are required for the runner:
```
payload.cms
payload-decryption.pfx
```
