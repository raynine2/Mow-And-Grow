# Bug sweep, 29 Oct (applied to Studio in this order)

Each file is one `execute_luau` call in Studio's Edit mode. It checks each script's checksum (`#source .. " " .. hash`,
hash = (h*31+byte) % 2147483647) before and after, and changes nothing if either doesn't match.

1. `1-run-boss-hud-rarity-vfx.luau`: `server/Run` (the HUD hears the run time every 4 s; `bossWaiting` in the world
   state), `server/Boss` (`Boss.waiting`; `Boss.ready` pushes the world state), `client/Hud` (the timer and the area
   card), `client/RarityFx` (the stock banner waits for the first-lawn card), and the two VFX library copies' render-step
   ids (`ReplicatedStorage.VFXLib.ForgeEmit.mod.utility`, CRLF, and `ReplicatedStorage.EmitModule.mod.utility`).
2. `2-hud-boss-line-in-fight.luau`: `client/Hud`, "Beat the <boss> to open <next>" during the fight too.

Studio's checksums after: Run 44975 1537369329, Boss 61319 178453170, Hud 39514 526136225, RarityFx 58390 688338957,
ForgeEmit utility 14536 2061431077, EmitModule utility 13907 1037940973.
