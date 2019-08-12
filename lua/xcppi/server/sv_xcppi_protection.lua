module("xcppi",package.seeall)
local Tag = "xcppi_protect"
local CANT_TELL,PASSTHROUGH = nil,nil

local assert = function(a,b)
	if not a then ErrorNoHalt("[XCPPI] Assert >> "..debug.traceback(tostring(b or ""),2):sub(2,-1)..'\n') end
	return a
end

function AreFriends(pl1,pl2)
	if pl1:AreFriends(pl2) then return true end
end

local xcppi_enabled = CreateConVar("xcppi_protect_enabled","1")
local xcppi_map_protect = CreateConVar("xcppi_map_protect","1")

function HasPlayerSet(ply,info)
	if ply and ply:IsValid() and ply:IsPlayer() and ply:GetInfoNum("xcppi_"..info,0) == 1 then
		return true
	end
end

function ProtectionDisabled(ply)
	if not xcppi_enabled:GetBool() then return true end
	if HasPlayerSet(ply,"disable") then return true end
end

function AllowsPhysgun(pl)
	if HasPlayerSet(pl,"physgunning") then return true end
end

function _PreventMapTouch(pl,ent,how,what)
	if not xcppi_map_protect:GetBool() then return PASSTHROUGH end
	local ret = hook.Call("PreventTouch",nil,pl,ent,how,what)
	if ret ~= nil then return ret end
	if how == "PlayerUse" then return CANT_TELL end
	if HasPlayerSet(pl,"restrictme") then return true end
	if how == "GravGunOnPickedUp" or how == "GravGunPunt" then return CANT_TELL end
	if pl.Unrestricted then return PASSTHROUGH end
	if pl:IsAdmin("propprotect") and HasPlayerSet(pl,"unrestrictme") then return PASSTHROUGH end
	return true
end

function PreventTouch(ply,ent,how,what)
	if not xcppi_enabled:GetBool() then return CANT_TELL end
	if ent and ent:IsWorld() then return CANT_TELL end
	if not assert(ent and ent:IsValid(),"CanTouch entity not entity") then return PASSTHROUGH end
	if not assert(ply and ply:IsPlayer(),"plyy not a player: "..tostring(ply)) then return PASSTHROUGH end
	if ent:IsPlayer() then return CANT_TELL end
	local owner = ent:CPPIGetOwner()
	local entowner = ent:GetOwner()
	if entowner:IsValid() and ent:GetParent() == entowner then owner = entowner end
	if not owner then
		if ent:MapCreationID() > 0 then return _PreventMapTouch(ply,ent,how,what) end
		return CANT_TELL
	end
	local ret = hook.Call("PreventTouch",nil,ply,ent,how,what)
	if ret ~= nil then return ret end
	if ply == owner then
		if HasPlayerSet(ply,"hate_self") then return true end
		return PASSTHROUGH
	end
	if not assert(owner and owner:IsPlayer(),"ply not a plyayer: "..tostring(owner).." - "..tostring(ply)) then return PASSTHROUGH end
	if how == "PlayerUse" then return CANT_TELL end
	if HasPlayerSet(ply,"restrictme") then return true end
	if (how == "PhysgunPickup" or how == "OnPhysgunFreeze") and AllowsPhysgun(owner) then return CANT_TELL end
	if owner.__disablepp then return PASSTHROUGH end
	if ply.Unrestricted then return PASSTHROUGH end
	if ply:IsAdmin("propprotect") and HasPlayerSet(ply,"unrestrictme") then return PASSTHROUGH end
	if ProtectionDisabled(owner) then return PASSTHROUGH end
	if AreFriends(ply,owner) then return PASSTHROUGH end
	return true
end

local function HASPROPFUNC(ent,func,...)
	if type(ent[func]) == "function" then
		local val = ent[func](ent,...)
		if val ~= nil then return true end
	end
end

local inPhysgunPickup
function PhysgunPickup(pl,ent)
	if inPhysgunPickup then
		if inPhysgunPickup > 0 then
			inPhysgunPickup = inPhysgunPickup-1
		else
			inPhysgunPickup = false
		end
		ErrorNoHalt("InPhysgunPickup\n")
		debug.Trace()
		return
	end
	if ent:IsPlayer() then return CANT_TELL end
	inPhysgunPickup = 5
	if HASPROPFUNC(ent,'PhysgunPickup',pl,ent) then inPhysgunPickup = false return PASSTHROUGH end
	if PreventTouch(pl,ent,'PhysgunPickup') then inPhysgunPickup = false return false end
	inPhysgunPickup = false
	return PASSTHROUGH
end

function EntityTakeDamage(ent,dmginfo)
	return PASSTHROUGH
end

function PlayerUse(ply,ent)
	if not ply or not ply:IsPlayer() then
		Msg("Invalid call to PlayerUse, player is not player. ")
		debug.Trace()
		return CANT_TELL
	end
	if not ent or ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,'PlayerUse',ply,ent) then return PASSTHROUGH end
	if PreventTouch(ply,ent,'PlayerUse') then return false end
	return PASSTHROUGH
end

function GravGunPunt(pl,ent)
	return PASSTHROUGH
end

function CanPlayerEnterVehicle(pl,ent)
	return PASSTHROUGH
end

function GravGunOnPickedUp(pl,ent)
	return PASSTHROUGH
end

function OnPhysgunFreeze(wep, phys, ent, pl)
	if ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,"OnPhysgunFreeze",pl,ent) then return PASSTHROUGH end
	if PreventTouch(pl,ent,'OnPhysgunFreeze') then return false  end
	return PASSTHROUGH
end

function OnPhysgunReload(wep,pl)
	local ent = pl:GetEyeTrace().Entity
	if not IsValid(ent) then return CANT_TELL end
	if ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,"OnPhysgunReload",pl,ent) then return PASSTHROUGH end
	if PreventTouch(pl,ent,"OnPhysgunReload") then return false  end
	return PASSTHROUGH
end

TracingTools = {
	hydraulic      = true,
	slider         = true,
	winch          = true,
	muscle         = true,
	wire_winch     = true,
	wire_hydraulic = true,
}

function CanTool(ply,tr,mode,enty)
	if enty and isentity(enty) and IsValid(tr.Entity) and enty~=tr.Entity then
		ErrorNoHalt("CanTool got ",enty," but it isnt ",tr.Entity,", HOW?\n")
	end
	local ent = tr.Entity
	if not IsValid(ent) then return CANT_TELL end
	if not IsValid(ply) or not ply:IsPlayer() then return CANT_TELL end
	if ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,"CanTool",ply,tr,mode,enty or tr.Entity) then return PASSTHROUGH end
	if PreventTouch(ply,ent,"CanTool",mode) then return false end
	for k,v in pairs(ply:GetTool() and ply:GetTool().Objects or {}) do
		local toolent = v.Ent
		if toolent and IsValid(toolent) then
			if PreventTouch(ply,toolent,"CanTool",mode) then return false end
		end
	end
	if mode == "remover" and ply:KeyDown(IN_ATTACK2) and not ply:KeyDownLast(IN_ATTACK2) then
		for k,v in pairs(constraint.GetAllConstrainedEntities(ent) or {}) do
			if PreventTouch(ply,v,"CanTool",mode) then return false end
		end
	end
	if TracingTools[mode:lower()] and ply:KeyDown(IN_ATTACK2) and not ply:KeyDownLast(IN_ATTACK2) then
		local trace = {}
		trace.start  = tr.HitPos
		trace.endpos = trace.start+(tr.HitNormal*16384)
		trace.filter = {ply}
		if tr.Entity:IsValid() then table.insert(trace.filter,tr.Entity) end
		local tr2 = util.TraceLine(trace)
		if tr2.Hit and not (tr.HitWorld and tr2.HitWorld) and not (tr.Entity:IsValid() and tr.Entity:IsPlayer()) and not (tr2.Entity:IsValid() and tr2.Entity:IsPlayer()) and tr2.Entity:IsValid() then
			if PreventTouch(ply,tr2.Entity,"CanTool",mode) then return false end
		end
	end
	return PASSTHROUGH
end

local inToolSetObject
function ToolSetObject(obj,i,ent,...)
	if inToolSetObject then
		inToolSetObject = inToolSetObject > 0 and inToolSetObject-1 or false
		ErrorNoHalt("ToolSetObject RE-ENTRY\n")
		if debug and debug.Trace then debug.Trace() end
		return
	end
	if not IsValid(ent) or ent:IsPlayer() then return CANT_TELL end
	local pl = obj.GetOwner and obj:GetOwner()
	if not IsValid(pl) then return CANT_TELL end
	inToolSetObject = 5
	if PreventTouch(pl,ent,"ToolSetObject") then
		if obj.ClearObjects then obj:ClearObjects()end
		inToolSetObject = false
		return false
	end
	inToolSetObject = false
end

timer.Simple(0,function()
	if _M._ToolObj_SetObject then
		Msg("[XCPPI] ")
		print("Not reoverriding ToolObj.SetObject")
	end
	local GM = GAMEMODE or GM
	if GM.ToolSetObject then return end
	local gmod_tool = weapons.GetStored("gmod_tool")
	if not gmod_tool then return end
	local Tool = gmod_tool.Tool
	if not Tool then
		ErrorNoHalt("Warning: toolgun protection broken (Tool system modified?)\n")
		return
	end
	local _,tbl = next(Tool)
	if not tbl then
		ErrorNoHalt("Warning: toolgun protection broken (no tools found)\n")
		return
	end
	local ToolObj = getmetatable(tbl)
	if not ToolObj then
		ErrorNoHalt("Warning: toolgun protection broken (ToolObj missing)\n")
		return
	end
	if not ToolObj.__index then
		ErrorNoHalt("Warning: toolgun protection broken (ToolObj index missing)\n")
		return
	end
	ToolObj = ToolObj.__index
	if not ToolObj.SetObject then
		ErrorNoHalt("Warning: toolgun protection broken (SetObject missing)\n")
		return
	end
	_M._ToolObj_SetObject = _M._ToolObj_SetObject or ToolObj.SetObject
	ToolObj.pp_SetObject  = ToolObj.pp_SetObject  or ToolObj.SetObject
	function ToolObj:SetObject(...)
		if hook.Run("ToolSetObject",self,...) == false then return end
		return self:pp_SetObject(...)
	end
end)

function CanProperty(pl,property,ent)
	if ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,'CanProperty',pl,ent) then return PASSTHROUGH end
	if PreventTouch(pl,ent,'CanProperty',property) then return false  end
	return PASSTHROUGH
end

function CanDrive(pl,ent)
	if ent:IsPlayer() then return CANT_TELL end
	if HASPROPFUNC(ent,'CanDrive',pl,ent) then return PASSTHROUGH end
	if PreventTouch(pl,ent,'CanDrive',property) then return false  end
	return PASSTHROUGH
end

local function wrap(f)
	local infunc = false
	local function ret(...)
		infunc = false
		return ...
	end
	return function(...)
		if infunc then return end
		infunc = true
		return ret(f(...))
	end
end

hook.Add("PhysgunPickup",         Tag,PhysgunPickup)
hook.Add("EntityTakeDamage",      Tag,EntityTakeDamage)
hook.Add("PlayerUse",             Tag,PlayerUse)
hook.Add("GravGunPunt",           Tag,GravGunPunt)
hook.Add("GravGunOnPickedUp",     Tag,GravGunOnPickedUp)
hook.Add("OnPhysgunFreeze",       Tag,OnPhysgunFreeze)
hook.Add("OnPhysgunReload",       Tag,OnPhysgunReload)
hook.Add("CanTool",               Tag,CanTool)
hook.Add("CanProperty",           Tag,CanProperty)
hook.Add("CanDrive",              Tag,CanDrive)
hook.Add("CanPlayerEnterVehicle", Tag,CanPlayerEnterVehicle)
hook.Add("ToolSetObject",         Tag,ToolSetObject)