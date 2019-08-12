local plys=player.GetAll
local t={}
local i=0
local function nextply()
    i=i+1
    local pl=t[i]
    if not pl then
		i=0
		t=player.GetAll()
		if #t==0 then return end -- empty server
		return nextply()
	end
    if not IsValid(pl) then
		i=i+1
		return nextply()
	end
    return pl
end
local Tag = "namechanged"
local t,sid,uid,eid,reid,sid2uid = {},{},{},{},{},{}

_G[Tag] = _G[Tag] or {}
_G[Tag].nid,_G[Tag].sid,_G[Tag].uid,_G[Tag].eid,_G[Tag].reid,_G[Tag].sid2uid = t,sid,uid,eid,reid,sid2uid

local function syncpl(pl)
	if pl:IsValid() and pl.IsPlayer and pl:IsPlayer() then
		local usrid = pl:UserID()
		if usrid < 0 then return end
		t[usrid]=pl:Name()
		local plsid = pl:SteamID()
		sid[usrid] = plsid
		sid2uid[plsid] = usrid
		uid[usrid] = pl:UniqueID()
		reid[usrid] = pl
		eid[pl] = usrid
	end
end

local function init()
	hook.Add("Think",Tag,function()
		local pl=nextply()
		if not pl then return end
		if not eid[pl] then syncpl(pl) end
		local name=pl:EngineNick()
		local id=pl:UserID()
		if id < 0 then return end
		local val = t[id]
		if val ~= name then
			if not val then t[id] = name return end
			local oldname = val
			t[id] = name
			if oldname == "unconnected" or name == "" or name == "unconnected" then return end
			hook.Call("NameChange",GAMEMODE,pl,oldname,name)
		end
	end)
	hook.Add("OnEntityCreated",Tag,syncpl)
	hook.Add("EntityRemoved",Tag,syncpl)
end

if SERVER then
	timer.Simple(0.1,init)
else
	init()
end

function player.UserIDToName(id)
    return t[id]
end
function player.UserIDToSteamID(id)
    return sid[id]
end
function player.UserIDToUniqueID(id)
    return uid[id]
end
function player.UserIDToEntity(id)
    return reid[id]
end

function player.ToUserID(ent)
    return eid[ent]
end

function player.SteamIDToUserID(sid)
    return sid2uid[sid]
end

if CLIENT then return end

hook.Add("NameChange",Tag,function(pl,old,new)
	if SERVER then
	   Msg("[Nick] ")
	   print(old.." changed their name to "..new)
	   return
	end
	if pl.GetRestricted and pl:GetRestricted() then return end
	local col = team.GetColor(IsValid(pl) and pl:Team() or -1)
	chat.AddText(col,old,color_white," changed their name to ",col,new,color_white,".")
	
end)
