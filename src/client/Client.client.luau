-- Mow A Lawn client entry point. Loads the UI and systems, then tells the server we're ready for state.
local modules = script.Parent

local State = require(modules:WaitForChild("State"))
require(modules:WaitForChild("Sound"))
require(modules:WaitForChild("UI"))
require(modules:WaitForChild("Hud"))
require(modules:WaitForChild("Windows"))
require(modules:WaitForChild("PetFollow")) -- everyone's critters following them
require(modules:WaitForChild("PetsWindow")) -- EGGS / PETS window + hatching
require(modules:WaitForChild("PetIndex")) -- the PETS window's INDEX tab
require(modules:WaitForChild("NightGun")) -- boss guns, day/night, crawlers, Peaceful toggle
require(modules:WaitForChild("ViewModel"))
require(modules:WaitForChild("Fx"))
require(modules:WaitForChild("Input"))
require(modules:WaitForChild("Guide"))
require(modules:WaitForChild("Ambient"))
require(modules:WaitForChild("CameraView"))
require(modules:WaitForChild("ZoneMood"))
require(modules:WaitForChild("Wind"))
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
