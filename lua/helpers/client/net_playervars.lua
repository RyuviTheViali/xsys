local PLAYER = FindMetaTable("Player")
local Tag = "NetData"
local data_table = {}

local net_playervar_debug = CreateConVar("net_playervar_debug","0")

local function Set(id,key,value)
	local tt = data_table[id]

	if not tt then
		tt = {}
		data_table[id] = tt
	end

	tt[key] = value

	if net_playervar_debug:GetBool() then
		Msg("[PNVar] ")
		print("Set",id,key,value)
	end
end

local function Get(id,key)
	local tt = data_table[id]

	return tt and tt[key]
end

net.Receive(Tag,function(len)
	local id    = net.ReadUInt(16)
	local key   = net.ReadString()
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

local lookup = {}
function PLAYER:GetNetData(key)
	local id = lookup[self]

	if id == nil then
		id = self:UserID()
		lookup[self] = id
	end

	local tt = data_table[id]

	return tt and tt[key]
end

xsys = xsys or {}

xsys.NET_PLAYERVARS_INITIALIZED = true