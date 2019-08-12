local Tag="xcppi"
module(Tag,package.seeall)

util.AddNetworkString(Tag)

net.Receive(Tag,function(l,p)
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end
	local owner = GetOwner(ent)
	local id
	if not owner or ent.owner_nonetworking then
		id = -2
	elseif type(owner)=="Player" and owner:IsPlayer() then
		id = player.ToUserID(owner)
	end
	id = id or -3
	assert(ent:EntIndex() > 0,"unable to network serverside only entities")
	net.Start(Tag)
		net.WriteBit(false)
		net.WriteEntity(ent)
		net.WriteDouble(id)
	net.Send(p)
end)

_M.Owners = _M.Owners or {}
local Owners = _M.Owners
hook.Add("PlayerInitialSpawn",Tag,function(ply)
	ReassignOwner(ply)
end)

function ReassignOwner(ply)
	local idp = ply:UniqueID()
	local recs = {}
	for k,v in pairs(Owners) do
		local uido = player.ToUserID(v)
		local ido  = player.UserIDToUniqueID(uido)
		if ido == idp then
			recs[#recs+1] = k
		end
	end
	for k,v in pairs(recs) do
		local oldown = Owners[v]
		UnsetOwner(v)
		SetOwner(v,ply)
	end
	if __owner_is_back then
		for k,v in pairs(recs) do
			__owner_is_back(v)
		end
	end
	if #recs > 0 then
		net.Start(Tag)
			net.WriteBit(true)
			net.WriteDouble(1)
		net.Broadcast()
		Msg("[XCPPI] ")
		print(ply,"recovered "..#recs.." props")
		ply:ChatPrint("[XCPPI] Assigned "..#recs.." props to you")
	end
end

function GetTable()
	return Owners
end

function SetOwner(ent,ply)
	if not ply then
		Msg("[XCPPI] ")
		print("SetOwner","Missing player")
		debug.Trace()
		return
	end
	if not IsValid(ply) or not ply:IsPlayer() then
		Msg("[XCPPI] ")
		print("SetOwner","Bad",ply)
		debug.Trace()
		return
	end
	if not ent then
		Msg("[XCPPI] ")
		print("SetOwner","Missing entity")
		debug.Trace()
		return
	end
	local cown = Owners[ent]
	if cown then
		if cown ~= ply then
			Msg("[XCPPI] ")
			print("Changing owner NOT SUPPORTED:",cown,">>",ply,"for",ent)
			return
		end
	end
	Owners[ent] = ply
end

function UnsetOwner(ent)
	if not ent then
		Msg("[XCPPI] ")
		print("UnsetOwner","Missing entity")
		debug.Trace()
		return
	end
	if Owners[ent] then
		Owners[ent] = nil
	end
end

function GetOwner(ent)
	return ent:CPPIGetOwner()
end

local em = FindMetaTable("Entity")
em.CPPISetOwner=function(ent,owner)
	if not owner then
		UnsetOwner(ent)
	else
		SetOwner(ent,owner)
	end
	return true
end

em.CPPIGetOwner=function(ent)
	return Owners[ent],654321
end

hook.Add("EntityRemoved",Tag,function(ent)
	UnsetOwner(ent)
end)

function EntitySpawned(ply,ent,ent2)
	if type(ent) == "string" then
		ent = ent2
	end
	if not ent or not ent.IsValid or not ent:IsValid() then
		ent = ent2
	end
	if ent and ent.IsValid and ent:IsValid() then
		SetOwner(ent,ply)
	end
end

hook.Add("PlayerSpawnedProp",    Tag,EntitySpawned)
hook.Add("PlayerSpawnedRagdoll", Tag,EntitySpawned)
hook.Add("PlayerSpawnedEffect",  Tag,EntitySpawned)
hook.Add("PlayerSpawnedVehicle", Tag,EntitySpawned)
hook.Add("PlayerSpawnedSENT",    Tag,EntitySpawned)
hook.Add("PlayerSpawnedNPC",     Tag,EntitySpawned)
hook.Add("PlayerSpawnedSWEP",    Tag,EntitySpawned)

local pm = FindMetaTable("Player")
local PAddCount = pm.AddCount
local Current_Undo
local undo_Create    = undo.Create
local undo_AddEntity = undo.AddEntity
local undo_SetPlayer = undo.SetPlayer
local undo_Finish    = undo.Finish
local cleanup_Add    = cleanup.Add

function RestoreUndoFunctions()
	undo.Create    = undo_Create
	undo.AddEntity = undo_AddEntity
	undo.SetPlayer = undo_SetPlayer
	undo.Finish    = undo_Finish
	pm.AddCount    = PAddCount
	cleanup.Add    = cleanup_Add
end

function cleanup.Add(ply,Type,ent,...)
	if IsValid(ply) and IsValid(ent) then
		EntitySpawned(ply,ent)
	end
	return cleanup_Add(ply,Type,ent,...)
end	

function pm.AddCount(ply,str,ent)
	local ret = PAddCount(ply,str,ent)
	EntitySpawned(ply,ent)
	return ret
end

function undo.Create(...)
	Current_Undo = {ents={}}
	return undo_Create(...)
end

function undo.AddEntity(ent)
	if not Current_Undo then return end
	if not ent or not ent:IsValid() then return end
	table.insert(Current_Undo.ents,ent)
	return undo_AddEntity(ent)
end

function undo.SetPlayer(ply)
	if not Current_Undo then return end
	if not ply or not ply:IsValid() then return end
	Current_Undo.ply = ply
	return undo_SetPlayer(ply)
end

function undo.Finish(...)
	if Current_Undo and Current_Undo.ply and Current_Undo.ply:IsValid() then
		for k,v in ipairs(Current_Undo.ents) do
			EntitySpawned(Current_Undo.ply,v)
		end
		Current_Undo = nil
	end
	return undo_Finish(...)
end

local function FindClosestInSphere(pos,what,dist)
	local t=ents.FindInSphere(pos,dist or 256)
	local closest,range = nil,256
	for k,v in pairs(t) do
		if v:GetClass() == what then
			local d =  pos:Distance(v:GetPos())
			if d < range then range,closest = d,v end
		end
	end
	return closest
end

local q,startedq = {},false
local function CheckEnt(ent)
	if not ent:IsValid() or ent:CPPIGetOwner() or ent:IsWorld() then return end
	local class = ent:GetClass()
	local owner
	if class == "npc_headcrab" then
		local pos = ent:GetPos()
		local zombie = FindClosestInSphere(pos,"npc_zombie",256)
		if zombie then owner = zombie:CPPIGetOwner() end
	elseif class == "npc_headcrab_poison" then
		local pos = ent:GetPos()
		local zombie = FindClosestInSphere(pos,"npc_poisonzombie",256)
		if zombie then owner = zombie:CPPIGetOwner() end
	elseif ent.GetPlayer then
		owner = ent:GetPlayer()
	elseif ent.Owner and ent.Owner.IsPlayer and ent.Owner:IsPlayer() then
		owner = ent.Owner
	end
	if owner and owner:IsPlayer() then
		EntitySpawned(owner,ent)
	end
end

local function CheckQ()
	local f
	for k,v in pairs(q) do
		f = true
		q[k] = nil
		local ok,err = pcall(CheckEnt,k)
		if not ok then
			ErrorNoHalt("XCPPI Check: "..err.."\n")
		end
	end
	if not f then
		startedq = false
		hook.Remove("Think",Tag)
	end
end

local function StartQ(ent)
	q[ent] = true
	if startedq then return end
	startedq = true
	hook.Add("Think",Tag,CheckQ)
end

hook.Add("OnEntityCreated",Tag,function(ent)
	if not ent.IsValid or not ent:IsValid() or ent:IsWorld() or ent:IsWeapon() or ent:CPPIGetOwner() then return end
	local class = ent:GetClass()
	if class == "predicted_viewmodel" then return end
	local pl = ent:GetOwner()
	if IsValid(pl) and pl:IsPlayer() then
		EntitySpawned(pl,ent)
		return
	end
	StartQ(ent)
end)

local class_search = {
	npc_tripmine = function(ent)
		local owner = ent:GetInternalVariable("m_hOwner") or ent:GetSaveTable().m_hOwner
		if owner and owner:IsValid() then return owner end
	end
}

function ents.FindOwner(ent)
	if ent:IsPlayer() then return ent end
	local cppi = ent.CPPIGetOwner and ent:CPPIGetOwner()
	if cppi and cppi:IsValid() then return cppi end
	local owner = ent:GetOwner()
	if owner and owner:IsValid() then return owner end
	local owner = ent:GetPhysicsAttacker()
	if owner and owner:IsValid() then return owner end
	owner = ent.Owner
	if owner and owner.IsValid and owner:IsValid() then return owner end
	local owner = ent:GetParent()
	if owner and owner:IsValid() then
		if owner:IsPlayer() then
			return owner
		else
			return ents.FindOwner(owner)
		end
	end
	local classfunc = SERVER and class_search[ent:GetClass()]
	if classfunc then return classfunc(ent) end
end