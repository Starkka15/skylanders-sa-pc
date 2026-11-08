# Starts the PC build for a play session: no timer, hides the phantom "Xbox 360 Controller"
# (045E:028E, Steam's virtual pad) so the real pad is player 1, logs fps.
# The portal service must already be running (tools\skyportal.py / decky-skyportal py_modules).
param([string]$Name = 'play', [string]$Config = 'win-amd64-relwithdebinfo')
$dir = "H:\skylanders-sa\out\build\$Config"
$logs = 'H:\skylanders-sa\logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$env:SDL_GAMECONTROLLER_IGNORE_DEVICES = '0x045E/0x028E'
$p = Start-Process -FilePath "$dir\skylanders_sa.exe" -WorkingDirectory $dir -PassThru `
    -ArgumentList '--game_data_root', 'H:\skylanders-sa\game\files', '--log_file', "$logs\$Name.log", '--log_flush_interval', '1', '--fps_log', 'true'
"started pid $($p.Id), log $logs\$Name.log"
