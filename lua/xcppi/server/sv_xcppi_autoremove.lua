module("xcppi",package.seeall)

local sv_prop_autoremove = CreateConVar("sv_prop_autoremove","45")

function RemoveEntity(ent)
	if ent:IsWorld() or ent:IsPlayer() or not ent:IsValid() then return end
	if ent:GetClass() == "predicted_viewmodel" then return end
	if ent:CPPIGetOwner() == nil then
		ErrorNoHalt("Removing ownerless entity: "..tostring(ent)..'\n')
	end
	ent:Remove()
	return true
end

function FinishRemoveCleanup(pl)
	local id = player.ToUserID(pl)
	local name = id and player.UserIDToName(id)
	local found
	local t = _M.GetTable()
	for k,v in pairs(t) do
		if player.ToUserID(v) == id then
			found = true
			break
		end
	end
	if not found then return end
	
	Msg("[XCPPI] Cleanup >> "..(name or "???")..': ')
	assert(not IsValid(pl),"player was valid in remove timer")
	local c = 0
	for k,v in pairs(t) do
		if player.ToUserID(v) == id then
			c = c+1
			RemoveEntity(k)
		end
	end
	print(c.." props Removed")
end

function CleanupUserID(userid)
	local c = 0
	for k,v in pairs(ents.GetAll()) do
		local o = v:CPPIGetOwner()
		if o then
			local id = player.ToUserID and player.ToUserID(o)
			if id == userid then
				if RemoveEntity(v) then
					c = c+1
				end
			end
		end
	end
	if c > 0 then return c end
end

concommand.Add("cleanup_player",function(ply,cmd,args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local id = args[1] and tonumber(args[1])
	if not id then return end
	local ply
	for k,v in pairs(player.GetAll()) do
		if v:UserID() == id then ply = v break end
	end
	Msg("[XCPPI]")
	Msg("Cleaning up ",ply or id,": ")
	local c = CleanupUserID(id)
	print(c and c..' props removed' or "Nothing removed")
end)

local player_connect    = 1
local player_info       = 2
local player_spawn      = 3
local player_disconnect = 4
local player_activate   = 5
local wait_delay        = 3

function StartRemoveCleanup(pl)
	local nid = pl:SteamID()
	local track
	local function callback()
		if track then
			if track.state == player_connect then return wait_delay end
		elseif track ~= false then
			track = false
			for userid,data in pairs(gameevent.GetCache and gameevent.GetCache() or {}) do
				if data.nid == nid and data.state == player_connect then
					track = data
					local plid = player.SteamIDToUserID and player.SteamIDToUserID(nid)
					plid = plid and player.UserIDToName and player.UserIDToName(plid)
					plid = plid and (" ("..tostring(plid)..")") or ""
					return wait_delay
				end
			end
		end
		FinishRemoveCleanup(pl)
	end
	_DelayRemove(callback,sv_prop_autoremove:GetFloat())
end

function __owner_is_back(ent)
	xpcall(FreezeProp,ErrorNoHalt,ent,true)
end

function FreezeProp(ent,unfreeze)
	if not ent or not ent.IsValid or not ent:IsValid() or ent:IsWorld() then return false end
	if ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "predicted_viewmodel" then return false end
	if ent:EntIndex() <= 0 then return false end
	if ent:GetPhysicsObjectCount() < 1 then return false end
	if not ent:GetPhysicsObject() then return false end
	if not ent:GetPhysicsObjectNum(0) then return false end
	if not IsValid(ent:GetPhysicsObjectNum(0)) then return false end
	if not IsValid(ent:GetPhysicsObject()) then return false end
	if unfreeze and ent.__pp_frozen ~= true then return end
	local change
	for i=0,ent:GetPhysicsObjectCount()-1 do
		local phys = ent:GetPhysicsObjectNum(i)
		if phys and phys:IsValid() and (unfreeze or phys:IsMoveable()) then
			change = true
			phys:EnableMotion(unfreeze or false)
		end
	end
	if unfreeze then
		ent.__pp_frozen = nil
	elseif change then
		ent.__pp_frozen = true
	end
	return change
end

function FreezePlayerProps(ply,unfreeze)
	local id = isnumber(ply) and ply or plyayer.ToUserID(ply)
	local name = id and player.UserIDToName(id)
	local found
	local t = _M.GetTable()
	for k,v in pairs(t) do
		if player.ToUserID(v) == id then
			found = true
			break
		end
	end
	if not found then return end
	Msg("[XCPPI] "..(unfreeze and "Unf" or "F").."reezing props of "..(name or "???")..": ")
	local c = 0
	for k,v in pairs(t) do
		if player.ToUserID(v) == id then
			c = c+1
			local ok,err = xpcall(FreezeProp,ErrorNoHalt,k,unfreeze)
			if not ok then
				pcall(function() ErrorNoHalt("\nOffending prop: "..tostring(k).."\n") end)
			end
		end
	end
	print(c.." props "..(unfreeze and "un" or "").."frozen")
end

_M.Removers = _M.Removers or {}
local Removers = _M.Removers
function InitiateSingularity()
	local i = 0
	for k,v in pairs(Removers) do
		i = i+1
		Removers[k] = nil
		timer.Simple(i/100,k)
	end
end

timer.Simple(0,function()
	if xsys then
		local f = function(pl,txt,force) InitiateSingularity() end
		xsys.AddCommand({"gc","cdp","cleandisconnected"},f,"designers")
	end
end)

local function RemoveThink()
	local ok,now = false,SysTime()
	for k,v in pairs(Removers) do
		ok = true
		if v < now then
			Removers[k] = nil
			local newcheck = k()
			if newcheck then Removers[k] = now+newcheck end
		end
	end
	if not ok then hook.Remove("Think","prop_remover") end
end

function _DelayRemove(f,d)
	hook.Add("Think","prop_remover",RemoveThink)
	Removers[f] = SysTime()+d
end

hook.Add("EntityRemoved","prop_remover",function(ply)
	if not ply:IsPlayer() then return end
	local id = ply:UserID()
	StartRemoveCleanup(ply)
	timer.Simple(0,function()
		timer.Simple(0,function()
			FreezePlayerProps(id)
		end)
	end)
end)