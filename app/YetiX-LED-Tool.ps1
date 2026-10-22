# Yeti X LED Studio
# Controls the Blue Yeti X LEDs through the local G HUB agent (ws://127.0.0.1:9010) without the
# colour/brightness limits of the G HUB UI, and can store the result on the microphone.
param([switch]$SelfTest)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class YxNative {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
  [DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
}
'@

$CardType    = 'type.googleapis.com/logi.protocol.cards.Card'
$EffectsType = 'type.googleapis.com/logi.protocol.firmware_lighting.Effects'
$AppDir      = Join-Path $env:LOCALAPPDATA 'YetiX-LED-Tool'
$SettingsFile = Join-Path $AppDir 'settings.json'

#region Language
$Strings = @{
  en = @{
    appName = 'Yeti X LED Studio'; subtitle = 'LED STUDIO'; lighting = 'Lighting'
    RING = 'RING'; MODE = 'MODE'; PATTERN = 'PATTERN'; METERING = 'METERING'; OTHER = 'OTHER'
    ZONE_PRIMARY = 'Live'; ZONE_BRANDING = 'Mute'
    ZONE_LEFT_SIDE = 'Mode 1'; ZONE_RIGHT_SIDE = 'Mode 2'; ZONE_COMBINED = 'Mode 3'
    ZONE_ONE = 'Pattern 1'; ZONE_TWO = 'Pattern 2'; ZONE_THREE = 'Pattern 3'; ZONE_FOUR = 'Pattern 4'
    ZONE_FIVE = 'Normal'; ZONE_SIX = 'High'; ZONE_SEVEN = 'Peak'
    tabHint_RING = 'Ring around the knob while live and while muted.'
    tabHint_MODE = 'Indicators for the knob mode (gain, headphones, blend).'
    tabHint_PATTERN = 'Polar pattern indicators on the back.'
    tabHint_METERING = 'Level meter colours while the knob is in mic gain mode.'
    tabHint_OTHER = 'Further zones reported by the device.'
    color = 'COLOR'; brightness = 'BRIGHTNESS'; presets = 'PRESETS'; custom = 'CUSTOM'
    effect = 'EFFECT'; speed = 'SPEED (ms)'; identify = 'IDENTIFY'; FIXED = 'Fixed'; BREATHING = 'Breathing'
    save = 'SAVE TO MIC'; apply = 'APPLY'; off = 'ALL OFF'; reload = 'RELOAD'; import = 'IMPORT'; export = 'EXPORT'
    live = 'Live preview'; showMuted = 'Show muted state'
    previewNote = 'Preview shows real values - very dark values can look black here but still glow on the mic.'
    connecting = 'Connecting to G HUB ...'; connected = 'Connected'; disconnected = 'Not connected'
    loaded = 'Loaded current colours from {0}.'; applied = 'Applied (G HUB only). Use "Save to mic" to store it on the device.'
    saved = 'Saved to the microphone and G HUB.'; identifyRun = '{0} flashes white for 2 seconds ...'; identifyDone = 'Identify finished, colours restored.'
    allOff = 'All zones set to off.'; presetSaved = 'Preset saved: {0}'; presetLoaded = 'Preset loaded: {0}'
    errNoGhub = 'G HUB is not responding. Is G HUB running (tray icon)?'; errNoDevice = 'No Yeti X with LED control found in G HUB. Is it plugged in?'
    errNoReply = 'No reply from G HUB for {0}.'; errGhub = 'G HUB reported: {0}'; errTooLarge = 'Reply from port 9010 was unexpectedly large and was rejected.'
  }
  de = @{
    appName = 'Yeti X LED Studio'; subtitle = 'LED STUDIO'; lighting = 'Beleuchtung'
    RING = 'RING'; MODE = 'MODUS'; PATTERN = 'PATTERN'; METERING = 'PEGEL'; OTHER = 'SONSTIGE'
    ZONE_PRIMARY = 'Live'; ZONE_BRANDING = 'Stumm'
    ZONE_LEFT_SIDE = 'Modus 1'; ZONE_RIGHT_SIDE = 'Modus 2'; ZONE_COMBINED = 'Modus 3'
    ZONE_ONE = 'Pattern 1'; ZONE_TWO = 'Pattern 2'; ZONE_THREE = 'Pattern 3'; ZONE_FOUR = 'Pattern 4'
    ZONE_FIVE = 'Normal'; ZONE_SIX = 'Hoch'; ZONE_SEVEN = 'Spitze'
    tabHint_RING = 'Ring um den Drehknopf – live und stummgeschaltet.'
    tabHint_MODE = 'Anzeigen für den Knopf-Modus (Gain, Kopfhörer, Mix).'
    tabHint_PATTERN = 'Richtcharakteristik-Anzeigen auf der Rückseite.'
    tabHint_METERING = 'Pegelanzeige, wenn der Knopf im Mikrofon-Gain-Modus ist.'
    tabHint_OTHER = 'Weitere Zonen, die das Gerät meldet.'
    color = 'FARBE'; brightness = 'HELLIGKEIT'; presets = 'VORLAGEN'; custom = 'EIGENE'
    effect = 'EFFEKT'; speed = 'TEMPO (ms)'; identify = 'IDENTIFIZIEREN'; FIXED = 'Fest'; BREATHING = 'Pulsieren'
    save = 'AUFS MIKRO SPEICHERN'; apply = 'ANWENDEN'; off = 'ALLE AUS'; reload = 'NEU LADEN'; import = 'IMPORT'; export = 'EXPORT'
    live = 'Live-Vorschau'; showMuted = 'Stumm-Zustand zeigen'
    previewNote = 'Die Vorschau zeigt echte Werte – sehr dunkle Werte wirken hier schwarz, leuchten am Mikro aber noch.'
    connecting = 'Verbinde mit G HUB ...'; connected = 'Verbunden'; disconnected = 'Nicht verbunden'
    loaded = 'Aktuelle Farben von {0} geladen.'; applied = 'Angewendet (nur G HUB). „Aufs Mikro speichern“ speichert es im Gerät.'
    saved = 'Aufs Mikro und in G HUB gespeichert.'; identifyRun = '{0} leuchtet 2 Sekunden weiß ...'; identifyDone = 'Identifizieren fertig, Farben wiederhergestellt.'
    allOff = 'Alle Zonen ausgeschaltet.'; presetSaved = 'Preset gespeichert: {0}'; presetLoaded = 'Preset geladen: {0}'
    errNoGhub = 'G HUB antwortet nicht. Läuft G HUB (Symbol unten rechts)?'; errNoDevice = 'Kein Yeti X mit LED-Steuerung in G HUB gefunden. Ist es angesteckt?'
    errNoReply = 'Keine Antwort von G HUB auf {0}.'; errGhub = 'G HUB meldet: {0}'; errTooLarge = 'Antwort von Port 9010 war unerwartet groß und wurde verworfen.'
  }
}
$script:lang = 'en'
try { $s = Get-Content -LiteralPath $SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json; if ($s.lang -in 'en', 'de') { $script:lang = $s.lang } } catch { }
function T([string]$key) { $v = $Strings[$script:lang][$key]; if ($null -eq $v) { $key } else { $v } }
#endregion

#region G HUB websocket
$script:ws = $null
$script:buf = [byte[]]::new(4194304)
$script:pending = $null
$script:msgCounter = 0
$None = [Threading.CancellationToken]::None
$MaxMessageChars = 16MB

function Connect-Agent {
  if ($script:ws -and $script:ws.State -eq 'Open') { return }
  $script:ws = [System.Net.WebSockets.ClientWebSocket]::new()
  $script:ws.Options.AddSubProtocol('json')
  $script:ws.Options.SetRequestHeader('Origin', 'file://')
  $script:pending = $null
  $ok = $false
  try { $ok = $script:ws.ConnectAsync([Uri]'ws://127.0.0.1:9010', $None).Wait(3000) } catch { }
  if (-not $ok) { $script:ws = $null; throw (T 'errNoGhub') }
}

function Read-AgentMessage([int]$ms) {
  $deadline = [DateTime]::Now.AddMilliseconds($ms)
  $sb = [Text.StringBuilder]::new()
  while ($true) {
    if (-not $script:pending) { $script:pending = $script:ws.ReceiveAsync([ArraySegment[byte]]::new($script:buf), $None) }
    $left = [int]($deadline - [DateTime]::Now).TotalMilliseconds
    if ($left -le 0 -or -not $script:pending.Wait($left)) { return $null }
    $r = $script:pending.Result
    $script:pending = $null
    [void]$sb.Append([Text.Encoding]::UTF8.GetString($script:buf, 0, $r.Count))
    if ($sb.Length -gt $MaxMessageChars) {   # refuse oversized replies instead of buffering without limit
      try { $script:ws.Abort() } catch { }
      $script:ws = $null; $script:pending = $null
      throw (T 'errTooLarge')
    }
    if ($r.EndOfMessage) { return $sb.ToString() }
  }
}

function Invoke-Agent([string]$Verb, [string]$Path, $Payload) {
  Connect-Agent
  $script:msgCounter++
  $id = "yetix-studio-$($script:msgCounter)"
  $msg = [ordered]@{ msgId = $id; verb = $Verb; path = $Path }
  if ($null -ne $Payload) { $msg.payload = $Payload }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($msg | ConvertTo-Json -Depth 30 -Compress))
  try {
    [void]$script:ws.SendAsync([ArraySegment[byte]]::new($bytes), 'Text', $true, $None).Wait(3000)
    $deadline = [DateTime]::Now.AddSeconds(6)
    while ([DateTime]::Now -lt $deadline) {
      $s = Read-AgentMessage ([int]($deadline - [DateTime]::Now).TotalMilliseconds)
      if (-not $s) { break }
      if ($s.IndexOf("`"$id`"") -lt 0) { continue }   # ignore broadcasts
      $o = $s | ConvertFrom-Json
      if ($o.msgId -ne $id) { continue }
      if ($o.result.code -ne 'SUCCESS') { throw ((T 'errGhub') -f "$($o.result.code) $($o.result.what)") }
      return $o.payload
    }
  } catch {
    if ($script:ws -and $script:ws.State -ne 'Open') { $script:ws = $null }
    throw
  }
  throw ((T 'errNoReply') -f "$Verb $Path")
}
#endregion

#region Device, card and zone state
$ZoneGroups = [ordered]@{
  ZONE_PRIMARY = 'RING'; ZONE_BRANDING = 'RING'
  ZONE_LEFT_SIDE = 'MODE'; ZONE_RIGHT_SIDE = 'MODE'; ZONE_COMBINED = 'MODE'
  ZONE_ONE = 'PATTERN'; ZONE_TWO = 'PATTERN'; ZONE_THREE = 'PATTERN'; ZONE_FOUR = 'PATTERN'
  ZONE_FIVE = 'METERING'; ZONE_SIX = 'METERING'; ZONE_SEVEN = 'METERING'
}
$script:dev = $null
$script:card = $null
$script:zones = [Collections.ArrayList]::new()

function ConvertTo-Hex([int]$r, [int]$g, [int]$b) { '#{0:x2}{1:x2}{2:x2}' -f $r, $g, $b }
function ConvertFrom-Hex([string]$hex) {
  $h = "$hex".Trim().TrimStart('#')
  if ($h -notmatch '^[0-9a-fA-F]{6}$') { return $null }
  return @([Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16))
}
function Get-EffectColorHex($e) {
  $p = if ($e.fixedParams) { $e.fixedParams } elseif ($e.breathingParams) { $e.breathingParams } else { $null }
  if (-not $p -or -not $p.color) { return '#000000' }
  if ($p.color.hex) { return $p.color.hex.ToLower() }
  if ($p.color.rgba) { return ConvertTo-Hex ([int](255 * $p.color.rgba.red)) ([int](255 * $p.color.rgba.green)) ([int](255 * $p.color.rgba.blue)) }
  return '#000000'
}
function Get-Hsv([int]$r, [int]$g, [int]$b) {
  $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b)); $d = $max - $min
  $h = 0.0
  if ($d -gt 0) {
    if ($max -eq $r) { $h = 60 * ((($g - $b) / $d) % 6) } elseif ($max -eq $g) { $h = 60 * ((($b - $r) / $d) + 2) } else { $h = 60 * ((($r - $g) / $d) + 4) }
  }
  if ($h -lt 0) { $h += 360 }
  $s = if ($max -eq 0) { 0.0 } else { $d / $max }
  return @($h, $s, $max)
}
function Get-Rgb([double]$h, [double]$s, [double]$v) {
  $chroma = $v * $s; $x = $chroma * (1 - [Math]::Abs((($h / 60) % 2) - 1)); $m = $v - $chroma
  $sector = [int][Math]::Floor($h / 60) % 6
  $rgb = switch ($sector) { 0 { $chroma, $x, 0 } 1 { $x, $chroma, 0 } 2 { 0, $chroma, $x } 3 { 0, $x, $chroma } 4 { $x, 0, $chroma } default { $chroma, 0, $x } }
  return @([int][Math]::Round($rgb[0] + $m), [int][Math]::Round($rgb[1] + $m), [int][Math]::Round($rgb[2] + $m))
}

function Get-YetiState {
  $devs = Invoke-Agent 'GET' '/devices/list' $null
  $dev = $null; $slotId = $null
  foreach ($d in $devs.deviceInfos) {
    if (-not $d.slots) { continue }
    $s = $d.slots.PSObject.Properties.Name | Where-Object { $_ -like '*_lighting_setting_firmware' } | Select-Object -First 1
    if ($s -and $d.deviceType -eq 'MICROPHONE') { $dev = $d; $slotId = $s; break }
  }
  if (-not $dev) { throw (T 'errNoDevice') }

  $active = Invoke-Agent 'GET' '/profile/active' $null
  $profiles = (Invoke-Agent 'GET' '/profiles' $null).profiles
  $cardId = $null
  foreach ($p in @($profiles | Where-Object { $_.id -eq $active.id }) + @($profiles)) {
    $a = $p.assignments | Where-Object { $_.slotId -eq $slotId } | Select-Object -First 1
    if ($a) { $cardId = $a.cardId; break }
  }
  if (-not $cardId) { $cardId = $dev.slots.$slotId.defaultCard }
  $cardObj = Invoke-Agent 'GET' '/card' ([ordered]@{ '@type' = $CardType; id = $cardId })

  $support = @{}
  foreach ($z in $dev.capabilities.lightingSupport.zones) {
    $support[$z.zoneType] = @($z.supportedEffects | ForEach-Object { $_.id } | Where-Object { $_ -in 'FIXED', 'BREATHING' })
  }
  $effects = @{}
  foreach ($e in $cardObj.firmwareLightingSettings.effects) { $effects[$e.zoneType] = $e }

  $names = @($ZoneGroups.Keys | Where-Object { $effects.ContainsKey($_) -or $support.ContainsKey($_) })
  $names += @(@($effects.Keys) + @($support.Keys) | Sort-Object -Unique | Where-Object { -not $ZoneGroups.Contains($_) })

  $script:zones.Clear()
  foreach ($n in $names) {
    $e = $effects[$n]
    $rgb = ConvertFrom-Hex $(if ($e) { Get-EffectColorHex $e } else { '#000000' })
    $sup = if ($support[$n] -and $support[$n].Count) { $support[$n] } else { @('FIXED') }
    $hsv = Get-Hsv $rgb[0] $rgb[1] $rgb[2]
    [void]$script:zones.Add(@{
      Zone = $n; Group = $(if ($ZoneGroups.Contains($n)) { $ZoneGroups[$n] } else { 'OTHER' })
      R = $rgb[0]; G = $rgb[1]; B = $rgb[2]; H = $hsv[0]; S = $(if ($hsv[2] -gt 0) { $hsv[1] } else { 1.0 })
      Effect = $(if ($e -and $sup -contains $e.id) { $e.id } else { $sup[0] })
      Period = $(if ($e -and $e.breathingParams -and $e.breathingParams.periodInMs) { [Math]::Min(20000, [Math]::Max(500, [int]$e.breathingParams.periodInMs)) } else { 5000 })
      Supported = $sup
    })
  }
  $script:dev = $dev
  $script:card = $cardObj
}

function New-Effect([string]$Zone, [string]$Effect, [string]$Hex, [int]$Period, [bool]$Persistent) {
  $color = [ordered]@{ tag = ''; hex = $Hex }
  if ($Effect -eq 'BREATHING') {
    return [ordered]@{ id = 'BREATHING'; zoneType = $Zone; persistent = $Persistent; breathingParams = [ordered]@{ color = $color; periodInMs = $Period; intensity = 1 } }
  }
  return [ordered]@{ id = 'FIXED'; zoneType = $Zone; persistent = $Persistent; fixedParams = [ordered]@{ color = $color } }
}

function Get-ZoneEffects {
  foreach ($z in $script:zones) { [pscustomobject]@{ zone = $z.Zone; effect = $z.Effect; hex = (ConvertTo-Hex $z.R $z.G $z.B); period = $z.Period } }
}

function Set-YetiLighting($Effects, [bool]$SaveOnMic) {
  $cardOut = [ordered]@{ '@type' = $CardType }
  foreach ($p in $script:card.PSObject.Properties) { if ($p.Name -ne '@type') { $cardOut[$p.Name] = $p.Value } }
  $fls = [ordered]@{ effects = @($Effects | ForEach-Object { New-Effect $_.zone $_.effect $_.hex $_.period $false }) }
  $fls.powerSavingEffects = @(if ($script:card.firmwareLightingSettings.powerSavingEffects) { $script:card.firmwareLightingSettings.powerSavingEffects })
  $cardOut.firmwareLightingSettings = $fls
  $script:card = Invoke-Agent 'SET' '/card' $cardOut
  if ($SaveOnMic) {
    $fw = [ordered]@{ '@type' = $EffectsType; effects = @($Effects | ForEach-Object { New-Effect $_.zone $_.effect $_.hex $_.period $true }) }
    [void](Invoke-Agent 'SET' "/lighting/$($script:dev.id)/firmware/effects" $fw)
  }
}
#endregion

if ($SelfTest) {
  Get-YetiState
  "Device: $($script:dev.displayName) ($($script:dev.id)), card: $($script:card.id)"
  foreach ($z in $script:zones) { '{0,-16} {1,-8} {2,-9} {3}  supports: {4}' -f $z.Zone, $z.Group, $z.Effect, (ConvertTo-Hex $z.R $z.G $z.B), ($z.Supported -join ',') }
  return
}

#region Theme and drawing helpers
[void][YxNative]::SetProcessDPIAware()
[void][YxNative]::SetCurrentProcessExplicitAppUserModelID('YetiX.LEDStudio')   # own taskbar entry + icon instead of PowerShell's
[Windows.Forms.Application]::EnableVisualStyles()
$screenG = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $Sc = $screenG.DpiX / 96.0; $screenG.Dispose()
function P([double]$v) { [int][Math]::Round($v * $Sc) }

$C = @{
  Bg = [Drawing.Color]::FromArgb(0, 0, 0); Rail = [Drawing.Color]::FromArgb(10, 10, 11)
  Card = [Drawing.Color]::FromArgb(31, 32, 35); CardHi = [Drawing.Color]::FromArgb(44, 45, 50); Line = [Drawing.Color]::FromArgb(58, 60, 66)
  Fg = [Drawing.Color]::FromArgb(240, 241, 243); Dim = [Drawing.Color]::FromArgb(150, 154, 162); Faint = [Drawing.Color]::FromArgb(92, 96, 104)
  Accent = [Drawing.Color]::FromArgb(0, 168, 252); AccentDark = [Drawing.Color]::FromArgb(0, 120, 190)
  Ok = [Drawing.Color]::FromArgb(84, 214, 132); Err = [Drawing.Color]::FromArgb(255, 107, 107); Input = [Drawing.Color]::FromArgb(22, 23, 26)
}
$FontFamily = 'Segoe UI'
function F([double]$size, [string]$style = 'Regular', [string]$family = $FontFamily) { [Drawing.Font]::new($family, [single]$size, [Drawing.FontStyle]$style) }
$Fonts = @{
  Title = F 24 'Bold' 'Segoe UI'; Sub = F 8.5 'Bold'; Card = F 15 'Regular' 'Segoe UI Semilight'
  Tab = F 9.5 'Regular'; TabOn = F 9.5 'Bold'; Row = F 9.5 'Bold'; Small = F 8.5; Label = F 8 'Bold'; Btn = F 9 'Bold'; Body = F 9.5
}

function New-RoundPath([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
  $p = [Drawing.Drawing2D.GraphicsPath]::new()
  $d = [Math]::Max(1.0, 2 * $r)
  $p.AddArc([single]$x, [single]$y, [single]$d, [single]$d, 180, 90)
  $p.AddArc([single]($x + $w - $d), [single]$y, [single]$d, [single]$d, 270, 90)
  $p.AddArc([single]($x + $w - $d), [single]($y + $h - $d), [single]$d, [single]$d, 0, 90)
  $p.AddArc([single]$x, [single]($y + $h - $d), [single]$d, [single]$d, 90, 90)
  $p.CloseFigure(); return $p
}
function Set-DoubleBuffered($ctrl) {
  $ctrl.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($ctrl, $true, $null)
}
function New-Canvas([int]$x, [int]$y, [int]$w, [int]$h, $parent) {
  $p = [Windows.Forms.Panel]::new()
  $p.SetBounds($x, $y, $w, $h); $p.BackColor = $parent.BackColor
  Set-DoubleBuffered $p
  $parent.Controls.Add($p)
  return $p
}
function New-Text([string]$text, $font, $color, [int]$x, [int]$y, $parent) {
  $l = [Windows.Forms.Label]::new()
  $l.Text = $text; $l.Font = $font; $l.ForeColor = $color; $l.BackColor = $parent.BackColor; $l.AutoSize = $true
  $l.Location = [Drawing.Point]::new($x, $y)
  $parent.Controls.Add($l)
  return $l
}
function Get-ZoneColor($z) { [Drawing.Color]::FromArgb($z.R, $z.G, $z.B) }
function Get-ZoneByName([string]$n) { foreach ($z in $script:zones) { if ($z.Zone -eq $n) { return $z } } return $null }

function Draw-Led($g, [double]$cx, [double]$cy, [double]$r, [Drawing.Color]$col, [bool]$selected) {
  $lum = [Math]::Max($col.R, [Math]::Max($col.G, $col.B))
  if ($lum -gt 0) {
    for ($k = 3; $k -ge 1; $k--) {
      $gr = $r * (1 + 0.55 * $k)
      $a = [int][Math]::Min(90, (10 + $lum / 4) / $k)
      $b = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($a, $col))
      $g.FillEllipse($b, [single]($cx - $gr), [single]($cy - $gr), [single](2 * $gr), [single](2 * $gr)); $b.Dispose()
    }
  }
  $b = [Drawing.SolidBrush]::new($col)
  $g.FillEllipse($b, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $b.Dispose()
  $pen = if ($selected) { [Drawing.Pen]::new($C.Accent, [single](P 2.5)) } else { [Drawing.Pen]::new($C.Line, [single](P 1.2)) }
  $g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $pen.Dispose()
}
#endregion

#region Window layout
$form = [Windows.Forms.Form]::new()
$form.AutoScaleMode = 'None'
$form.Text = T 'appName'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = [Drawing.Size]::new((P 1180), (P 780))
$form.MinimumSize = $form.Size
$form.BackColor = $C.Bg; $form.ForeColor = $C.Fg; $form.Font = $Fonts.Body
$iconPath = Join-Path $PSScriptRoot 'logo.ico'
if (Test-Path -LiteralPath $iconPath) { $form.Icon = [Drawing.Icon]::new($iconPath) }
$logoImg = $null
$logoPath = Join-Path $PSScriptRoot 'logo.png'
if (Test-Path -LiteralPath $logoPath) { $logoImg = [Drawing.Image]::FromStream([IO.MemoryStream]::new([IO.File]::ReadAllBytes($logoPath))) }   # no file lock
Set-DoubleBuffered $form

# Left rail (logo + active lighting section), like the G HUB device page
$rail = New-Canvas 0 0 (P 76) (P 780) $form
$rail.BackColor = $C.Rail; $rail.Anchor = 'Top,Left,Bottom'
$rail.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
  if ($logoImg) { $g.DrawImage($logoImg, (P 16), (P 18), (P 44), (P 44)) }
  $path = New-RoundPath (P 16) (P 96) (P 44) (P 44) (P 9)
  $b = [Drawing.SolidBrush]::new($C.Accent); $g.FillPath($b, $path); $b.Dispose()
  # sun / lighting glyph
  $pen = [Drawing.Pen]::new([Drawing.Color]::White, [single](P 2)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $cx = (P 38); $cy = (P 118)
  $g.DrawEllipse($pen, [single]($cx - (P 5)), [single]($cy - (P 5)), [single](P 10), [single](P 10))
  for ($i = 0; $i -lt 8; $i++) {
    $a = $i * [Math]::PI / 4
    $g.DrawLine($pen, [single]($cx + [Math]::Cos($a) * (P 9)), [single]($cy + [Math]::Sin($a) * (P 9)), [single]($cx + [Math]::Cos($a) * (P 12)), [single]($cy + [Math]::Sin($a) * (P 12)))
  }
  $pen.Dispose()
})

$title = New-Text 'Yeti X' $Fonts.Title $C.Fg (P 100) (P 14) $form
$subtitle = New-Text (T 'subtitle') $Fonts.Sub $C.Accent (P 104) (P 62) $form

# Status pill + language switch (top right)
$top = New-Canvas (P 760) (P 22) (P 400) (P 40) $form
$top.Anchor = 'Top,Right'
$script:connected = $false
$top.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $txt = if ($script:connected) { "$(T 'connected') · $($script:dev.displayName)" } else { T 'disconnected' }
  $tw = [Windows.Forms.TextRenderer]::MeasureText($txt, $Fonts.Small).Width
  $w = $tw + (P 36); $x = $top.Width - $w - (P 4)
  $path = New-RoundPath $x (P 6) $w (P 28) (P 14)
  $b = [Drawing.SolidBrush]::new($C.Card); $g.FillPath($b, $path); $b.Dispose()
  $dot = [Drawing.SolidBrush]::new($(if ($script:connected) { $C.Ok } else { $C.Err }))
  $g.FillEllipse($dot, [single]($x + (P 12)), [single](P 16), [single](P 8), [single](P 8)); $dot.Dispose()
  [Windows.Forms.TextRenderer]::DrawText($g, $txt, $Fonts.Small, [Drawing.Point]::new($x + (P 26), (P 12)), $C.Fg)
})

# Language switch at the bottom of the rail (where G HUB keeps its settings button)
function New-LangLabel([string]$code, [int]$y) {
  $l = [Windows.Forms.Label]::new()
  $l.Text = $code.ToUpper(); $l.Tag = $code; $l.AutoSize = $false; $l.TextAlign = 'MiddleCenter'
  $l.SetBounds((P 16), $y, (P 44), (P 30)); $l.BackColor = $C.Rail; $l.Cursor = 'Hand'; $l.Anchor = 'Left,Bottom'
  $l.Add_Click({ try { Set-Language $this.Tag } catch { Set-Status $_.Exception.Message 'err' } })
  $l.Add_Paint({
    if ($script:lang -eq $this.Tag) {
      $p = New-RoundPath 0 0 ($this.Width - 1) ($this.Height - 1) (P 7)
      $pen = [Drawing.Pen]::new($C.Accent, [single](P 1.5)); $_.Graphics.SmoothingMode = 'AntiAlias'; $_.Graphics.DrawPath($pen, $p); $pen.Dispose()
    }
  })
  $rail.Controls.Add($l)
  return $l
}
$langEn = New-LangLabel 'en' ($rail.Height - (P 92))
$langDe = New-LangLabel 'de' ($rail.Height - (P 56))
function Update-LangLabels {
  foreach ($l in $langEn, $langDe) {
    $on = $script:lang -eq $l.Tag
    $l.Font = $(if ($on) { $Fonts.TabOn } else { $Fonts.Tab })
    $l.ForeColor = $(if ($on) { $C.Fg } else { $C.Faint })
    $l.Invalidate()
  }
  $top.Invalidate()
}

# Lighting card
$cardX = (P 100); $cardY = (P 96); $cardW = (P 450); $cardH = (P 600)
$cardPanel = New-Canvas $cardX $cardY $cardW $cardH $form
$cardPanel.BackColor = $C.Card
$cardPanel.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.Clear($C.Bg)
  $path = New-RoundPath 0 0 ($cardPanel.Width - 1) ($cardPanel.Height - 1) (P 12)
  $b = [Drawing.SolidBrush]::new($C.Card); $g.FillPath($b, $path); $b.Dispose()
  $pen = [Drawing.Pen]::new($C.Line, 1); $g.DrawLine($pen, (P 22), (P 300), $cardPanel.Width - (P 22), (P 300)); $pen.Dispose()
})
function New-CardText([string]$text, $font, $color, [int]$x, [int]$y) { $l = New-Text $text $font $color $x $y $cardPanel; $l.BackColor = $C.Card; return $l }

$cardTitle = New-CardText (T 'lighting') $Fonts.Card $C.Fg (P 20) (P 16)

# Tabs
$tabs = New-Canvas (P 20) (P 58) (P 410) (P 30) $cardPanel
$tabs.BackColor = $C.Card; $tabs.Cursor = 'Hand'
$script:tab = 'RING'
$script:tabRects = @()
$tabs.Add_Paint({
  $g = $_.Graphics; $g.TextRenderingHint = 'ClearTypeGridFit'
  $script:tabRects = @()
  $x = 0
  foreach ($t in Get-TabList) {
    $on = $script:tab -eq $t
    $font = if ($on) { $Fonts.TabOn } else { $Fonts.Tab }
    $txt = T $t
    $w = [Windows.Forms.TextRenderer]::MeasureText($txt, $font).Width
    [Windows.Forms.TextRenderer]::DrawText($g, $txt, $font, [Drawing.Point]::new($x, (P 4)), $(if ($on) { $C.Fg } else { $C.Dim }))
    if ($on) { $b = [Drawing.SolidBrush]::new($C.Fg); $g.FillRectangle($b, $x + (P 3), (P 26), $w - (P 6), (P 2)); $b.Dispose() }
    $script:tabRects += , @($x, $w, $t)
    $x += $w + (P 14)
  }
})
$tabs.Add_MouseClick({
  foreach ($r in $script:tabRects) { if ($_.X -ge $r[0] -and $_.X -lt $r[0] + $r[1]) { Select-Tab $r[2]; break } }
})
$tabHint = New-CardText '' $Fonts.Small $C.Dim (P 22) (P 96)
$tabHint.AutoSize = $false; $tabHint.Size = [Drawing.Size]::new((P 410), (P 34))

# Zone list (rows painted like G HUB: name left, round swatch right)
$list = New-Canvas (P 12) (P 132) (P 426) (P 160) $cardPanel
$list.BackColor = $C.Card; $list.Cursor = 'Hand'
$script:listZones = @()
$list.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $rowH = [Math]::Min((P 40), [int]($list.Height / [Math]::Max(1, $script:listZones.Count)))
  $y = 0
  foreach ($z in $script:listZones) {
    $sel = $script:sel -eq $z
    if ($sel) { $p = New-RoundPath 0 $y ($list.Width - 1) ($rowH - (P 4)) (P 8); $b = [Drawing.SolidBrush]::new($C.CardHi); $g.FillPath($b, $p); $b.Dispose() }
    $mid = $y + ($rowH - (P 4)) / 2
    [Windows.Forms.TextRenderer]::DrawText($g, (T $z.Zone).ToUpper(), $Fonts.Row, [Drawing.Point]::new((P 12), [int]($mid - (P 9))), $C.Fg)
    $pct = [Math]::Round([Math]::Max($z.R, [Math]::Max($z.G, $z.B)) / 2.55, 1)
    $info = "$(T $z.Effect) · $(ConvertTo-Hex $z.R $z.G $z.B) · $pct %"
    $iw = [Windows.Forms.TextRenderer]::MeasureText($info, $Fonts.Small).Width
    [Windows.Forms.TextRenderer]::DrawText($g, $info, $Fonts.Small, [Drawing.Point]::new($list.Width - (P 48) - $iw, [int]($mid - (P 8))), $C.Dim)
    $r = (P 11); $cx = $list.Width - (P 24)
    $b = [Drawing.SolidBrush]::new((Get-ZoneColor $z)); $g.FillEllipse($b, [single]($cx - $r), [single]($mid - $r), [single](2 * $r), [single](2 * $r)); $b.Dispose()
    $pen = [Drawing.Pen]::new($(if ($sel) { $C.Accent } else { [Drawing.Color]::FromArgb(110, 114, 122) }), [single](P 1.6))
    $g.DrawEllipse($pen, [single]($cx - $r), [single]($mid - $r), [single](2 * $r), [single](2 * $r)); $pen.Dispose()
    $y += $rowH
  }
})
$list.Add_MouseClick({
  $rowH = [Math]::Min((P 40), [int]($list.Height / [Math]::Max(1, $script:listZones.Count)))
  $i = [int][Math]::Floor($_.Y / $rowH)
  if ($i -ge 0 -and $i -lt $script:listZones.Count) { Select-Zone $script:listZones[$i] }
})

# Colour editor
$lblColor = New-CardText (T 'color') $Fonts.Label $C.Dim (P 22) (P 314)
$selName = New-CardText '' $Fonts.Label $C.Fg (P 120) (P 314)

$spectrum = New-Canvas (P 22) (P 336) (P 406) (P 22) $cardPanel
$spectrum.BackColor = $C.Card; $spectrum.Cursor = 'Hand'
$spectrum.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'
  $h = (P 10); $y = ($spectrum.Height - $h) / 2; $pad = (P 9); $w = $spectrum.Width - 2 * $pad
  $rect = [Drawing.RectangleF]::new($pad, $y, $w, $h)
  $lg = [Drawing.Drawing2D.LinearGradientBrush]::new($rect, [Drawing.Color]::Red, [Drawing.Color]::Red, 0.0)
  $blend = [Drawing.Drawing2D.ColorBlend]::new(7)
  $blend.Colors = [Drawing.Color[]]@([Drawing.Color]::FromArgb(255, 0, 0), [Drawing.Color]::FromArgb(255, 255, 0), [Drawing.Color]::FromArgb(0, 255, 0), [Drawing.Color]::FromArgb(0, 255, 255), [Drawing.Color]::FromArgb(0, 0, 255), [Drawing.Color]::FromArgb(255, 0, 255), [Drawing.Color]::FromArgb(255, 0, 0))
  $blend.Positions = [single[]]@(0, (1 / 6), (2 / 6), (3 / 6), (4 / 6), (5 / 6), 1)
  $lg.InterpolationColors = $blend
  $g.FillPath($lg, (New-RoundPath $pad $y $w $h ($h / 2))); $lg.Dispose()
  if ($script:sel) {
    $mx = $pad + ($script:sel.H / 360.0) * $w; $r = (P 8); $cy = $spectrum.Height / 2
    $hc = Get-Rgb $script:sel.H 1 255
    $b = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($hc[0], $hc[1], $hc[2])); $g.FillEllipse($b, [single]($mx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $b.Dispose()
    $pen = [Drawing.Pen]::new([Drawing.Color]::White, [single](P 2)); $g.DrawEllipse($pen, [single]($mx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $pen.Dispose()
  }
})
$spectrumDrag = {
  if ($_.Button -ne 'Left' -or -not $script:sel) { return }
  $pad = (P 9); $w = $spectrum.Width - 2 * $pad
  $hue = [Math]::Max(0.0, [Math]::Min(359.9, (($_.X - $pad) / $w) * 360))
  $z = $script:sel; $z.H = $hue; if ($z.S -lt 0.05) { $z.S = 1.0 }
  $v = [Math]::Max($z.R, [Math]::Max($z.G, $z.B)); if ($v -eq 0) { $v = 255 }
  $rgb = Get-Rgb $z.H $z.S $v
  Set-SelColor $rgb[0] $rgb[1] $rgb[2] $false
}
$spectrum.Add_MouseDown($spectrumDrag); $spectrum.Add_MouseMove($spectrumDrag)

$bright = New-Canvas (P 22) (P 366) (P 406) (P 22) $cardPanel
$bright.BackColor = $C.Card; $bright.Cursor = 'Hand'
$bright.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'
  $h = (P 10); $y = ($bright.Height - $h) / 2; $pad = (P 9); $w = $bright.Width - 2 * $pad
  $full = if ($script:sel) { Get-Rgb $script:sel.H $script:sel.S 255 } else { @(255, 255, 255) }
  $rect = [Drawing.RectangleF]::new($pad, $y, $w, $h)
  $lg = [Drawing.Drawing2D.LinearGradientBrush]::new($rect, [Drawing.Color]::Black, [Drawing.Color]::FromArgb($full[0], $full[1], $full[2]), 0.0)
  $g.FillPath($lg, (New-RoundPath $pad $y $w $h ($h / 2))); $lg.Dispose()
  $pen = [Drawing.Pen]::new($C.Line, 1); $g.DrawPath($pen, (New-RoundPath $pad $y $w $h ($h / 2))); $pen.Dispose()
  if ($script:sel) {
    $v = [Math]::Max($script:sel.R, [Math]::Max($script:sel.G, $script:sel.B))
    $mx = $pad + ($v / 255.0) * $w; $r = (P 8); $cy = $bright.Height / 2
    $b = [Drawing.SolidBrush]::new((Get-ZoneColor $script:sel)); $g.FillEllipse($b, [single]($mx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $b.Dispose()
    $pen = [Drawing.Pen]::new([Drawing.Color]::White, [single](P 2)); $g.DrawEllipse($pen, [single]($mx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $pen.Dispose()
  }
})
$brightDrag = {
  if ($_.Button -ne 'Left' -or -not $script:sel) { return }
  $pad = (P 9); $w = $bright.Width - 2 * $pad
  $v = [int][Math]::Round([Math]::Max(0.0, [Math]::Min(1.0, ($_.X - $pad) / $w)) * 255)
  $rgb = Get-Rgb $script:sel.H $script:sel.S $v
  Set-SelColor $rgb[0] $rgb[1] $rgb[2] $false
}
$bright.Add_MouseDown($brightDrag); $bright.Add_MouseMove($brightDrag)
$lblBright = New-CardText (T 'brightness') $Fonts.Label $C.Dim (P 22) (P 392)
$brightVal = New-CardText '' $Fonts.Small $C.Fg (P 300) (P 392)
$brightVal.AutoSize = $false; $brightVal.TextAlign = 'TopRight'; $brightVal.Size = [Drawing.Size]::new((P 128), (P 18))

# Preset swatches (round, like G HUB) - keep the current brightness so dark setups stay dark
$PresetColors = @(@(255, 0, 0), @(0, 168, 224), @(0, 255, 0), @(138, 43, 226), @(255, 127, 0), @(124, 252, 0), @(255, 230, 0), @(255, 255, 255), @(0, 0, 0))
$presets = New-Canvas (P 18) (P 416) (P 414) (P 34) $cardPanel
$presets.BackColor = $C.Card; $presets.Cursor = 'Hand'
$presets.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'
  for ($i = 0; $i -lt $PresetColors.Count; $i++) {
    $pc = $PresetColors[$i]; $cx = (P 16) + $i * (P 34); $cy = $presets.Height / 2; $r = (P 11)
    $b = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($pc[0], $pc[1], $pc[2])); $g.FillEllipse($b, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r)); $b.Dispose()
    if ($i -eq $PresetColors.Count - 1) {
      $pen = [Drawing.Pen]::new($C.Dim, [single](P 1.4)); $g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
      $g.DrawLine($pen, [single]($cx - $r * 0.7), [single]($cy + $r * 0.7), [single]($cx + $r * 0.7), [single]($cy - $r * 0.7)); $pen.Dispose()
    }
  }
})
$presets.Add_MouseClick({
  if (-not $script:sel) { return }
  $i = [int][Math]::Floor(($_.X - (P 5)) / (P 34))
  if ($i -lt 0 -or $i -ge $PresetColors.Count) { return }
  $pc = $PresetColors[$i]
  if ($i -eq $PresetColors.Count - 1) { Set-SelColor 0 0 0 $false; return }
  $hsv = Get-Hsv $pc[0] $pc[1] $pc[2]
  $v = [Math]::Max($script:sel.R, [Math]::Max($script:sel.G, $script:sel.B)); if ($v -eq 0) { $v = 255 }
  $script:sel.H = $hsv[0]; $script:sel.S = $hsv[1]
  $rgb = Get-Rgb $hsv[0] $hsv[1] $v
  Set-SelColor $rgb[0] $rgb[1] $rgb[2] $false
})

# Custom RGB / hex
$lblCustom = New-CardText (T 'custom') $Fonts.Label $C.Dim (P 22) (P 460)
function New-Num([int]$x, [int]$y) {
  $n = [Windows.Forms.NumericUpDown]::new()
  $n.Minimum = 0; $n.Maximum = 255; $n.Location = [Drawing.Point]::new($x, $y); $n.Width = (P 62)
  $n.BackColor = $C.Input; $n.ForeColor = $C.Fg; $n.BorderStyle = 'FixedSingle'; $n.Font = $Fonts.Body
  $cardPanel.Controls.Add($n); return $n
}
$chR = New-CardText 'R' $Fonts.Label $C.Dim (P 22) (P 487); $numR = New-Num (P 36) (P 482)
$chG = New-CardText 'G' $Fonts.Label $C.Dim (P 106) (P 487); $numG = New-Num (P 120) (P 482)
$chB = New-CardText 'B' $Fonts.Label $C.Dim (P 190) (P 487); $numB = New-Num (P 204) (P 482)
$hexBox = [Windows.Forms.TextBox]::new()
$hexBox.Location = [Drawing.Point]::new((P 282), (P 482)); $hexBox.Width = (P 92); $hexBox.Font = $Fonts.Body
$hexBox.BackColor = $C.Input; $hexBox.ForeColor = $C.Fg; $hexBox.BorderStyle = 'FixedSingle'
$cardPanel.Controls.Add($hexBox)

# Effect + speed + identify
$lblEffect = New-CardText (T 'effect') $Fonts.Label $C.Dim (P 22) (P 526)
$effectBox = [Windows.Forms.ComboBox]::new()
$effectBox.DropDownStyle = 'DropDownList'; $effectBox.FlatStyle = 'Flat'; $effectBox.Font = $Fonts.Body
$effectBox.Location = [Drawing.Point]::new((P 22), (P 546)); $effectBox.Width = (P 130)
$effectBox.BackColor = $C.Input; $effectBox.ForeColor = $C.Fg
$cardPanel.Controls.Add($effectBox)
$lblSpeed = New-CardText (T 'speed') $Fonts.Label $C.Dim (P 166) (P 526)
$speedBox = [Windows.Forms.NumericUpDown]::new()
$speedBox.Minimum = 500; $speedBox.Maximum = 20000; $speedBox.Increment = 250; $speedBox.Value = 5000
$speedBox.Location = [Drawing.Point]::new((P 166), (P 546)); $speedBox.Width = (P 92); $speedBox.Font = $Fonts.Body
$speedBox.BackColor = $C.Input; $speedBox.ForeColor = $C.Fg; $speedBox.BorderStyle = 'FixedSingle'
$cardPanel.Controls.Add($speedBox)

function New-Pill([string]$text, [bool]$primary, $parent) {
  $b = [Windows.Forms.Button]::new()
  $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = $(if ($primary) { 0 } else { 1 })
  $b.FlatAppearance.BorderColor = $C.Line
  $b.BackColor = $(if ($primary) { $C.Accent } else { $C.Card })
  $b.FlatAppearance.MouseOverBackColor = $(if ($primary) { [Drawing.Color]::FromArgb(40, 190, 255) } else { $C.CardHi })
  $b.FlatAppearance.MouseDownBackColor = $(if ($primary) { $C.AccentDark } else { $C.Line })
  $b.ForeColor = $(if ($primary) { [Drawing.Color]::Black } else { $C.Fg })
  $b.Font = $Fonts.Btn; $b.Cursor = 'Hand'; $b.Tag = $primary
  $parent.Controls.Add($b)
  Set-PillText $b $text
  return $b
}
function Set-PillText($b, [string]$text) {
  $b.Text = $text
  $w = [Windows.Forms.TextRenderer]::MeasureText($text, $b.Font).Width + (P 34)
  $b.Size = [Drawing.Size]::new($w, (P 36))
  $b.Region = [Drawing.Region]::new((New-RoundPath 0 0 $b.Width $b.Height ($b.Height / 2)))
}
$identifyBtn = New-Pill (T 'identify') $false $cardPanel
$identifyBtn.BackColor = $C.CardHi
$identifyBtn.Location = [Drawing.Point]::new((P 272), (P 543))

# Preview panel (stylised Yeti X front + back indicators)
$prev = New-Canvas (P 572) (P 96) (P 588) (P 600) $form
$prev.Anchor = 'Top,Left,Right,Bottom'
$script:hits = @()
$showMuted = [Windows.Forms.CheckBox]::new()
$showMuted.Text = T 'showMuted'; $showMuted.AutoSize = $true; $showMuted.ForeColor = $C.Dim; $showMuted.BackColor = $C.Bg; $showMuted.Font = $Fonts.Small
$showMuted.Location = [Drawing.Point]::new((P 16), (P 10))
$prev.Controls.Add($showMuted)
$showMuted.Add_CheckedChanged({ $prev.Invalidate() })
$prev.Add_Paint({
  $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
  $W = $prev.Width; $H = $prev.Height
  $script:hits = @()
  if ($script:zones.Count -eq 0) { return }
  $cx = $W / 2; $cy = $H * 0.40; $kr = [Math]::Min($W, $H) * 0.13

  # body
  $bw = $kr * 3.6; $bh = $H * 0.86
  $body = New-RoundPath ($cx - $bw / 2) ($H * 0.08) $bw $bh ($bw / 2.2)
  $lg = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.PointF]::new([single]($cx - $bw / 2), 0), [Drawing.PointF]::new([single]($cx + $bw / 2), 0), [Drawing.Color]::FromArgb(30, 31, 34), [Drawing.Color]::FromArgb(14, 14, 16))
  $blend = [Drawing.Drawing2D.ColorBlend]::new(3)
  $blend.Colors = [Drawing.Color[]]@([Drawing.Color]::FromArgb(18, 18, 20), [Drawing.Color]::FromArgb(40, 41, 45), [Drawing.Color]::FromArgb(14, 14, 16))
  $blend.Positions = [single[]]@(0, 0.45, 1); $lg.InterpolationColors = $blend
  $g.FillPath($lg, $body); $lg.Dispose()

  $add = { param($zone, $x, $y, $r) $z = Get-ZoneByName $zone; if ($z) { Draw-Led $g $x $y $r (Get-ZoneColor $z) ($script:sel -eq $z); $script:hits += , @($x, $y, [Math]::Max($r, (P 12)), $z) } }

  # metering arc (11 LEDs over the knob): 7 normal, 3 high, 1 peak
  for ($i = 0; $i -lt 11; $i++) {
    $a = (205 + $i * 13) * [Math]::PI / 180
    $zn = if ($i -lt 7) { 'ZONE_FIVE' } elseif ($i -lt 10) { 'ZONE_SIX' } else { 'ZONE_SEVEN' }
    & $add $zn ($cx + [Math]::Cos($a) * $kr * 1.62) ($cy + [Math]::Sin($a) * $kr * 1.62) (P 5.5)
  }
  # ring (live / mute)
  $ringZone = if ($showMuted.Checked) { 'ZONE_BRANDING' } else { 'ZONE_PRIMARY' }
  $rz = Get-ZoneByName $ringZone
  if ($rz) {
    $col = Get-ZoneColor $rz; $lum = [Math]::Max($col.R, [Math]::Max($col.G, $col.B))
    if ($lum -gt 0) { for ($k = 3; $k -ge 1; $k--) { $pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb([int][Math]::Min(80, (8 + $lum / 4) / $k), $col), [single]((P 7) * (1 + $k))); $g.DrawEllipse($pen, [single]($cx - $kr * 1.22), [single]($cy - $kr * 1.22), [single]($kr * 2.44), [single]($kr * 2.44)); $pen.Dispose() } }
    $pen = [Drawing.Pen]::new($col, [single](P 7)); $g.DrawEllipse($pen, [single]($cx - $kr * 1.22), [single]($cy - $kr * 1.22), [single]($kr * 2.44), [single]($kr * 2.44)); $pen.Dispose()
    $pen = [Drawing.Pen]::new($(if ($script:sel -eq $rz) { $C.Accent } else { $C.Line }), [single](P 1.2))
    $g.DrawEllipse($pen, [single]($cx - $kr * 1.32), [single]($cy - $kr * 1.32), [single]($kr * 2.64), [single]($kr * 2.64)); $pen.Dispose()
    $script:hits += , @($cx, ($cy - $kr * 1.22), (P 14), $rz)
  }
  # knob
  $kb = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.PointF]::new([single]($cx - $kr), [single]($cy - $kr)), [Drawing.PointF]::new([single]($cx + $kr), [single]($cy + $kr)), [Drawing.Color]::FromArgb(58, 59, 64), [Drawing.Color]::FromArgb(12, 12, 14))
  $g.FillEllipse($kb, [single]($cx - $kr), [single]($cy - $kr), [single](2 * $kr), [single](2 * $kr)); $kb.Dispose()
  $pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(70, 72, 78), [single](P 1)); $g.DrawEllipse($pen, [single]($cx - $kr), [single]($cy - $kr), [single](2 * $kr), [single](2 * $kr)); $pen.Dispose()

  # labels + mode / pattern rows
  $lbl = { param($t, $x, $y) $tw = [Windows.Forms.TextRenderer]::MeasureText($t, $Fonts.Label).Width; [Windows.Forms.TextRenderer]::DrawText($g, $t, $Fonts.Label, [Drawing.Point]::new([int]($x - $tw / 2), [int]$y), $C.Dim) }
  $rowY = $cy + $kr * 2.15
  & $lbl (T 'MODE') $cx ($rowY - (P 30))
  $modes = 'ZONE_LEFT_SIDE', 'ZONE_RIGHT_SIDE', 'ZONE_COMBINED'
  for ($i = 0; $i -lt 3; $i++) { & $add $modes[$i] ($cx + ($i - 1) * (P 46)) $rowY (P 9) }
  $rowY2 = $rowY + (P 74)
  & $lbl (T 'PATTERN') $cx ($rowY2 - (P 30))
  $pats = 'ZONE_ONE', 'ZONE_TWO', 'ZONE_THREE', 'ZONE_FOUR'
  for ($i = 0; $i -lt 4; $i++) { & $add $pats[$i] ($cx + ($i - 1.5) * (P 46)) $rowY2 (P 9) }
  & $lbl $(if ($showMuted.Checked) { "RING · $(T 'ZONE_BRANDING')".ToUpper() } else { "RING · $(T 'ZONE_PRIMARY')".ToUpper() }) $cx ($cy + $kr * 1.42)
  & $lbl (T 'METERING') $cx ($cy - $kr * 1.95 - (P 18))

  # other zones (if any) as a small row at the bottom
  $others = @($script:zones | Where-Object { $_.Group -eq 'OTHER' })
  for ($i = 0; $i -lt $others.Count; $i++) { & $add $others[$i].Zone ($cx + ($i - ($others.Count - 1) / 2) * (P 40)) ($rowY2 + (P 60)) (P 8) }

  $note = T 'previewNote'
  $rect = [Drawing.Rectangle]::new((P 20), $H - (P 44), $W - (P 40), (P 40))
  [Windows.Forms.TextRenderer]::DrawText($g, $note, $Fonts.Small, $rect, $C.Faint, [Windows.Forms.TextFormatFlags]'HorizontalCenter,WordBreak')
})
$prev.Add_MouseClick({
  foreach ($h in $script:hits) {
    $dx = $_.X - $h[0]; $dy = $_.Y - $h[1]
    if ($dx * $dx + $dy * $dy -le $h[2] * $h[2]) { $z = $h[3]; Select-Tab $z.Group; Select-Zone $z; break }
  }
})

# Bottom bar
$bar = New-Canvas (P 100) (P 712) (P 1060) (P 56) $form
$bar.Anchor = 'Left,Right,Bottom'
$liveBox = [Windows.Forms.CheckBox]::new()
$liveBox.Text = T 'live'; $liveBox.Checked = $true; $liveBox.AutoSize = $true; $liveBox.ForeColor = $C.Fg; $liveBox.BackColor = $C.Bg; $liveBox.Font = $Fonts.Small
$liveBox.Location = [Drawing.Point]::new(0, (P 16))
$bar.Controls.Add($liveBox)
$status = [Windows.Forms.Label]::new()
$status.AutoSize = $false; $status.Location = [Drawing.Point]::new((P 250), (P 30)); $status.Size = [Drawing.Size]::new((P 500), (P 22))
$status.ForeColor = $C.Dim; $status.BackColor = $C.Bg; $status.Font = $Fonts.Small; $status.AutoEllipsis = $true
$form.Controls.Add($status); $status.BackColor = $C.Bg
$btns = [Windows.Forms.FlowLayoutPanel]::new()
$btns.FlowDirection = 'RightToLeft'; $btns.WrapContents = $false; $btns.BackColor = $C.Bg
$btns.SetBounds((P 180), (P 6), (P 880), (P 46)); $btns.Anchor = 'Top,Left,Right'
$bar.Controls.Add($btns)
$btnSave = New-Pill (T 'save') $true $btns
$btnApply = New-Pill (T 'apply') $false $btns
$btnOff = New-Pill (T 'off') $false $btns
$btnReload = New-Pill (T 'reload') $false $btns
$btnExport = New-Pill (T 'export') $false $btns
$btnImport = New-Pill (T 'import') $false $btns
foreach ($b in $btns.Controls) { $b.Margin = [Windows.Forms.Padding]::new((P 8), 0, 0, 0) }
#endregion

#region Behaviour
$script:sel = $null
$script:updating = $false

function Set-Status([string]$text, [string]$kind = 'info') {
  $status.Text = $text
  $status.ForeColor = switch ($kind) { 'ok' { $C.Ok } 'err' { $C.Err } default { $C.Dim } }
}
function Get-TabList {
  $list = @('RING', 'MODE', 'PATTERN', 'METERING')
  if (@($script:zones | Where-Object { $_.Group -eq 'OTHER' }).Count) { $list += 'OTHER' }
  return $list
}
function Refresh-All { $list.Invalidate(); $spectrum.Invalidate(); $bright.Invalidate(); $prev.Invalidate() }

function Select-Tab([string]$t) {
  $script:tab = $t
  $script:listZones = @($script:zones | Where-Object { $_.Group -eq $t })
  $tabHint.Text = T "tabHint_$t"
  $tabs.Invalidate()
  if ($script:listZones.Count -and -not ($script:listZones -contains $script:sel)) { Select-Zone $script:listZones[0] } else { $list.Invalidate() }
}

function Sync-Editor {
  $z = $script:sel
  if (-not $z) { return }
  $script:updating = $true
  $numR.Value = $z.R; $numG.Value = $z.G; $numB.Value = $z.B
  $hexBox.Text = ConvertTo-Hex $z.R $z.G $z.B
  $effectBox.Items.Clear()
  foreach ($e in $z.Supported) { [void]$effectBox.Items.Add((T $e)) }
  $effectBox.SelectedIndex = [Math]::Max(0, [Array]::IndexOf([string[]]$z.Supported, [string]$z.Effect))
  $speedBox.Value = $z.Period
  $speedBox.Enabled = ($z.Effect -eq 'BREATHING')
  $selName.Text = "· $((T $z.Zone).ToUpper())"
  $v = [Math]::Max($z.R, [Math]::Max($z.G, $z.B))
  $brightVal.Text = "$([Math]::Round($v / 2.55, 1)) %  ($v/255)"
  $script:updating = $false
  Refresh-All
}

function Select-Zone($z) {
  $script:sel = $z
  if ($z -and $z.Group -ne $script:tab) { $script:tab = $z.Group; $script:listZones = @($script:zones | Where-Object { $_.Group -eq $z.Group }); $tabHint.Text = T "tabHint_$($z.Group)"; $tabs.Invalidate() }
  Sync-Editor
}

function Set-SelColor([int]$r, [int]$g, [int]$b, [bool]$recalcHue) {
  $z = $script:sel
  if (-not $z) { return }
  $z.R = $r; $z.G = $g; $z.B = $b
  if ($recalcHue) {
    $hsv = Get-Hsv $r $g $b
    if ($hsv[2] -gt 0 -and $hsv[1] -gt 0) { $z.H = $hsv[0] }
    if ($hsv[2] -gt 0) { $z.S = $hsv[1] }
  }
  Sync-Editor
  Request-LiveApply
}

$debounce = [Windows.Forms.Timer]::new()
$debounce.Interval = 220
$debounce.Add_Tick({
  $debounce.Stop()
  try { Set-YetiLighting (Get-ZoneEffects) $false; Set-Status (T 'applied') 'ok' } catch { Set-Status $_.Exception.Message 'err' }
})
function Request-LiveApply {
  if ($script:updating -or -not $liveBox.Checked) { return }
  $debounce.Stop(); $debounce.Start()
}

foreach ($n in $numR, $numG, $numB) {
  $n.Add_ValueChanged({ if (-not $script:updating) { Set-SelColor ([int]$numR.Value) ([int]$numG.Value) ([int]$numB.Value) $true } })
}
$hexBox.Add_TextChanged({
  if ($script:updating) { return }
  $v = ConvertFrom-Hex $hexBox.Text
  if ($v) { $pos = $hexBox.SelectionStart; Set-SelColor $v[0] $v[1] $v[2] $true; $hexBox.SelectionStart = [Math]::Min($pos, $hexBox.Text.Length) }
})
$effectBox.Add_SelectedIndexChanged({
  if ($script:updating -or -not $script:sel -or $effectBox.SelectedIndex -lt 0) { return }
  $script:sel.Effect = $script:sel.Supported[$effectBox.SelectedIndex]
  Sync-Editor; Request-LiveApply
})
$speedBox.Add_ValueChanged({
  if ($script:updating -or -not $script:sel) { return }
  $script:sel.Period = [int]$speedBox.Value; Request-LiveApply
})

$identifyTimer = [Windows.Forms.Timer]::new()
$identifyTimer.Interval = 2000
$identifyTimer.Add_Tick({
  $identifyTimer.Stop()
  try { Set-YetiLighting (Get-ZoneEffects) $false; Set-Status (T 'identifyDone') 'ok' } catch { Set-Status $_.Exception.Message 'err' }
})
$identifyBtn.Add_Click({
  if (-not $script:sel) { return }
  try {
    $zn = $script:sel.Zone
    $fx = @(Get-ZoneEffects | ForEach-Object { if ($_.zone -eq $zn) { $_.effect = 'FIXED'; $_.hex = '#ffffff' }; $_ })
    Set-YetiLighting $fx $false
    Set-Status ((T 'identifyRun') -f (T $zn)) 'info'
    $identifyTimer.Start()
  } catch { Set-Status $_.Exception.Message 'err' }
})

function Import-State {
  try {
    Set-Status (T 'connecting'); $form.Refresh()
    Get-YetiState
    $script:connected = $true
    $keep = if ($script:sel) { $script:sel.Zone } else { $null }
    $script:sel = $null
    $tabsNow = Get-TabList
    if ($tabsNow -notcontains $script:tab) { $script:tab = 'RING' }
    Select-Tab $script:tab
    if ($keep) { $z = Get-ZoneByName $keep; if ($z) { Select-Zone $z } }
    Set-Status ((T 'loaded') -f $script:dev.displayName) 'ok'
  } catch { $script:connected = $false; Set-Status $_.Exception.Message 'err' }
  $top.Invalidate()
}

function Set-Language([string]$code) {
  $script:lang = $code
  try { if (-not (Test-Path -LiteralPath $AppDir)) { [void](New-Item -ItemType Directory -Path $AppDir) }; (@{ lang = $code } | ConvertTo-Json) | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch { }
  $form.Text = T 'appName'; $subtitle.Text = T 'subtitle'; $cardTitle.Text = T 'lighting'
  $lblColor.Text = T 'color'; $lblBright.Text = T 'brightness'; $lblCustom.Text = T 'custom'; $lblEffect.Text = T 'effect'; $lblSpeed.Text = T 'speed'
  $liveBox.Text = T 'live'; $showMuted.Text = T 'showMuted'
  Set-PillText $identifyBtn (T 'identify')
  Set-PillText $btnSave (T 'save'); Set-PillText $btnApply (T 'apply'); Set-PillText $btnOff (T 'off')
  Set-PillText $btnReload (T 'reload'); Set-PillText $btnExport (T 'export'); Set-PillText $btnImport (T 'import')
  $tabHint.Text = T "tabHint_$($script:tab)"
  Update-LangLabels
  Sync-Editor
  $tabs.Invalidate(); $top.Invalidate(); Refresh-All
}

$btnReload.Add_Click({ Import-State })
$btnApply.Add_Click({ try { Set-YetiLighting (Get-ZoneEffects) $false; Set-Status (T 'applied') 'ok' } catch { Set-Status $_.Exception.Message 'err' } })
$btnSave.Add_Click({ try { Set-YetiLighting (Get-ZoneEffects) $true; Set-Status (T 'saved') 'ok' } catch { Set-Status $_.Exception.Message 'err' } })
$btnOff.Add_Click({
  foreach ($z in $script:zones) { $z.R = 0; $z.G = 0; $z.B = 0 }
  Sync-Editor; Request-LiveApply
  Set-Status (T 'allOff') 'ok'
})
$btnExport.Add_Click({
  $dlg = [Windows.Forms.SaveFileDialog]::new(); $dlg.Filter = 'Yeti X preset (*.json)|*.json'; $dlg.FileName = 'yetix-preset.json'
  if ($dlg.ShowDialog($form) -eq 'OK') {
    @(Get-ZoneEffects) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $dlg.FileName -Encoding UTF8
    Set-Status ((T 'presetSaved') -f $dlg.FileName) 'ok'
  }
})
$btnImport.Add_Click({
  $dlg = [Windows.Forms.OpenFileDialog]::new(); $dlg.Filter = 'Yeti X preset (*.json)|*.json'
  if ($dlg.ShowDialog($form) -ne 'OK') { return }
  try {
    $preset = Get-Content -LiteralPath $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $preset) {
      $z = Get-ZoneByName $p.zone
      if (-not $z) { continue }
      $v = ConvertFrom-Hex $p.hex
      if ($v) { $z.R = $v[0]; $z.G = $v[1]; $z.B = $v[2]; $hsv = Get-Hsv $v[0] $v[1] $v[2]; if ($hsv[2] -gt 0) { $z.H = $hsv[0]; $z.S = $hsv[1] } }
      if ($z.Supported -contains $p.effect) { $z.Effect = $p.effect }
      if ($p.period) { $z.Period = [Math]::Min(20000, [Math]::Max(500, [int]$p.period)) }
    }
    Sync-Editor; Request-LiveApply
    Set-Status ((T 'presetLoaded') -f $dlg.FileName) 'ok'
  } catch { Set-Status $_.Exception.Message 'err' }
})

$form.Add_Load({
  try { $dark = 1; [void][YxNative]::DwmSetWindowAttribute($form.Handle, 20, [ref]$dark, 4) } catch { }
})
$form.Add_Shown({ Set-Language $script:lang; Import-State })
$form.Add_FormClosed({ if ($script:ws) { try { $script:ws.Dispose() } catch { } } })
[void]$form.ShowDialog()
#endregion
