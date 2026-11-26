param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{4}$')]
    [string]$StudentId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$resRoot = Join-Path $projectRoot 'android\app\src\main\res'
$fontPath = Join-Path $projectRoot 'assets\fonts\SpaceGrotesk-Variable.ttf'

$privateFonts = [System.Drawing.Text.PrivateFontCollection]::new()
$privateFonts.AddFontFile($fontPath)
$spaceGrotesk = $privateFonts.Families | Select-Object -First 1

function New-RoundedRectanglePath {
    param([float]$Width, [float]$Height, [float]$Radius)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = 2 * $Radius
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($Width - $diameter, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($Width - $diameter, $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-BrandBitmap {
    param(
        [int]$Size,
        [bool]$Transparent,
        [string]$Identifier
    )

    $scale = $Size / 432.0
    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        if (-not $Transparent) {
            $background = [System.Drawing.SolidBrush]::new(
                [System.Drawing.ColorTranslator]::FromHtml('#0A0F1F')
            )
            $backgroundPath = New-RoundedRectanglePath `
                -Width $Size -Height $Size -Radius (92 * $scale)
            try {
                $graphics.FillPath($background, $backgroundPath)
            } finally {
                $backgroundPath.Dispose()
                $background.Dispose()
            }
        }

        $amber = [System.Drawing.SolidBrush]::new(
            [System.Drawing.ColorTranslator]::FromHtml('#F4B860')
        )
        $ink = [System.Drawing.SolidBrush]::new(
            [System.Drawing.ColorTranslator]::FromHtml('#E8ECF8')
        )
        $band = [System.Drawing.SolidBrush]::new(
            [System.Drawing.ColorTranslator]::FromHtml('#123F3C')
        )
        $bandInk = [System.Drawing.SolidBrush]::new(
            [System.Drawing.ColorTranslator]::FromHtml('#A6F0E7')
        )

        try {
            $crescent = [System.Drawing.Drawing2D.GraphicsPath]::new(
                [System.Drawing.Drawing2D.FillMode]::Alternate
            )
            $crescent.AddEllipse(171 * $scale, 117 * $scale, 66 * $scale, 66 * $scale)
            $crescent.AddEllipse(191 * $scale, 111 * $scale, 56 * $scale, 56 * $scale)
            $graphics.FillPath($amber, $crescent)
            $crescent.Dispose()

            $mountainPoints = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(164 * $scale, 210 * $scale),
                [System.Drawing.PointF]::new(188 * $scale, 186 * $scale),
                [System.Drawing.PointF]::new(202 * $scale, 197 * $scale),
                [System.Drawing.PointF]::new(229 * $scale, 165 * $scale),
                [System.Drawing.PointF]::new(244 * $scale, 182 * $scale),
                [System.Drawing.PointF]::new(253 * $scale, 175 * $scale),
                [System.Drawing.PointF]::new(268 * $scale, 210 * $scale)
            )
            $mountainPen = [System.Drawing.Pen]::new(
                [System.Drawing.ColorTranslator]::FromHtml('#F4B860'),
                [Math]::Max(1.0, 9 * $scale)
            )
            $mountainPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $mountainPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $mountainPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $graphics.DrawLines($mountainPen, $mountainPoints)
            $mountainPen.Dispose()

            $starPoints = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new(252 * $scale, 116 * $scale),
                [System.Drawing.PointF]::new(256 * $scale, 125 * $scale),
                [System.Drawing.PointF]::new(266 * $scale, 129 * $scale),
                [System.Drawing.PointF]::new(256 * $scale, 133 * $scale),
                [System.Drawing.PointF]::new(252 * $scale, 143 * $scale),
                [System.Drawing.PointF]::new(248 * $scale, 133 * $scale),
                [System.Drawing.PointF]::new(238 * $scale, 129 * $scale),
                [System.Drawing.PointF]::new(248 * $scale, 125 * $scale)
            )
            $graphics.FillPolygon($amber, $starPoints)

            $hasIdentifier = -not [string]::IsNullOrWhiteSpace($Identifier)
            $nameY = if ($hasIdentifier) { 230.0 } else { 244.0 }
            $nameHeight = if ($hasIdentifier) { 52.0 } else { 70.0 }
            $fontStyle = [System.Drawing.FontStyle]::Bold
            try {
                $nameFont = [System.Drawing.Font]::new(
                    $spaceGrotesk,
                    [Math]::Max(1.0, 48 * $scale),
                    $fontStyle,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            } catch {
                $nameFont = [System.Drawing.Font]::new(
                    $spaceGrotesk,
                    [Math]::Max(1.0, 48 * $scale),
                    [System.Drawing.FontStyle]::Regular,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            }
            $format = [System.Drawing.StringFormat]::new()
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $nameRect = [System.Drawing.RectangleF]::new(
                70 * $scale,
                $nameY * $scale,
                292 * $scale,
                $nameHeight * $scale
            )
            $graphics.DrawString('CieloRD', $nameFont, $ink, $nameRect, $format)
            $nameFont.Dispose()

            if ($hasIdentifier) {
                $bandPath = New-RoundedRectanglePath `
                    -Width (176 * $scale) -Height (36 * $scale) -Radius (18 * $scale)
                $translate = [System.Drawing.Drawing2D.Matrix]::new()
                $translate.Translate(128 * $scale, 284 * $scale)
                $bandPath.Transform($translate)
                $graphics.FillPath($band, $bandPath)
                $translate.Dispose()
                $bandPath.Dispose()

                $idFont = [System.Drawing.Font]::new(
                    $spaceGrotesk,
                    [Math]::Max(1.0, 22 * $scale),
                    [System.Drawing.FontStyle]::Bold,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
                $idRect = [System.Drawing.RectangleF]::new(
                    128 * $scale,
                    284 * $scale,
                    176 * $scale,
                    36 * $scale
                )
                $graphics.DrawString($Identifier, $idFont, $bandInk, $idRect, $format)
                $idFont.Dispose()
            }
            $format.Dispose()
        } finally {
            $amber.Dispose()
            $ink.Dispose()
            $band.Dispose()
            $bandInk.Dispose()
        }
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

$densities = [ordered]@{
    'mdpi' = @{ legacy = 48; foreground = 108 }
    'hdpi' = @{ legacy = 72; foreground = 162 }
    'xhdpi' = @{ legacy = 96; foreground = 216 }
    'xxhdpi' = @{ legacy = 144; foreground = 324 }
    'xxxhdpi' = @{ legacy = 192; foreground = 432 }
}

foreach ($entry in $densities.GetEnumerator()) {
    $targetDirectory = Join-Path $resRoot "mipmap-$($entry.Key)"
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    $legacy = New-BrandBitmap -Size $entry.Value.legacy -Transparent $false -Identifier $StudentId
    try {
        $legacy.Save(
            (Join-Path $targetDirectory 'ic_launcher.png'),
            [System.Drawing.Imaging.ImageFormat]::Png
        )
    } finally {
        $legacy.Dispose()
    }

    $foreground = New-BrandBitmap -Size $entry.Value.foreground -Transparent $true -Identifier $StudentId
    try {
        $foreground.Save(
            (Join-Path $targetDirectory 'ic_launcher_foreground.png'),
            [System.Drawing.Imaging.ImageFormat]::Png
        )
    } finally {
        $foreground.Dispose()
    }
}

$privateFonts.Dispose()
Write-Output "Recursos Android finales generados para $StudentId en: $resRoot"
