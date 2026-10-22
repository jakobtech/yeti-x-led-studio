# Generates the app logo (logo.png + multi-size logo.ico): a segmented LED level ring around a mic capsule.
param([string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'app'))
Add-Type -AssemblyName System.Drawing

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); return $p
}

function Mix([Drawing.Color]$a, [Drawing.Color]$b, [double]$t) {
  [Drawing.Color]::FromArgb([int]($a.R + ($b.R - $a.R) * $t), [int]($a.G + ($b.G - $a.G) * $t), [int]($a.B + ($b.B - $a.B) * $t))
}

function New-Logo([int]$N) {
  $bmp = [Drawing.Bitmap]::new($N, $N, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([Drawing.Color]::Transparent)

  # Background tile
  $tile = New-RoundRect 0 0 ($N - 1) ($N - 1) ($N * 0.23)
  $bgBrush = [Drawing.Drawing2D.LinearGradientBrush]::new(([Drawing.PointF]::new(0, 0)), ([Drawing.PointF]::new($N, $N)), [Drawing.Color]::FromArgb(30, 33, 42), [Drawing.Color]::FromArgb(6, 7, 10))
  $g.FillPath($bgBrush, $tile)
  if ($N -ge 48) { $g.DrawPath(([Drawing.Pen]::new([Drawing.Color]::FromArgb(60, 255, 255, 255), [Math]::Max(1, $N / 128))), $tile) }

  # Segmented LED ring (level meter): cyan -> violet -> magenta, last segments unlit
  $c = $N / 2; $R = $N * 0.335; $w = [Math]::Max(1.6, $N * 0.085)
  $cyan = [Drawing.Color]::FromArgb(0, 212, 255); $violet = [Drawing.Color]::FromArgb(124, 92, 255); $pink = [Drawing.Color]::FromArgb(255, 61, 139)
  $segs = if ($N -ge 32) { 12 } else { 8 }
  $sweep = 300.0; $start = 120.0; $gap = if ($N -ge 32) { 7.0 } else { 10.0 }
  $lit = $segs - [Math]::Max(2, [int]($segs / 4))
  for ($i = 0; $i -lt $segs; $i++) {
    $t = $i / ($segs - 1)
    $col = if ($t -lt 0.5) { Mix $cyan $violet ($t * 2) } else { Mix $violet $pink (($t - 0.5) * 2) }
    if ($i -ge $lit) { $col = [Drawing.Color]::FromArgb(48, 52, 64) }
    $a0 = $start + $i * ($sweep / $segs) + $gap / 2
    $pen = [Drawing.Pen]::new($col, $w); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    if ($i -lt $lit -and $N -ge 48) {
      $glow = [Drawing.Pen]::new([Drawing.Color]::FromArgb(34, $col), $w * 1.8); $glow.StartCap = 'Round'; $glow.EndCap = 'Round'
      $g.DrawArc($glow, $c - $R, $c - $R, 2 * $R, 2 * $R, $a0, ($sweep / $segs) - $gap)
    }
    $g.DrawArc($pen, $c - $R, $c - $R, 2 * $R, 2 * $R, $a0, ($sweep / $segs) - $gap)
  }

  # Mic capsule
  $cw = $N * 0.17; $ch = $N * 0.27; $cx = $c - $cw / 2; $cy = $c - $ch * 0.62
  $cap = New-RoundRect $cx $cy $cw $ch ($cw / 2)
  $capBrush = [Drawing.Drawing2D.LinearGradientBrush]::new(([Drawing.PointF]::new($cx, $cy)), ([Drawing.PointF]::new(($cx + $cw), ($cy + $ch))), [Drawing.Color]::FromArgb(250, 252, 255), [Drawing.Color]::FromArgb(160, 170, 188))
  $g.FillPath($capBrush, $cap)
  if ($N -ge 48) {
    $grille = [Drawing.Pen]::new([Drawing.Color]::FromArgb(110, 20, 24, 32), [Math]::Max(1, $N / 110))
    for ($k = 1; $k -le 3; $k++) { $yy = $cy + $ch * (0.22 + 0.16 * $k); $g.DrawLine($grille, $cx + $cw * 0.22, $yy, $cx + $cw * 0.78, $yy) }
  }
  # Holder arc and stem
  $hp = [Drawing.Pen]::new([Drawing.Color]::FromArgb(205, 212, 225), [Math]::Max(1.2, $N * 0.032)); $hp.StartCap = 'Round'; $hp.EndCap = 'Round'
  $hw = $cw * 1.75; $g.DrawArc($hp, $c - $hw / 2, $cy + $ch * 0.30, $hw, $ch * 0.78, 20, 140)
  $stemTop = $cy + $ch * 0.30 + $ch * 0.78
  $g.DrawLine($hp, $c, $stemTop, $c, $stemTop + $N * 0.06)
  $g.DrawLine($hp, $c - $N * 0.06, $stemTop + $N * 0.06, $c + $N * 0.06, $stemTop + $N * 0.06)

  $g.Dispose()
  return $bmp
}

# 32-bit DIB icon entry (what Windows/WinForms expect for the small sizes)
function ConvertTo-IconDib([Drawing.Bitmap]$bmp) {
  $n = $bmp.Width
  $ms = New-Object IO.MemoryStream
  $w = New-Object IO.BinaryWriter($ms)
  $w.Write([UInt32]40); $w.Write([Int32]$n); $w.Write([Int32]($n * 2)); $w.Write([UInt16]1); $w.Write([UInt16]32)
  $w.Write([UInt32]0); $w.Write([UInt32]0); $w.Write([Int32]0); $w.Write([Int32]0); $w.Write([UInt32]0); $w.Write([UInt32]0)
  for ($y = $n - 1; $y -ge 0; $y--) {
    for ($x = 0; $x -lt $n; $x++) { $c = $bmp.GetPixel($x, $y); $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A) }
  }
  $maskRow = [int]([Math]::Ceiling($n / 32.0) * 4)
  $w.Write((New-Object byte[] ($maskRow * $n)))
  $w.Flush()
  return , $ms.ToArray()
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$pngs = foreach ($s in $sizes) {
  $b = New-Logo $s
  if ($s -eq 256) {
    $ms = New-Object IO.MemoryStream
    $b.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $b.Save((Join-Path $OutDir 'logo.png'), [Drawing.Imaging.ImageFormat]::Png)
    $data = $ms.ToArray()
  } else {
    $data = ConvertTo-IconDib $b
  }
  $b.Dispose()
  , $data
}

# ICO container: DIB entries for small sizes, PNG for 256
$fs = [IO.File]::Create((Join-Path $OutDir 'logo.ico'))
$bw = New-Object IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $len = $pngs[$i].Length
  $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s }))); $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
  $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([UInt16]1); $bw.Write([UInt16]32)
  $bw.Write([UInt32]$len); $bw.Write([UInt32]$offset)
  $offset += $len
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close()
"logo.png + logo.ico written to $OutDir"
