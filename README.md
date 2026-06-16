# coc-sens

A tiny PowerShell tool to **read, set, and sensitivity-match** the mouse sensitivity in
**Call of Cthulhu (2018)** — the Cyanide/Focus Home game built on Unreal Engine 4.

## Why this exists

Call of Cthulhu stores **no mouse sensitivity value in any of its `.ini` files**. The
in-game "Camera Sensitivity" slider is written into a binary save file instead, as a
UE4 `FloatProperty` named **`CameraSensibility`**:

```
%LOCALAPPDATA%\CallOfCthulhu\Saved\SaveGames\Configuration.sav
```

That makes it impossible to tweak in a text editor and impossible to match against other
games with the usual converters (CoC isn't in any sensitivity database). This script reads
and writes that float directly, and can tune it to match another game's **cm/360**
(the physical mouse distance for one full 360° turn).

## Install

1. Copy `coc-sens.ps1` into your `...\CallOfCthulhu\Saved\SaveGames\` folder.
2. Run it from there in PowerShell.

## Usage

```powershell
# Read the current value
.\coc-sens.ps1 get

# Write a raw value
.\coc-sens.ps1 set 16.0

# Match another game's cm/360 (see below)
.\coc-sens.ps1 match -Bf6Cm360 27 -MeasuredCm 34.3
```

Every write first makes a `Configuration.sav.bak` backup. **Close the game before
writing** — it overwrites the save on exit and would clobber your change.

## Matching to another game (e.g. Battlefield 6)

`CameraSensibility` is a linear multiplier, so a single measurement gives an *exact* match:

1. Run `get` to see the current value.
2. In-game, at that value, measure the cm of mouse travel for one full 360° turn
   (lay a ruler along your mousepad). A 180° turn doubled works too.
3. Run `match`, passing your measurement and the target cm/360 from your other game
   (e.g. from [mouse-sensitivity.com](https://www.mouse-sensitivity.com/)):

```powershell
.\coc-sens.ps1 match -Bf6Cm360 27 -MeasuredCm 34.3
```

DPI cancels out of the ratio, so it doesn't need to match between the games — only that
both numbers are physical centimeters.

### Estimating the BF6 target instead

If you don't have a converter number, the script can estimate the Battlefield 6 hipfire
target from its sensitivity formula (`cm/360 = 810 / inGameValue` at 800 DPI, where
`inGameValue = GstInput.MouseSensitivity / 0.00075`):

```powershell
.\coc-sens.ps1 match -Dpi 800 -Bf6Decimal 0.017250 -MeasuredCm 34.3
```

## How it finds the value

It locates the `CameraSensibility` string in the save and walks the UE4 property header
(`name → type → size → guid flag → value`) to find the 4-byte float, rather than relying
on a hardcoded offset — so it survives minor layout shifts.

## Disclaimer

Edits a save file. There's a built-in backup, but use at your own risk.
