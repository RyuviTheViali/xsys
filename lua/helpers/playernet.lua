local PLAYER=FindMetaTable("Player")
local Tag = "NetData"
local data_table = ({})

local function Set(id,key,value)
	local tt=data_table[id]
	if not tt then
		tt={}
		data_table[id]=tt
	end
	tt[key]=value
end
local function Get(id,key)
	local tt = data_table[id]
	return tt and tt[key]
end

local lookup={}	
if SERVER then
	util.AddNetworkString(Tag)

	local function ReplicateData(id,key,value,targets)
		local queuefunc = function(pl) 
			net.Start(Tag)
				net.WriteUInt(id,16)
				net.WriteString(key)
				net.WriteType(value)
			net.Send(pl)
		end
		for k,v in pairs(targets and (istable(targets) and targets or {targets}) or player.GetHumans()) do
			net.queue(v,queuefunc)
		end
	end

	hook.Add("PlayerInitialSpawn",Tag,function(pl) 
		local valid={}
		for k,v in pairs(player.GetAll()) do valid[v:UserID()]=true end
		for id,data_table in pairs(data_table) do
			if valid[id] then
				for key,value in pairs(data_table) do
					ReplicateData(id,key,value,pl)
				end
			end
		end
	end)

	function PLAYER:SetNetData(key,value)
		local id = lookup[self]
		if not id then
			id = self:UserID()
			lookup[self]=id
		end
		local lastval = Get(id,key)
		Set(id,key,value)
		if lastval ~= value then ReplicateData(id,key,value) end
	end
	
	net.Receive(Tag,function(len,self)
		local id = self:UserID()		
		local key = net.ReadString()
		local _type = net.ReadUInt(8)
		local value = net.ReadType(_type)
		if hook.Call(Tag,nil,self,key,value) == true then
			self:SetNetData(key,value)
		end
	end)
	
else
	net.Receive(Tag,function(len)
		local id = net.ReadUInt(16)
		local key = net.ReadString()
		local _type = net.ReadUInt(8)
		local value = net.ReadType(_type)
		Set(id,key,value)
		hook.Call(Tag,nil,id,key,value)
	end)

	function PLAYER:SetNetData(key,value)
		if self ~= LocalPlayer() then error("not implemented") end
		net.Start(Tag)
			net.WriteString(key)
			net.WriteType(value)
		net.SendToServer()
	end
	
end

local lookup={}
function PLAYER:GetNetData(key)
	local id = lookup[self]
	if not id then
		id = self:UserID()
		lookup[self]=id
	end
	return Get(id,key)
end