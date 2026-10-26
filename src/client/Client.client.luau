-- Mow A Lawn client entry point. Loads the UI and systems, then tells the server we're ready for state.
local modules = script.Parent

local State = require(modules:WaitForChild("State"))
require(modules:WaitForChild("PhonePerf")) -- phones: shadows, bloom and sun rays off (owner, 26 Oct)
require(modules:WaitForChild("Sound"))
require(modules:WaitForChild("UI"))
require(modules:WaitForChild("Hud"))
require(modules:WaitForChild("Windows"))
require(modules:WaitForChild("PetFollow")) -- everyone's critters following them
require(modules:WaitForChild("PetsWindow")) -- EGGS / PETS window + hatching
require(modules:WaitForChild("PetIndex")) -- the PETS window's INDEX tab
require(modules:WaitForChild("NightGun")) -- boss guns, day/night, crawlers, Peaceful toggle
require(modules:WaitForChild("ViewModel"))
require(modules:WaitForChild("Soundscape")) -- footsteps, birds and breeze
require(modules:WaitForChild("Fx"))
require(modules:WaitForChild("BossCine")) -- boss fights: the model, effects, cutscenes, your HP (after Fx)
require(modules:WaitForChild("ShopDisplays")) -- tool shop status lamps + turning tools, the camp fountain
require(modules:WaitForChild("ClassHolo")) -- the CLASSES kiosk's hologram
require(modules:WaitForChild("BlackHole")) -- the CLASSES black hole: jump in for the class screen
require(modules:WaitForChild("MowFx")) -- lawn stripes behind mowers, the clippings chute, soft rings, reaper wisps
require(modules:WaitForChild("MowerFx")) -- ride-on mowers: turning wheels and blade, exhaust puffs, auras
require(modules:WaitForChild("Input"))
require(modules:WaitForChild("Guide"))
require(modules:WaitForChild("SellPointer")) -- bag full: an arrow beside you pointing to the nearest sell spot
require(modules:WaitForChild("Ambient"))
require(modules:WaitForChild("CameraView"))
require(modules:WaitForChild("ZoneMood"))
require(modules:WaitForChild("BiomeLight")) -- the generated world's per-valley lighting (runs)
require(modules:WaitForChild("EdgeLines")) -- faint lit edges on the voxel trees near you
require(modules:WaitForChild("Wind"))
require(modules:WaitForChild("Life")) -- trees swaying, wind ribbons, falling leaves, birds overhead
require(modules:WaitForChild("Combo"))
require(modules:WaitForChild("LootFx"))
require(modules:WaitForChild("Intro"))
require(modules:WaitForChild("Loading"))
require(modules:WaitForChild("PartyWindow"))
require(modules:WaitForChild("LobbyFX"))
-- after Windows: the card deal takes over the "Classes" window
require(modules:WaitForChild("ClassDeal"))
require(modules:WaitForChild("GemUpgrades")) -- takes over the "Perks" window (GEMS stall)

State.fire("Ready")
