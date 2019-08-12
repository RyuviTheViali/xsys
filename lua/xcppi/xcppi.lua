CPPI = CPPI or {}
local CPPI=CPPI

module("xcppi",package.seeall)

CPPI.CPPI_DEFER = 54321
CPPI.CPPI_NOTIMPLEMENTED = 654321

function CPPI:GetName()
	return "Xcppi"
end

function CPPI:GetVersion()
	return "1"
end

function CPPI:GetInterfaceVersion()
	return 1.1
end

function CPPI:GetNameFromUID(uid)
	if player.UserIDToName then
		return player.UserIDToName(uid)
	end
	return CPPI.CPPI_NOTIMPLEMENTED
end

local Player = FindMetaTable"Player"

function Player:CPPIGetFriends()
	if not self:IsValid() then return {} end
	local t = {}
	for k,v in pairs(player.GetHumans()) do
		if self ~= v and (AreFriends(self,v) or (CLIENT and v:GetFriendStatus() == "friend")) then t[#t+1] = v end
	end
	return t
end

local Entity = FindMetaTable"Entity"

Entity.CPPISetOwnerUID = function(ent,id)
	return CPPI.CPPI_NOTIMPLEMENTED
end

function Entity:CPPICanTool(pl,mode)
	return true
end

function Entity:CPPICanPhysgun(pl)
	return true
end

function Entity:CPPICanPickup(pl)
	return true
end

function Entity:CPPICanPunt(pl)
	return true
end

function Entity:CPPICanDamage(pl)
	return true
end

function Entity:CPPICanUse(pl)
	return true
end

if CLIENT then return end

function Entity.CPPICanTool(ent,pl,mode,huh)
	if huh then error("called incorrectly") end
	mode = tostring(mode or "")
	if not IsValid(ent) then return true end
	if not IsValid(pl) or not pl:IsPlayer() then return true end
	if ent:IsPlayer() then return true end
	if PreventTouch(pl,ent,"CanTool",mode) then return false end
	return true
end

function Entity.CPPICanPhysgun(ent,pl)
	if not IsValid(ent) then return true end
	if not IsValid(pl) or not pl:IsPlayer() then return true end
	if ent:IsPlayer() then return true end
	if PreventTouch(pl,ent,"PhysgunPickup") then return false end
	return true
end
