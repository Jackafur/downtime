# Copies the Downtime addon into the WoW Forever AddOns folder. A new addon needs a full game restart to be seen (a /reload is
# enough for later changes to its Lua files).
$src = Join-Path $PSScriptRoot 'Downtime'
$dst = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Downtime'
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item "$src\*" $dst -Force
Write-Host "Installed to $dst. Fully restart WoW the first time so it finds the new addon and its key binding."
