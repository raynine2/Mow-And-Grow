-- client/Settings: the SETTINGS gear and panel hidden (owner, 30 Oct: "remove this for now"). Studio's copy differs
-- from git's: anchored on one line both have; refuses if it's already there.
local m = game.StarterPlayer.StarterPlayerScripts.MowALawnClient.Settings
local s = m.Source
if string.find(s, "holder.Visible = false", 1, true) then
	return "Settings already hides the gear"
end
local anchor = "\tholder.Parent = hud\n"
local i, j = string.find(s, anchor, 1, true)
if not i or string.find(s, anchor, j + 1, true) then
	return "anchor not found once"
end
s = string.sub(s, 1, j) .. [======[	-- (30 Oct, owner: "remove this for now": hidden; Potato Mode is the top-bar pill, client/PotatoPill, and the saved
	-- choices still load above. Set this to true to bring the gear back.)
	holder.Visible = false
]======] .. string.sub(s, j + 1)
m.Source = s
return "Settings done (" .. #s .. " chars)"
