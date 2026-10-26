-- ForgeGUI building models (textured meshes, approved by the owner on 23 Oct; records in
-- assets/forgegui_models.json). server/Models loads each as the template "forge_<name>", keeps its painted texture,
-- stands it on its feet (pivot at the bottom centre) and turns it so its front faces the pivot's LookVector.
-- FORGE_SWAP in server/Models says which older models they replace.
return {
	bagstand = 89479177629481,
	shredder = 122216742633383,
	windmill = 98872799097988,
	lodge = 83216758022373,
	barn = 87691690990474,
	rewards = 71692087163918,
	startgate = 81723837273613,
	leaderboard = 101353987186694,
	lm_blossom = 76069617427255,
	lm_wheat = 140161198185129,
	lm_pine = 120907520324654,
	lm_swamp = 122886070654489,
	lm_frost = 85463365553189,
	lm_ember = 87118546176920,
	lm_starlight = 90425779548628,
	house_red = 87898019152043,
	house_blue = 122703325704658,
	-- 26 Oct (the owner: "remake the fountain, every sign and the boss areas with forgegui"): the camp fountain
	-- (server/CampFountain), the drop-off bins and area archways (server/ForgeDress), the lobby party booths
	-- (server/LobbyPads), the boss arena gateways and summon altar (server/BossArena)
	fountain = 82568929623199,
	dropoff = 131787783453543,
	partybooth = 97998160921780,
	altar = 127212826627130,
	gate_blossom = 118481985520587,
	gate_swamp = 109418497237639,
	gate_ember = 83338532938788,
	gate_starlight = 120530589946580,
	arena_meadow = 72812439262906,
	arena_hedge = 119760703897452,
	arena_bunker = 89188908030942,
	arena_cornfield = 125419026188869,
	arena_sakura = 130442464493828,
	arena_swamp = 75474451775473,
	arena_pumpkin = 74165472176746,
	arena_ruins = 84244292155553,
}
