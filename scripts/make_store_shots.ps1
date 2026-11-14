# Frames captured phone screens into 1080x1920 store screenshots.
#
# Capture first, on the phone, with the status bar hidden:
#   adb shell settings put global policy_control immersive.status=*
#   adb exec-out screencap -p > shots\store_src\01_home.png
#   adb shell settings put global policy_control null
#
# Then run this script. It reads every PNG in shots\store_src and writes a
# framed copy to store\shots, cropping the system navigation bar.
param(
  # Height of the Android navigation bar at the bottom of the capture. The
  # Samsung used for these shots reserves 220 px at 1440x3120.
  [int]$BottomCrop = 220
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = "D:\SAM LABS\Android App Projects\Timbre"
$source = Join-Path $root 'shots\store_src'
$out = Join-Path $root 'store\shots'
New-Item -ItemType Directory -Force -Path $out | Out-Null

if (-not (Test-Path $source)) {
  throw "No captures in $source"
}

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSerif-Regular.ttf'))
$fonts.AddFontFile((Join-Path $root 'assets\fonts\InstrumentSans.ttf'))
$serif = $fonts.Families | Where-Object { $_.Name -like '*Serif*' } | Select-Object -First 1
$sans = $fonts.Families | Where-Object { $_.Name -like '*Sans*' } | Select-Object -First 1
if (-not $serif -or -not $sans) { throw "Fonts did not load: $($fonts.Families.Name -join ', ')" }

$ink = [System.Drawing.ColorTranslator]::FromHtml('#0A0B0D')
$paper = [System.Drawing.ColorTranslator]::FromHtml('#F6F3EC')
$dim = [System.Drawing.ColorTranslator]::FromHtml('#9A958C')
$ember = [System.Drawing.ColorTranslator]::FromHtml('#E0562D')

# Caption for each capture, keyed by file name without extension.
$captions = @{
  '01_home'           = @{ kicker = 'HOME';        title = 'Pick up where you left off'; sub = 'Your week, your mixes, one tap away.' }
  '02_player_sleeve'  = @{ kicker = 'NOW PLAYING'; title = 'Every cover gets a sleeve';   sub = 'Art, title, and nothing in the way.' }
  '03_player_vinyl'   = @{ kicker = 'NOW PLAYING'; title = 'Or put it on the turntable';  sub = 'A disc, a tonearm, and your songs.' }
  '04_search'         = @{ kicker = 'SEARCH';      title = 'Find it as you type';         sub = 'Songs, albums, and artists, fast.' }
  '05_you'            = @{ kicker = 'YOU';         title = 'Your lists, kept tidy';       sub = 'Playlists, favourites, and on repeat.' }
  '06_equalizer'      = @{ kicker = 'SOUND';       title = 'Tune it to your ears';        sub = 'Real bands, presets, and bass boost.' }
}

$width = 1080
$height = 1920
$phoneTop = 404
$phoneBottom = 1850
$phoneHeight = $phoneBottom - $phoneTop

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

# GDI+ has no letter spacing, so draw one character at a time.
function Draw-Tracked($g, [string]$text, $font, $brush, [single]$x, [single]$y, [single]$tracking) {
  $typo = [System.Drawing.StringFormat]::GenericTypographic
  $cursor = $x
  foreach ($ch in $text.ToCharArray()) {
    $g.DrawString([string]$ch, $font, $brush, $cursor, $y, $typo)
    $cursor += $g.MeasureString([string]$ch, $font, 1000, $typo).Width + $tracking
  }
}

$written = @()
Get-ChildItem $source -Filter '*.png' | Sort-Object Name | ForEach-Object {
  $key = $_.BaseName
  if (-not $captions.ContainsKey($key)) {
    Write-Warning "no caption for $($_.Name), skipped"
    return
  }
  $caption = $captions[$key]

  $shot = [System.Drawing.Image]::FromFile($_.FullName)
  try {
    $cropH = $shot.Height - $bottomCrop
    $scale = $phoneHeight / $cropH
    $phoneWidth = [int][math]::Round($shot.Width * $scale)
    $phoneX = [int](($width - $phoneWidth) / 2)

    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # Deep paper dark background with a soft ember glow behind the phone.
    $bgRect = New-Object System.Drawing.Rectangle 0, 0, $width, $height
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $bgRect,
      [System.Drawing.ColorTranslator]::FromHtml('#141013'),
      [System.Drawing.ColorTranslator]::FromHtml('#07080A'),
      90.0
    )
    $g.FillRectangle($bg, $bgRect)

    $glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(20, 224, 86, 45))
    $g.FillEllipse($glow, 560, -320, 900, 900)
    $ringPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(30, 224, 86, 45)), 2
    $g.DrawEllipse($ringPen, 640, -240, 760, 760)

    # Brand mark: five rounded bars.
    $barW = 8.0
    $gap = 6.0
    $markH = 40.0
    $ratios = @(0.46, 0.72, 1.0, 0.62, 0.36)
    $markBase = 134.0
    $markX = 72.0
    $markRect = New-Object System.Drawing.RectangleF $markX, ($markBase - $markH), 80, $markH
    $markBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $markRect,
      [System.Drawing.ColorTranslator]::FromHtml('#F09B78'),
      $ember,
      90
    )
    for ($i = 0; $i -lt 5; $i++) {
      $bh = $markH * $ratios[$i]
      $bx = $markX + $i * ($barW + $gap)
      $path = New-RoundedPath $bx ($markBase - $bh) $barW $bh ($barW / 2)
      $g.FillPath($markBrush, $path)
      $path.Dispose()
    }

    $wordFont = New-Object System.Drawing.Font($sans, 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $wordBrush = New-Object System.Drawing.SolidBrush ($dim)
    Draw-Tracked $g 'TIMBRE' $wordFont $wordBrush 152 106 3.6

    $kickerFont = New-Object System.Drawing.Font($sans, 17, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $kickerBrush = New-Object System.Drawing.SolidBrush $ember
    $g.FillRectangle($kickerBrush, 72, 190, 26, 2)
    Draw-Tracked $g $caption.kicker $kickerFont $kickerBrush 112 176 2.6

    $titleSize = 56
    $titleFont = New-Object System.Drawing.Font($serif, $titleSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $typo = [System.Drawing.StringFormat]::GenericTypographic
    $titleWidth = $g.MeasureString($caption.title, $titleFont, 1000, $typo).Width
    if ($titleWidth -gt 940) {
      $titleSize = 46
      $titleFont.Dispose()
      $titleFont = New-Object System.Drawing.Font($serif, $titleSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $titleBrush = New-Object System.Drawing.SolidBrush $paper
    $g.DrawString($caption.title, $titleFont, $titleBrush, 70, 212, $typo)

    $subFont = New-Object System.Drawing.Font($sans, 23, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $subBrush = New-Object System.Drawing.SolidBrush $dim
    $g.DrawString($caption.sub, $subFont, $subBrush, 72, 318, $typo)

    # Phone: soft shadow, rounded clip, hairline border.
    $radius = 34.0
    for ($layer = 3; $layer -ge 1; $layer--) {
      $a = 8 + (3 - $layer) * 8
      $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, 0, 0, 0))
      $shadowPath = New-RoundedPath $phoneX ($phoneTop + $layer * 10) $phoneWidth $phoneHeight $radius
      $g.FillPath($shadow, $shadowPath)
      $shadowPath.Dispose()
      $shadow.Dispose()
    }

    $clip = New-RoundedPath $phoneX $phoneTop $phoneWidth $phoneHeight $radius
    $g.SetClip($clip)
    $destRect = New-Object System.Drawing.Rectangle $phoneX, $phoneTop, $phoneWidth, $phoneHeight
    $srcRect = New-Object System.Drawing.Rectangle 0, 0, $shot.Width, $cropH
    $g.DrawImage($shot, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.ResetClip()

    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(38, 246, 243, 236)), 1.4
    $g.DrawPath($borderPen, $clip)

    $target = Join-Path $out "$key.png"
    $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $written += $target

    $borderPen.Dispose()
    $clip.Dispose()
    $subFont.Dispose()
    $subBrush.Dispose()
    $titleFont.Dispose()
    $titleBrush.Dispose()
    $kickerFont.Dispose()
    $kickerBrush.Dispose()
    $wordFont.Dispose()
    $wordBrush.Dispose()
    $markBrush.Dispose()
    $ringPen.Dispose()
    $glow.Dispose()
    $bg.Dispose()
    $g.Dispose()
    $bmp.Dispose()
  } finally {
    $shot.Dispose()
  }
}

foreach ($file in $written) {
  $img = [System.Drawing.Image]::FromFile($file)
  Write-Output ("wrote {0} ({1}x{2})" -f $file, $img.Width, $img.Height)
  $img.Dispose()
}
$fonts.Dispose()
