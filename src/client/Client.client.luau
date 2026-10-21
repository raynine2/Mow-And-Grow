-- Mow A Lawn client entry point. Loads the UI and systems, then tells the server we're ready for state.
local modules = script.Parent

local State = require(modules:WaitForChild("State"))
require(modules:WaitForChild("Sound"))
require(modules:WaitForChild("UI"))
require(modules:WaitForChild("Hud"))
require(modules:WaitForChild("Windows"))
require(modules:WaitForChild("ViewModel"))
require(modules:WaitForChild("Fx"))
require(modules:WaitForChild("Input"))
require(modules:WaitForChild("Guide"))
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

State.fire("Ready")
