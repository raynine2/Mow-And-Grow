-- (28 Oct) The weapon effects' own textures, drawn by ServerStorage.MowALawnTools.TexGen and uploaded from Studio
-- (AssetService:CreateAssetAsync; owner's brief: "custom textures ... uploaded to the owner's account"). All white /
-- grey with the shading in them: the game tints them. client/WeaponVfx and client/ViewModel read these.
return {
	puff = "rbxassetid://122437894934077", -- 4x4 flipbook: Chop A Forest's punch puff (there at once, breaks into wisps)
	star = "rbxassetid://87871024708004", -- 4-point sparkle (golden hits)
	ring = "rbxassetid://93194469868506", -- soft shockwave ring
	leaf = "rbxassetid://87895776654924", -- two-tone leaf
	blade = "rbxassetid://130937713106553", -- grass blade
	petal = "rbxassetid://95529871134294", -- blossom petal (scythe)
	trail = "rbxassetid://130447905124051", -- Beam texture: thin bright core + soft halo (swing streaks)
	smear = "rbxassetid://106542030103669", -- Beam texture: one wide soft band (fist smears)
	spark = "rbxassetid://134370296345976", -- thin streak for VelocityParallel sparks
	confetti = "rbxassetid://91550111362337", -- paper snippet (scissors)
	glow = "rbxassetid://132747667551013", -- soft round glow
}
