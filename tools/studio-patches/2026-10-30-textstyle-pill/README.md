# Text style + Potato top-bar pill into Studio (30 Oct)

Run in Studio's command bar / execute_luau, **Edit mode**, in this order. Each one checks the script's checksum
first and changes nothing if it doesn't match.

1. `p0_new_textstyle.luau`, `p0_new_potatopill.luau`: create the two new ModuleScripts (exactly git's text:
   TextStyle 12264 1639211097, PotatoPill 9350 1004317079).
2. `p1`-`p6`: the font lines at the source in LobbyKit, CampBuildings, PropKit, BlackHole, ForgeDress, WorldGen
   (Studio = git for these six; each patch ends on git's exact checksum).
3. `p7_classholo.luau`: Studio's ClassHolo differs from git's (16278 1798344101): three exact find/replaces.
4. `p8_client.luau` last: the two require lines in `Client` (Studio 4015 1171987577).

Then Play and look: the pill beside Roblox's buttons, signs, windows, film subtitles.
