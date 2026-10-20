$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$directory = Join-Path (Split-Path $PSScriptRoot -Parent) 'icons'
$frames = @()
foreach ($size in @(16, 24, 32, 48, 96, 256)) {
    $canvas = [System.Drawing.Bitmap]::new($size * 4, $size * 4)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.ScaleTransform($size / 16.0, $size / 16.0)
    $background = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $background.AddArc(4, 4, 28, 28, 180, 90)
    $background.AddArc(32, 4, 28, 28, 270, 90)
    $background.AddArc(32, 32, 28, 28, 0, 90)
    $background.AddArc(4, 32, 28, 28, 90, 90)
    $background.CloseFigure()
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#CC2936'))
    $graphics.FillPath($brush, $background)
    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 4)
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawLine($pen, 32, 17, 32, 35)
    $graphics.DrawLines($pen, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(24, 27), [System.Drawing.PointF]::new(32, 35), [System.Drawing.PointF]::new(40, 27)))
    $graphics.DrawLines($pen, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(20, 39), [System.Drawing.PointF]::new(20, 47),
        [System.Drawing.PointF]::new(44, 47), [System.Drawing.PointF]::new(44, 39)))
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $scaled = [System.Drawing.Graphics]::FromImage($bitmap)
    $scaled.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scaled.DrawImage($canvas, 0, 0, $size, $size)
    $pngPath = Join-Path $directory "icon-$size.png"
    $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    if ($size -ne 96) { $frames += ,([System.IO.File]::ReadAllBytes($pngPath)) }
    $scaled.Dispose(); $bitmap.Dispose(); $pen.Dispose(); $brush.Dispose()
    $background.Dispose(); $graphics.Dispose(); $canvas.Dispose()
}
$stream = [System.IO.File]::Create((Join-Path $directory 'icon.ico'))
$writer = [System.IO.BinaryWriter]::new($stream)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
    $offset = 6 + 16 * $frames.Count
    $sizes = @(16, 24, 32, 48, 256)
    for ($i = 0; $i -lt $frames.Count; $i++) {
        $dimension = $sizes[$i] % 256
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$frames[$i].Length); $writer.Write([uint32]$offset)
        $offset += $frames[$i].Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
}
finally { $writer.Dispose(); $stream.Dispose() }
Write-Output 'Generated plugin PNGs and multi-resolution Windows tray icon.'
