# Builds the images used by README.md: a light and dark logo lockup, and a
# showcase band of three phone screens.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = "D:\SAM LABS\Android App Projects\Timbre"
$out = Join-Path $root 'docs\images'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSerif-Regular.ttf'))
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSans.ttf'))
$serif = $fonts.Families | Where-Object { $_.Name -like '*Serif*' } | Select-Object -First 1
$sans = $fonts.Families | Where-Object { $_.Name -like '*Sans*' } | Select-Object -First 1
if (-not $serif -or -not $sans) { throw "Fonts did not load" }

$ember = [System.Drawing.ColorTranslator]::FromHtml('#E0562D')
$emberLight = [System.Drawing.ColorTranslator]::FromHtml('#F09B78')
$ink = [System.Drawing.ColorTranslator]::FromHtml('#0A0B0D')
$paper = [System.Drawing.ColorTranslator]::FromHtml('#F6F3EC')

function New-BarPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

# ---------------------------------------------------------------- logo lockup

function New-Lockup([string]$file, $textColor) {
  $barW = 26.0
  $gap = 14.0
  $markH = 180.0
  $markW = 5 * $barW + 4 * $gap
  $wordSize = 178
  $wordFont = New-Object System.Drawing.Font($serif, $wordSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $typo = [System.Drawing.StringFormat]::GenericTypographic

  $probe = New-Object System.Drawing.Bitmap 10, 10
  $pg = [System.Drawing.Graphics]::FromImage($probe)
  $measure = $pg.MeasureString('Timbre', $wordFont, 2000, $typo)
  $pg.Dispose()
  $probe.Dispose()
  $wordW = $measure.Width
  $wordH = $measure.Height

  $left = 40.0
  $mid = 46.0
  $right = 50.0
  $width = [int][math]::Ceiling($left + $markW + $mid + $wordW + $right)
  $height = [int]($markH + 100)

  $bmp = New-Object System.Drawing.Bitmap $width, $height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)

  $baseY = ($height + $markH) / 2.0
  $ratios = @(0.46, 0.72, 1.0, 0.62, 0.36)
  $rect = New-Object System.Drawing.RectangleF $left, ($baseY - $markH), $markW, $markH
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $emberLight, $ember, 90)
  for ($i = 0; $i -lt 5; $i++) {
    $bh = $markH * $ratios[$i]
    $bx = $left + $i * ($barW + $gap)
    $path = New-BarPath $bx ($baseY - $bh) $barW $bh ($barW / 2)
    $g.FillPath($brush, $path)
    $path.Dispose()
  }

  $textBrush = New-Object System.Drawing.SolidBrush $textColor
  $textX = $left + $markW + $mid
  $textY = ($baseY - $markH / 2) - $wordH / 2
  $g.DrawString('Timbre', $wordFont, $textBrush, $textX, $textY, $typo)

  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $textBrush.Dispose()
  $brush.Dispose()
  $wordFont.Dispose()
  $g.Dispose()
  $bmp.Dispose()
  Write-Output "wrote $file ($width x $height)"
}

New-Lockup (Join-Path $out 'logo-light.png') $ink
New-Lockup (Join-Path $out 'logo-dark.png') $paper

# ---------------------------------------------------------------- showcase

$shots = @(
  (Join-Path $root 'shots\store_src\01_home.png'),
  (Join-Path $root 'shots\store_src\02_player_sleeve.png'),
  (Join-Path $root 'shots\store_src\05_you.png')
)
foreach ($shot in $shots) {
  if (-not (Test-Path $shot)) { throw "Missing capture $shot" }
}

$canvasW = 1800
$canvasH = 1080
$bottomCrop = 220
$phoneH = 860
$gapPx = 54.0

$first = [System.Drawing.Image]::FromFile($shots[0])
try {
  $phoneW = [int][math]::Round($phoneH * $first.Width / ($first.Height - $bottomCrop))
} finally {
  $first.Dispose()
}
$totalW = 3 * $phoneW + 2 * $gapPx
$startX = [int](($canvasW - $totalW) / 2)
$topY = [int](($canvasH - $phoneH) / 2)

$bmp = New-Object System.Drawing.Bitmap $canvasW, $canvasH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$rect = New-Object System.Drawing.Rectangle 0, 0, $canvasW, $canvasH
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $rect,
  [System.Drawing.ColorTranslator]::FromHtml('#151114'),
  [System.Drawing.ColorTranslator]::FromHtml('#06070A'),
  90.0
)
$g.FillRectangle($bg, $rect)
$glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 224, 86, 45))
$g.FillEllipse($glow, 520, -260, 1000, 900)
$ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(26, 224, 86, 45)), 2
$g.DrawEllipse($ring, 600, -180, 840, 840)

for ($i = 0; $i -lt 3; $i++) {
  $shot = [System.Drawing.Image]::FromFile($shots[$i])
  try {
    $x = $startX + $i * ($phoneW + $gapPx)
    $radius = 34.0

    for ($layer = 3; $layer -ge 1; $layer--) {
      $a = 10 + (3 - $layer) * 9
      $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, 0, 0, 0))
      $shadowPath = New-RoundedPath $x ($topY + $layer * 12) $phoneW $phoneH $radius
      $g.FillPath($shadow, $shadowPath)
      $shadowPath.Dispose()
      $shadow.Dispose()
    }

    $clip = New-RoundedPath $x $topY $phoneW $phoneH $radius
    $g.SetClip($clip)
    $dest = New-Object System.Drawing.Rectangle $x, $topY, $phoneW, $phoneH
    $src = New-Object System.Drawing.Rectangle 0, 0, $shot.Width, ($shot.Height - $bottomCrop)
    $g.DrawImage($shot, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $g.ResetClip()

    $border = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(42, 246, 243, 236)), 1.4
    $g.DrawPath($border, $clip)
    $border.Dispose()
    $clip.Dispose()
  } finally {
    $shot.Dispose()
  }
}

$showcase = Join-Path $out 'showcase.png'
$bmp.Save($showcase, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output "wrote $showcase ($canvasW x $canvasH)"

$bg.Dispose()
$glow.Dispose()
$ring.Dispose()
$fonts.Dispose()
