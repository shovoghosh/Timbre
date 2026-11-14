# Generates the Timbre app icon, adaptive foreground, monochrome icon and
# splash mark with .NET drawing. All shapes are original: five rounded bars in a
# warm gradient, the same mark used inside the app.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$out = "D:\SAM LABS\Android App Projects\Timbre\assets\brand"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$ink = [System.Drawing.ColorTranslator]::FromHtml('#0A0B0D')

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

function New-Mark([string]$file, [int]$canvas, [int]$markWidth, [int]$markHeight, [bool]$background, [bool]$monochrome) {
  $bmp = New-Object System.Drawing.Bitmap $canvas, $canvas
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  if ($background) {
    $g.Clear($ink)
  } else {
    $g.Clear([System.Drawing.Color]::Transparent)
  }

  $top = [System.Drawing.ColorTranslator]::FromHtml('#E0562D')
  $bottom = [System.Drawing.ColorTranslator]::FromHtml('#F09B78')
  if ($monochrome) {
    $top = [System.Drawing.Color]::White
    $bottom = [System.Drawing.Color]::White
  }

  $left = ($canvas - $markWidth) / 2.0
  $bottomY = ($canvas + $markHeight) / 2.0
  $rect = New-Object System.Drawing.RectangleF $left, ($bottomY - $markHeight), $markWidth, $markHeight
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $top, $bottom, 90

  $barWidth = $markWidth * 0.13
  $gap = ($markWidth - ($barWidth * 5)) / 4.0
  $ratios = @(0.46, 0.72, 1.0, 0.62, 0.36)
  $radius = $barWidth / 2.0

  for ($i = 0; $i -lt 5; $i++) {
    $h = $markHeight * $ratios[$i]
    $x = $left + $i * ($barWidth + $gap)
    $y = $bottomY - $h
    $path = New-BarPath $x $y $barWidth $h $radius
    $g.FillPath($brush, $path)
    $path.Dispose()
  }

  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $brush.Dispose()
  $g.Dispose()
  $bmp.Dispose()
  Write-Output "wrote $file"
}

# Store icon: full bleed ink with a confident mark.
New-Mark (Join-Path $out 'icon.png') 1024 470 470 $true $false

# Adaptive icon foreground: transparent, well inside the 66% safe zone.
New-Mark (Join-Path $out 'icon_foreground.png') 1024 400 400 $false $false

# Android 13 themed icon.
New-Mark (Join-Path $out 'icon_monochrome.png') 1024 400 400 $false $true

# Splash mark on transparent, sized for the native splash.
New-Mark (Join-Path $out 'splash_mark.png') 512 250 250 $false $false

# Play Store listing icon.
New-Mark (Join-Path $out 'play_store_icon.png') 512 240 240 $true $false
