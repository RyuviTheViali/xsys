local tag = "player_cache"
local next = next
local cache = player.GetAllCached and player.GetAllCached() or {}
local cache_count = player.CountAll and player.CountAll() or 0

function player.GetAllCached() return cache       end
function player.CountAll()     return cache_count end
function player.All()          return next,cache  end

function player.iterator()
	local i = 1
	local function iter_all()
		local val = cache[i]
		i = val and i + 1 or 1
		return val
	end
	return iter_all
end

local SERVER = SERVER
local function EntityCreated(ply)
	if ply:IsPlayer() then
		if SERVER then
			local id = ply:UserID()
			for k,v in next,cache do
				if id == v:UserID() then
					table.remove(cache,k)
					cache_count = cache_count-1
					return
				end
			end
		end
		table.insert(cache,ply)
		cache_count = cache_count+1
	end
end

if SERVER then
	hook.Add("OnEntityCreated",tag,EntityCreated)
else
	hook.Add("NetworkEntityCreated",tag,EntityCreated)
end

local function add(ply)
	for k,v in next,cache do
		if v == ply then return end
	end
	table.insert(cache,ply)
	cache_count = cache_count+1
end
for k,v in next,player.GetAll() do add(ply) end

local function EntityRemoved(ply)
	if ply:IsPlayer() then
		for k,v in next,cache do
			if ply == v then
				table.remove(cache,k)
				cache_count = cache_count-1
			end
		end
	end
end

if SERVER then
	hook.Add("PlayerDisconnected",tag,EntityRemoved)
end
hook.Add("EntityRemoved",tag,EntityRemoved)





local tag = "PlayerSlowThink" --By: Python1320, original by Lixquid

local RealTime = RealTime
local player = player
local hook = hook
local next = next
local FrameTime = FrameTime
local math = math
local ticint
	local function getintervals()
		return ticint
	end
	
	local function getintervalc()
		local ft = FrameTime()
		return ft > 0.3 and 0.3 or ft
	end
	
	local getinterval
	getinterval = function()
		if SERVER then
			ticint = engine.TickInterval()
			getinterval = getintervals
		else
			getinterval = getintervalc
		end
	
		return getinterval()
	end
	
local iterating_players = {  }
local function refreshplayers(t)
	local pls = player.GetAllCached()
	local plsc = #pls
	for i = 1, plsc do
		iterating_players[i] = pls[i]
	end

	local ipc = #iterating_players
	if ipc == plsc then
		return plsc
	end

	for i = ipc, plsc + 1, -1 do
		iterating_players[i] = nil
	end

	return plsc
end

function GetPlayerThinkCache()
	return iterating_players
end

local function Call(pl)
	if not pl:IsValid() then
		return
	end

	hook.Call(tag, nil, pl)
end

local iterid = 1
local function iter()
	iterid = iterid + 1
	local pl = iterating_players[iterid]
	if pl == nil then
		iterid = 1
		return true
	end

	Call(pl)
end

local iterations_per_tick
local iterations_per_tick_frac
local fracpart = 0
local nextthink = 0
local printed
local function Think()
	local pl = iterating_players[iterid]
	if pl == nil then
		local now = RealTime()
		if nextthink > now then
			--if not printed then
			--	printed = true
			--	--print("=========",nextthink - now)
			--end

			return
		end

		nextthink = now + 1
		--printed = false
		fracpart = fracpart >= 1 and 1 or fracpart
		local plc = refreshplayers(iterating_players)
		if plc == 0 then
			return
		end

		iterid = 1
		iterations_per_tick = #player.GetAllCached() * getinterval()
		iterations_per_tick_frac = iterations_per_tick - math.floor(iterations_per_tick)
		iterations_per_tick = math.floor(iterations_per_tick)
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end
		if fracpart>=0.3 then
			fracpart = 0
			Call(pl)
			iterid = iterid + 1
			pl = iterating_players[iterid]
			if pl == nil then
				return
			end
		end
	end

	fracpart = fracpart + iterations_per_tick_frac
	if fracpart > 1 then
		fracpart = fracpart - 1
		Call(pl)
		iterid = iterid + 1
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end

	end

	for i = 1, iterations_per_tick do
		Call(pl)
		iterid = iterid + 1
		pl = iterating_players[iterid]
		if pl == nil then
			return
		end

	end

end


hook.Add("Think", tag, Think)


-- Fix parent positioning function --

local tag="f_pp"
if SERVER then
	
	util.AddNetworkString(tag)
	
	local Entity=FindMetaTable"Entity"
	function Entity:FixParentPositioning()
		
		local ply = self:GetParent()
		if not ply:IsPlayer() then error"Parent is not a player" end
		
		net.Start(tag)
			net.WriteEntity(self)
		net.Send(ply)
	end
	
	return
	
end
	
local t={}

local added = false

local LocalPlayer=LocalPlayer

local function PreDrawOpaqueRenderables()
	local mypos=LocalPlayer():GetPos()
	local ok
	for _,ent in next,t do
		ok=true
		if not ent:IsValid() then
			t[_]=nil
			continue
		end
		ent:SetRenderAngles(ent:GetNetworkAngles())
		ent:SetRenderOrigin(ent:GetNetworkOrigin()+mypos)
	end
	if not ok then
		added=false
		hook.Remove("PreDrawOpaqueRenderables",tag)
	end
end

net.Receive(tag,function()
	if not added then
		hook.Add("PreDrawOpaqueRenderables",tag,PreDrawOpaqueRenderables)
		added = true
	end
	
	local ent = net.ReadEntity()
	
	if not IsValid(ent) then return end
	
	table.insert(t,ent)
	
end)
