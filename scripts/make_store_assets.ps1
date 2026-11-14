# Builds the 1024x500 Play Store feature graphic from the Timbre brand mark.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = "D:\SAM LABS\Android App Projects\Timbre"
$out = Join-Path $root 'store'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSerif-Regular.ttf'))
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSans.ttf'))
$serif = $fonts.Families | Where-Object { $_.Name -like '*Serif*' } | Select-Object -First 1
$sans = $fonts.Families | Where-Object { $_.Name -like '*Sans*' } | Select-Object -First 1
if (-not $serif -or -not $sans) { throw "Fonts did not load: $($fonts.Families.Name -join ', ')" }

$w = 1024
$h = 500
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$ink = [System.Drawing.ColorTranslator]::FromHtml('#0A0B0D')
$ember = [System.Drawing.ColorTranslator]::FromHtml('#E0562D')
$paper = [System.Drawing.ColorTranslator]::FromHtml('#F6F3EC')
$dim = [System.Drawing.ColorTranslator]::FromHtml('#9A958C')

$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.Rectangle 0, 0, $w, $h),
  [System.Drawing.ColorTranslator]::FromHtml('#141013'),
  $ink,
  15.0
)
$g.FillRectangle($bg, 0, 0, $w, $h)

# Large soft ember disc, clipped by the canvas edge.
$disc = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(26, 224, 86, 45))
$g.FillEllipse($disc, 720, -140, 620, 620)
$ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 224, 86, 45)), 2
$g.DrawEllipse($ring, 780, -80, 500, 500)

function New-BarPath([single]$x, [single]$y, [single]$bw, [single]$bh, [single]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $bw - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $bw - $d, $y + $bh - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $bh - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

# Mark: five rounded bars, 170 px tall block.
$markX = 76.0
$baseY = 330.0
$markH = 150.0
$barW = 22.0
$gap = 12.0
$ratios = @(0.46, 0.72, 1.0, 0.62, 0.36)
$gradRect = New-Object System.Drawing.RectangleF $markX, ($baseY - $markH), 175, $markH
$barBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $gradRect,
  [System.Drawing.ColorTranslator]::FromHtml('#F09B78'),
  $ember,
  60
)
for ($i = 0; $i -lt 5; $i++) {
  $bh = $markH * $ratios[$i]
  $x = $markX + $i * ($barW + $gap)
  $path = New-BarPath $x ($baseY - $bh) $barW $bh ($barW / 2)
  $g.FillPath($barBrush, $path)
  $path.Dispose()
}

$serifBrush = New-Object System.Drawing.SolidBrush $paper
$sansBrush = New-Object System.Drawing.SolidBrush $dim
$accentBrush = New-Object System.Drawing.SolidBrush $ember

$titleFont = New-Object System.Drawing.Font($serif, 96, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$tagFont = New-Object System.Drawing.Font($sans, 28, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$smallFont = New-Object System.Drawing.Font($sans, 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

$g.DrawString('Timbre', $titleFont, $serifBrush, 300, 140)
$g.DrawString('Your music, in its own order.', $tagFont, $sansBrush, 306, 262)

# Small overline with an accent rule.
$g.FillRectangle($accentBrush, 308, 330, 30, 2)
$g.DrawString('NO ACCOUNT   NO ADS   NO UPLOADS', $smallFont, $accentBrush, 350, 319)

$bmp.Save((Join-Path $out 'feature_graphic.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$titleFont.Dispose()
$tagFont.Dispose()
$smallFont.Dispose()
$serifBrush.Dispose()
$sansBrush.Dispose()
$accentBrush.Dispose()
$barBrush.Dispose()
$bg.Dispose()
$disc.Dispose()
$ring.Dispose()
$g.Dispose()
$bmp.Dispose()
$fonts.Dispose()
Write-Output "wrote $out\feature_graphic.png"
