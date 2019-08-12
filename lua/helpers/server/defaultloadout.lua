hook.Add("Initialize","XsysDefaultWeapons",function()
	GAMEMODE.WeaponTable = {
		"gmod_tool",
		"gmod_camera",
		"none",
		"weapon_physgun",
		"weapon_crowbar",
		"weapon_physcannon"--"weapon_stunstick"
	}
end)

hook.Add("PlayerLoadout","XsysPlayerLoadout",function(ply)
	if not GAMEMODE.WeaponTable then return end
	for k,v in pairs(GAMEMODE.WeaponTable) do
		ply:Give(v)
	end
	ply:SelectWeapon("none")
	return true
end)