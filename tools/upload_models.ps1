# Upload the Blender models (assets/models/*.glb) to Roblox from Windows, without saving your key anywhere.
# Asks for your Open Cloud API key in a hidden prompt, keeps it only in this PowerShell process, runs
# tools/upload_models.py (which uploads only new or changed models and writes src/shared/ModelIds.luau), then
# forgets it. Extra arguments go to the uploader, e.g. a list of model names.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\upload_models.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$secure = Read-Host "Paste your Roblox Open Cloud API key (it won't be shown)" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
	$env:ROBLOX_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
	[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

try {
	Push-Location $root
	if (Get-Command py -ErrorAction SilentlyContinue) {
		& py tools\upload_models.py @args
	} else {
		& python tools\upload_models.py @args
	}
} finally {
	Pop-Location
	Remove-Item Env:ROBLOX_API_KEY -ErrorAction SilentlyContinue
}
