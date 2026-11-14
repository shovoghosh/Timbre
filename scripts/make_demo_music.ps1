# Generates an original demo music library for testing Timbre on an emulator.
# All audio is synthesized sine material, and all names are invented.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$out = "D:\SAM LABS\Android App Projects\Timbre\.demo-audio"
$coverDir = Join-Path $out "covers"

New-Item -ItemType Directory -Force -Path $out | Out-Null
New-Item -ItemType Directory -Force -Path $coverDir | Out-Null

function New-Cover($name, $topHex, $bottomHex, $title, $subtitle) {
  $path = Join-Path $coverDir "$name.png"
  $size = 700
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
  $c0 = [System.Drawing.ColorTranslator]::FromHtml("#$topHex")
  $c1 = [System.Drawing.ColorTranslator]::FromHtml("#$bottomHex")
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c0, $c1, 45
  $g.FillRectangle($brush, $rect)

  $titleFont = New-Object System.Drawing.Font "Georgia", 52, ([System.Drawing.FontStyle]::Bold)
  $subFont = New-Object System.Drawing.Font "Arial", 22, ([System.Drawing.FontStyle]::Regular)
  $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
  $dim = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(160, 255, 255, 255))
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center

  $titleRect = New-Object System.Drawing.RectangleF 60, 250, 580, 160
  $subRect = New-Object System.Drawing.RectangleF 60, 410, 580, 60
  $g.DrawString($title, $titleFont, $white, $titleRect, $format)
  $g.DrawString($subtitle.ToUpper(), $subFont, $dim, $subRect, $format)

  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  return $path
}

function New-Track {
  param($name, $title, $artist, $album, $genre, $track, $seconds, $freq, $cover, $lyrics, $codec)
  $args = @('-y','-loglevel','error')
  $args += @('-f','lavfi','-i',"sine=frequency=${freq}:duration=${seconds}:sample_rate=44100")
  if ($cover -and $codec -ne 'wav') {
    $args += @('-i', $cover)
  }
  $fade = 'afade=t=in:st=0:d=1,afade=t=out:st=' + ($seconds - 2) + ':d=2,volume=0.35'
  $args += @('-af', $fade)
  switch ($codec) {
    'wav' {
      $args += @('-ac','1','-ar','44100','-c:a','pcm_s16le')
    }
    'flac' {
      $args += @('-ac','1','-ar','44100','-c:a','flac','-compression_level','8')
      if ($cover) { $args += @('-c:v','copy','-disposition:v','attached_pic') }
    }
    'm4a' {
      $args += @('-ac','1','-ar','44100','-c:a','aac','-b:a','128k')
      if ($cover) { $args += @('-c:v','mjpeg','-disposition:v','attached_pic') }
    }
    'ogg' {
      $args += @('-ac','1','-ar','44100','-c:a','libvorbis','-q:a','4')
      if ($cover) { $args += @('-c:v','copy','-disposition:v','attached_pic') }
    }
    default {
      $args += @('-ac','1','-ar','44100','-c:a','libmp3lame','-b:a','128k','-id3v2_version','3')
      if ($cover) { $args += @('-c:v','mjpeg','-metadata:s:v','title=Album cover','-metadata:s:v','comment=Cover (front)') }
    }
  }
  $args += @(
    '-metadata', "title=$title",
    '-metadata', "artist=$artist",
    '-metadata', "album=$album",
    '-metadata', "album_artist=$artist",
    '-metadata', "genre=$genre",
    '-metadata', "date=2026",
    '-metadata', "track=$track",
    '-metadata', "disc=1"
  )
  if ($lyrics) { $args += @('-metadata', "lyrics=$lyrics") }
  $args += (Join-Path $out $name)
  & ffmpeg @args
  if (Test-Path (Join-Path $out $name)) {
    $size = [math]::Round((Get-Item (Join-Path $out $name)).Length / 1MB, 2)
    Write-Output "made $name ($size MB)"
  } else {
    Write-Output "FAILED $name"
  }
}

$cover1 = New-Cover 'neon' '1E2A33' '4F8486' 'Neon Lit Rooms' 'Mara Vale'
$cover2 = New-Cover 'paper' '33261F' 'B4694E' 'Paper Harbour' 'Juno Reed'
$cover3 = New-Cover 'lowtide' '232C2B' '51806D' 'Low Tide' 'The Quiet Hours'
$cover4 = New-Cover 'singles' '2A2133' '925E80' 'Singles' 'Various'

$lrc = "[00:12.00] Streetlights hum a borrowed tune`n[00:22.50] Every window is a room`n[00:33.00] I keep the city in my chest`n[00:44.00] and let it sing me into rest"

New-Track -name '01 Neon Lit Rooms.m4a' -title 'Neon Lit Rooms' -artist 'Mara Vale' -album 'Neon Lit Rooms' -genre 'Synthwave' -track 1 -seconds 214 -freq 220 -cover $cover1 -codec 'm4a' -lyrics $lrc
New-Track -name '02 Chrome Rain.mp3' -title 'Chrome Rain' -artist 'Mara Vale' -album 'Neon Lit Rooms' -genre 'Synthwave' -track 2 -seconds 187 -freq 247 -cover $cover1 -codec 'mp3'
New-Track -name '03 Last Train West.mp3' -title 'Last Train West' -artist 'Mara Vale' -album 'Neon Lit Rooms' -genre 'Synthwave' -track 3 -seconds 241 -freq 196 -cover $cover1 -codec 'mp3' -lyrics $lrc
New-Track -name '04 Paper Harbour.flac' -title 'Paper Harbour' -artist 'Juno Reed' -album 'Paper Harbour' -genre 'Folk' -track 1 -seconds 203 -freq 174 -cover $cover2 -codec 'flac'
New-Track -name '05 Salt and String.flac' -title 'Salt and String' -artist 'Juno Reed' -album 'Paper Harbour' -genre 'Folk' -track 2 -seconds 168 -freq 196 -cover $cover2 -codec 'flac'
New-Track -name '06 Lantern Hour.ogg' -title 'Lantern Hour' -artist 'Juno Reed' -album 'Paper Harbour' -genre 'Folk' -track 3 -seconds 232 -freq 261 -cover $cover2 -codec 'ogg'
New-Track -name '07 Low Tide.wav' -title 'Low Tide' -artist 'The Quiet Hours' -album 'Low Tide' -genre 'Ambient' -track 1 -seconds 312 -freq 130 -codec 'wav'
New-Track -name '08 Slow Glass.mp3' -title 'Slow Glass' -artist 'The Quiet Hours' -album 'Low Tide' -genre 'Ambient' -track 2 -seconds 296 -freq 146 -cover $cover3 -codec 'mp3'
New-Track -name '09 Still Water.mp3' -title 'Still Water' -artist 'The Quiet Hours' -album 'Low Tide' -genre 'Ambient' -track 3 -seconds 728 -freq 110 -cover $cover3 -codec 'mp3'
New-Track -name '10 Field Notes.mp3' -title 'Field Notes' -artist 'Various' -album 'Singles' -genre 'Electronic' -track 1 -seconds 201 -freq 329 -cover $cover4 -codec 'mp3'
New-Track -name '11 Voice Memo 12s.mp3' -title 'Voice Memo 12s' -artist 'Various' -album 'Singles' -genre 'Spoken' -track 2 -seconds 12 -freq 440 -codec 'mp3'
New-Track -name '12 Second Wind.mp3' -title 'Second Wind' -artist 'Various' -album 'Singles' -genre 'Electronic' -track 3 -seconds 224 -freq 293 -cover $cover4 -codec 'mp3'

Get-ChildItem $out -File | Sort-Object Name | ForEach-Object { "{0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB) }
