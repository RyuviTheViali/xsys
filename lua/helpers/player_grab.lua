local Tag = "player_physgunning"

do
	local PLAYER = FindMetaTable("Player")
	function PLAYER:IsBeingPhysgunned()
		local pl = self._is_being_physgunned
		if pl then
			if isentity(pl) and not IsValid(pl) then return false end
			return true
		end
	end

	function PLAYER:SetPhysgunImmune(bool)
		self._physgun_immune = bool
	end

	function PLAYER:IsPhysgunImmune()
		return self._physgun_immune == true
	end
end
if CLIENT then
	CreateClientConVar("physgun_dont_touch_me","0",true,true)
end

hook.Add("PhysgunPickup", Tag, function(ply, ent)
	local canphysgun = ent:IsPlayer() and not ent:IsPhysgunImmune() and not ent:InVehicle()
	if not canphysgun then return end
	if ent.IsFriend then
		canphysgun = ent:IsFriend(ply) and ent:GetInfoNum("physgun_dont_touch_me",0)==0 and ply:GetInfoNum("physgun_dont_touch_me",0)==0
	else
		canphysgun = ply:IsAdmin()
	end
	canphysgun = canphysgun or ent:IsBot()
	canphysgun = canphysgun or (ent.IsBanned and ent:IsBanned())
	canphysgun = canphysgun or ply.Unrestricted
	if not canphysgun then return end
	if IsValid(ent._is_being_physgunned) then
		if ent._is_being_physgunned ~= ply then return end
	end
	ent._is_being_physgunned_oldpos = ent:GetPos()
	ent._is_being_physgunned = ply
	ent:SetMoveType(MOVETYPE_NONE)
	ent:SetOwner(ply)
	return true
end)

local function UnGrab(ply,ent)
	ent._pos_velocity = {}
	timer.Simple(0.1, function() if not IsValid(ent) then return end ent._is_being_physgunned_oldpos = nil end)
	ent._is_being_physgunned = false
	ent:SetMoveType(ply:KeyDown(IN_ATTACK2) and ply:CheckUserGroupLevel("moderators") and MOVETYPE_NOCLIP or MOVETYPE_WALK)
	ent:SetOwner()
end

hook.Add("PhysgunDrop",Tag,function(ply, ent)
	if ent:IsPlayer() and ent._is_being_physgunned == ply then
		UnGrab(ply,ent)
		return true
	end
end)

hook.Add("EntityRemoved",Tag,function(e)
	if not e:GetClass() == "weapon_physgun" then return end
	local owner = e:GetOwner()
	if not IsValid(owner) then return end
	for k,v in next,player.GetAll() do
		if v._is_being_physgunned == owner then
			UnGrab(owner,v)
		end
	end
end)

do
	local function GetAverage(tbl)
		if #tbl == 1 then return tbl[1] end
		local average = vector_origin
		for key,vec in pairs(tbl) do average = average+vec end
		return average/#tbl
	end

	local function CalcVelocity(self,pos)
		self._pos_velocity = self._pos_velocity or {}
		if #self._pos_velocity > 10 then table.remove(self._pos_velocity,1) end
		table.insert(self._pos_velocity,pos)
		return GetAverage(self._pos_velocity)
	end

	hook.Add("Move",Tag,function(ply,data)
		if ply._is_being_physgunned and (ply:IsBeingPhysgunned() or ply:InVehicle()) then
			local vel = CalcVelocity(ply,data:GetOrigin())
			if vel:Length() > 10 then data:SetVelocity((data:GetOrigin()-vel)*8) end
			local owner = ply:GetOwner()
			if owner:IsPlayer() then
				if owner:KeyDown(IN_USE) then
					local ang = ply:GetAngles()
					ply:SetEyeAngles(Angle(ang.p,ang.y,0))
				end
			end
		end
	end)
end

hook.Add("CanPlayerSuicide", Tag, function(ply)
	if ply:IsBeingPhysgunned() then return false end
end)

hook.Add("PlayerDeath",Tag,function(ply)
	if ply:IsBeingPhysgunned() then return false end
end)

hook.Add("PlayerNoClip",Tag,function(ply)
	if ply:IsBeingPhysgunned() then return false end
end)