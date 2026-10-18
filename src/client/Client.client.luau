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

State.fire("Ready")
