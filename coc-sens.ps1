#requires -Version 5
<#
  Get/Set/Match Call of Cthulhu (2018) mouse sensitivity.

  CoC stores no sensitivity value in its .ini files. The setting is a UE4
  FloatProperty named "CameraSensibility" inside the binary save:
    %LOCALAPPDATA%\CallOfCthulhu\Saved\SaveGames\Configuration.sav
  Place this script in that same SaveGames folder and run it from there.

  Usage:
    .\coc-sens.ps1 get                                    # read current value
    .\coc-sens.ps1 set 16.0                               # write a raw value
    .\coc-sens.ps1 match -Bf6Cm360 27 -MeasuredCm 34.3    # match another game's cm/360

  'match' tunes CameraSensibility so a full 360 turn takes the same physical
  mouse distance (cm/360) as a reference game. CameraSensibility is a linear
  multiplier, so one measurement is exact:
    1. Run 'get' to see the current value.
    2. In-game, measure cm of mouse travel for one 360 turn at that value.
    3. Pass it as -MeasuredCm, and the target as -Bf6Cm360 (e.g. from
       mouse-sensitivity.com). DPI cancels out, so it need not match.
  Alternatively, omit -Bf6Cm360 and pass -Dpi (+ optional -Bf6Decimal) to
  estimate the Battlefield 6 hipfire target from its sensitivity formula.

  Close the game before writing: it overwrites the save on exit. Every write
  makes a Configuration.sav.bak backup first.
#>
param(
    [Parameter(Mandatory)][ValidateSet('get', 'set', 'match')][string]$Command,
    [double]$Value,
    [double]$Dpi,
    [double]$MeasuredCm,           # measured CoC cm/360 at the CURRENT CameraSensibility
    [double]$Bf6Cm360,             # known BF6 cm/360 (e.g. 27 from mouse-sensitivity.com) — preferred
    [double]$Bf6Decimal = 0.017250 # GstInput.MouseSensitivity (used only if -Bf6Cm360 not given)
)

# Battlefield hipfire: cm/360 = 810 / inGameValue at 800 DPI; inGameValue = decimal / 0.00075
$BF_C800 = 810.0

$ErrorActionPreference = 'Stop'
$SavePath = Join-Path $PSScriptRoot 'Configuration.sav'
$PropName = 'CameraSensibility'

function Get-FloatOffset([byte[]]$b) {
    $ascii = [System.Text.Encoding]::ASCII.GetString($b)
    $i = $ascii.IndexOf($PropName)
    if ($i -lt 0) { throw "'$PropName' not found in $SavePath" }
    # UE4 layout from name text: name\0, int32 typeLen, type\0, int64 size, byte guidFlag, value
    $p = $i + $PropName.Length + 1            # past name + null
    $typeLen = [System.BitConverter]::ToInt32($b, $p); $p += 4
    $type = [System.Text.Encoding]::ASCII.GetString($b, $p, $typeLen - 1)
    if ($type -ne 'FloatProperty') { throw "Unexpected type '$type' (expected FloatProperty)" }
    $p += $typeLen                            # past type + null
    $p += 8                                   # int64 size
    $p += 1                                   # guid flag byte
    return $p
}

function Write-Sens([byte[]]$b, [int]$off, [double]$v) {
    $old = [System.BitConverter]::ToSingle($b, $off)
    Copy-Item $SavePath "$SavePath.bak" -Force
    [Array]::Copy([System.BitConverter]::GetBytes([single]$v), 0, $b, $off, 4)
    [System.IO.File]::WriteAllBytes($SavePath, $b)
    "CameraSensibility: $old -> $v  (backup: $SavePath.bak)"
}

$bytes = [System.IO.File]::ReadAllBytes($SavePath)
$off = Get-FloatOffset $bytes

switch ($Command) {
    'get' {
        $v = [System.BitConverter]::ToSingle($bytes, $off)
        "CameraSensibility = $v"
    }
    'set' {
        if (-not $PSBoundParameters.ContainsKey('Value')) { throw 'set requires a value, e.g. set 16.0' }
        Write-Sens $bytes $off $Value
    }
    'match' {
        if (-not $PSBoundParameters.ContainsKey('MeasuredCm')) {
            throw 'match requires -MeasuredCm (measure CoC cm/360 at the current CameraSensibility first)'
        }
        $current = [System.BitConverter]::ToSingle($bytes, $off)
        if ($PSBoundParameters.ContainsKey('Bf6Cm360')) {
            $bf6cm = $Bf6Cm360                            # authoritative cm/360
            "BF6 target cm/360: $bf6cm cm (provided)"
        }
        else {
            if (-not $PSBoundParameters.ContainsKey('Dpi')) { throw 'provide -Bf6Cm360, or -Dpi to compute it' }
            $inGame = $Bf6Decimal / 0.00075
            $bf6cm = ($BF_C800 / $inGame) * (800.0 / $Dpi)
            "BF6 in-game sens : $inGame  (decimal $Bf6Decimal)"
            "BF6 target cm/360: $([math]::Round($bf6cm,2)) cm @ $Dpi DPI (estimated)"
        }
        $target = $current * ($MeasuredCm / $bf6cm)
        "CoC measured     : $MeasuredCm cm/360 at CameraSensibility $current"
        "==> target CameraSensibility = $([math]::Round($target,4))"
        Write-Sens $bytes $off $target
    }
}
