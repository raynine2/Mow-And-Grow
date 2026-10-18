# Mow A Lawn

A Roblox incremental game in the style of Chop A Forest, but with grass. You mow overgrown fields, carry grass
bundles to the **Giant Grass Shredder**, sell them for coins, buy better tools and mowers, beat a giant weed boss
in every zone, and earn gems that buy permanent classes and perks. The building style uses chunky studded bricks.

## How the game works

**Lobby** (public server)
- **Party pads**: SOLO starts after 3 s. A PARTY pad takes you plus up to 3 friends and starts after 15 s, or
  sooner if the host presses START NOW. Everyone on the pad teleports to a private run server.
- **Classes booth**: the stock re-rolls every 5 minutes and is the same in every lobby. Classes cost gems, are
  owned forever, and you equip one. Lawn Legend and Goat Man can also be bought with Robux.
- **Gem Perks**: Sell Value, Bigger Bundle, Mutation Luck and Gem Value, each with 5 permanent levels.
- **Free Rewards**: 35 gems every 6 hours, plus 100 gems once for joining Atlas Interactive Inc.
- **Garage**: permanent ride-on mowers, bought with gems or Robux.

**Run** (private server, saves if you leave)
1. You start with bare hands and pull grass. Every patch you cut becomes a bundle on your back.
2. When your bag is full, walk onto the SELL ring at the Shredder to turn bundles into coins.
3. Coins buy tools in order: Scissors → Sickle → Push Mower → Weed Whacker → Mega Scythe → Laser Mower.
   They also buy upgrades (Power, Backpack, Walk Speed, Sell; press Tab) and coin mowers.
4. Ride-on mowers cut while you drive and burn fuel. Refuel at the gas pumps.
5. Cutting every patch in a zone wakes its boss: Dandelion King, Thorn Bush, Venus Flytrap, Swamp Vine and
   Jungle Titan. Dodge the red circles. Beating a boss opens the next zone.
6. Zones in order: Backyard Lawn → Golf Course → Wheat Farm → Swamp Reeds → Mega Jungle.
7. **Mutations are hidden until you cut**: Golden, Rainbow, Diamond, Toxic and Galaxy. They burst when
   revealed, are worth 2–10×, and give bonus gems.
8. Beating the last boss completes the run. You get gems and go back to the lobby, and coins, tools and coin
   mowers reset.

All the numbers are in `src/shared/Config.luau`.

## Code map

| Folder | Lands in | What's there |
|---|---|---|
| `src/shared` | ReplicatedStorage.MowALawn | `Config` (all content + tuning), `Format` |
| `src/server` | ServerScriptService.MowALawn | `Main.server` (entry), `Mode`, `Net`, `PlayerData`, `Stats`, `Monetization`, lobby (`Lobby`, `LobbyBuilder`), run (`Run`, `RunBuilder`, `Field`, `Carry`, `Tools`, `Mowers`, `Boss`), `PropKit`, `Environment` |
| `src/client` | StarterPlayerScripts.MowALawnClient | `Client.client` (entry), `UI` kit, `State`, `Hud`, `Windows`, `Fx`, `Input` (tools, prompts, driving) |

## First-time setup (Windows)

1. Install **Rokit** from https://github.com/rojo-rbx/rokit, then install the Rojo plugin in Studio
   (Plugins tab → Manage Plugins, or run `rojo plugin install` after step 3).
2. Get the code. In PowerShell:
   ```powershell
   cd $HOME\Documents
   git clone https://github.com/raynine2/Mow-And-Grow.git
   cd Mow-And-Grow
   git checkout claude/nice-rubin-9w0359
   rokit install
   ```
3. In Studio, create a new **Baseplate** place and save it (File → Save to Roblox) as "Mow A Lawn".
   Turn on **Game Settings → Security → Enable Studio Access to API Services**.
4. Start Rojo and connect:
   ```powershell
   rojo serve
   ```
   In Studio, open the Rojo plugin and click **Connect**. The scripts appear in ServerScriptService,
   ReplicatedStorage and StarterPlayerScripts.
5. Press **Play**. You'll be in the lobby.

**To test a run in Studio:** press Play and walk onto the SOLO pad. Teleports don't work in Studio, so after the
countdown the same server turns into a run. In the published game, pads teleport you to a private run server.

**Studio cheats** (Command Bar while playing, server side):
```lua
game.ServerStorage.DevHook:Invoke("coins", nil, 100000)   -- give coins
game.ServerStorage.DevHook:Invoke("gems", nil, 5000)      -- give gems
game.ServerStorage.DevHook:Invoke("clearZone")            -- cut the whole current zone (spawns the boss)
game.ServerStorage.DevHook:Invoke("killBoss")             -- defeat the boss
```
Studio never saves your profile, so tests can't break real data.

## Before publishing

- Create the developer products and game passes on the Creator Dashboard, then put their ids into
  `Config.PRODUCTS` and `Config.PASSES` (an id of 0 shows "Coming soon").
- Party pads need the published game: they use reserved servers of this same place.
- Save a backup before syncing new code: File → Save to File As.
