-- Config: the camp villagers' lines (Config.CAMP_LINES), put in just before the final "return Config".
local m = game.ReplicatedStorage.MowALawn.Config
local s = m.Source
local function hashOf(t)
	local x = 0
	for i = 1, #t do
		x = (x * 31 + string.byte(t, i)) % 2147483647
	end
	return #t .. " " .. x
end
if string.find(s, "Config.CAMP_LINES", 1, true) then
	return "Config already has CAMP_LINES: " .. hashOf(s)
end
if hashOf(s) ~= "91277 128436136" then
	return "NOT CHANGED: Config is " .. hashOf(s) .. " (expected 91277 128436136)"
end
local block = [====[

-------------------------------------------------------------------------------------------------------------
-- The area camps' gnome villagers (owner, 29 Oct: "make it feel more alive"; server/CampDress, client/CampLife):
-- what they say when you walk up to one (a line each time, in turn). `any`: for an area without its own.
-------------------------------------------------------------------------------------------------------------
Config.CAMP_LINES = {
	any = { "Welcome to the camp!", "Sell your clippings at the shredder!", "Mow it all and the boss wakes up!", "Nice bag of grass you've got!" },
	wheat = { "Fresh hay, fresh coins!", "The windmill never stops turning.", "Mind the chickens, they peck!", "Golden wheat sells for gold!", "The boss waits in the arena. Gulp." },
	blossom = { "Shh, the koi are shy.", "The petals fall all day here.", "Tea in the pavilion later?", "Pink grass sells for a pretty penny!", "Water the flowers, mow the grass!" },
	pine = { "It's misty up in the tower.", "Hoo! The owls see everything.", "Mind the logs, they roll.", "Chop, chop! I mean... mow, mow!", "The fire keeps the fog away." },
	swamp = { "Ribbit! Oops, wrong villager.", "The fish aren't biting today.", "Mind your boots, it's boggy!", "My house has legs. Fancy, right?", "Bubbles mean something's down there..." },
	frost = { "Brrr! Mow fast to stay warm!", "The penguins love visitors.", "The snowman's name is Gerald.", "Ice grass sells like hot cakes!", "Keep your hands in your mittens!" },
	ember = { "Careful, the ground is hot!", "Fresh from the forge!", "The salamanders keep the lava warm.", "Ash on your boots? Normal here.", "Strike while the iron's hot!" },
	isles = { "The stars are close tonight.", "Make a wish on a wisp!", "The telescope sees far, far away...", "Crystals hum if you listen.", "Mowing among the stars!" },
}
]====]
local at = nil
local from = 1
while true do
	local i = string.find(s, "\nreturn Config", from, true)
	if not i then
		break
	end
	at = i
	from = i + 1
end
if not at then
	return "NOT CHANGED: no return Config"
end
s = string.sub(s, 1, at - 1) .. block .. string.sub(s, at)
m.Source = s
return "Config done: " .. hashOf(s)
