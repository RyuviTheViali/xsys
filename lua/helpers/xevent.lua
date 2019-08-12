local Tag = "xevent"
local Player = FindMetaTable("Player")
local xevent = gameevent
local util = util
local Now = RealTime
xevent.EngineNick = xevent.EngineNick or Player.Nick
Player.EngineNick = Player.EngineNick or Player.Nick

if CLIENT then
	local steamnicks = setmetatable({},{__mode="k"})
	function Player:SteamNick()
		local nick = steamnicks[self]
		if nick ~= nil and nick ~= false then return nick end
		local sid64 = self:SteamID64()
		local islooking = nick==false
		nick = steamworks.GetPlayerName(sid64)
		if nick == "" then
			nick = false
			if not islooking then steamworks.RequestPlayerInfo(sid64) end
		end
		steamnicks[self] = nick
		return nick ~= true and nick
	end
end

local gamee_events={
	"player_connect",
	"player_info",
	"player_spawn",
	"player_disconnect",
	"player_activate"
}

local function xeventIncoming(name,...)
	error("Um.")
end

local event_num = {}
for k,v in next,gamee_events do 
	event_num[v] = k
	xevent.Listen(v)
	xevent[v] = k
	hook.Add(v,Tag,function(dat) xeventIncoming(v,dat) end)
end

local relaytbl = {}
local lastip
if SERVER then
	local kickhim = false
	hook.Add("CheckPassword",Tag,function(sid64,ip,_,_,name) lastip = ip end)
	hook.Add("OnEntityCreated",Tag,function(pl) 
		if pl:IsPlayer() then
			relaytbl.entity = pl
			relaytbl.userid = pl:UserID()
			xeventIncoming("player_appear",relaytbl)
		end
	end)
else
	local lastappear
	hook.Add("OnEntityCreated",Tag,function(pl) 
		if pl:IsPlayer() then
			if pl ~= LocalPlayer() then return end
			hook.Remove("OnEntityCreated",Tag)
			lastappear = pl
			relaytbl.entity = pl
			relaytbl.userid = pl:UserID()
			xeventIncoming("player_appear",relaytbl)
		end
	end)
	hook.Add("NetworkEntityCreated",Tag,function(pl) 
		if pl:IsPlayer() then
			if pl == lastappear then 
				Msg("[GAME-EVENT] (Net Entity Created) Not player_appearing ")
				print(lastappear)
				lastappear = false
				return 
			end
			relaytbl.entity,relaytbl.userid = pl,pl:UserID()
			xeventIncoming("player_appear",relaytbl)
		end
	end)
end

hook.Add("EntityRemoved",Tag,function(pl) 
	if pl:IsPlayer() then
		relaytbl.entity,relaytbl.userid = pl,pl:UserID()
		xeventIncoming("player_lost",relaytbl)
	end
end)

local relaytbl = {}
local function SteamNickChange(pl,prev,nick)
	relaytbl.entity,relaytbl.userid = pl,pl:UserID()
	relaytbl.oldname,relaytbl.newname = prev,nick
	xeventIncoming("player_changename",relaytbl)
	hook.Run("NameChange",pl,prev,nick)
end

local prevnicks = setmetatable({},{__mode="k"})
hook.Add("PlayerSlowThink",Tag,function(pl) 
	local nick,prev = xevent.EngineNick(pl),prevnicks[pl]
	if prev ~= nick then
		prevnicks[pl] = nick
		if prev == nil then return end
		SteamNickChange(pl,prev,nick)
	end
end)

local userid_to_data = xevent.eventcache or {}
xevent.eventcache = userid_to_data
local entity_to_data = xevent.eventcache_ent or setmetatable({},{__mode="k"})

xevent.eventcache_ent = entity_to_data
function xevent.GetTable()
	return userid_to_data,entity_to_data
end

local function GetCache(T)
	if T == nil then return userid_to_data,entity_to_data end
	return entity_to_data[T] or userid_to_data[T]
end

xevent.GetCache = GetCache
local function GetCacheEnt(ent)
	return entity_to_data[ent]
end

xevent.GetCacheEnt = GetCacheEnt
Player.EventCache = GetCacheEnt
local function GetCacheID(userid)
	return userid_to_data[userid]
end

xevent.GetCacheID = GetCacheID
local function GetName(ply)
	local t = entity_to_data[ply]
	return t and t.name or xevent.EngineNick(ply)
end

Player.GetName = GetName
Player.GetNick = GetName
Player.Nick = GetName
Player.Name = GetName
Player.RealNick = Player.EngineNick
Player.RealName = Player.EngineNick
Player.GetRealName = Player.EngineNick

local dataclone = {}
local function CleanupData(id,info,cached)
	if id == "player_connect" then
		local ip = lastip
		if ip ~= nil and info.address then 
			lastip = nil
			info.address = ip
		end
	end
	local name = info.name
	if CLIENT and name ~= nil and (name == "unconnected" or name == "" or name == "Unconnected") then
		if info.name_overriden ~= true then
			name = cached and (cached.name or cached._name) or name
			info.name = name
		end
	end
	if info.index then info.entindex = info.index+1 end
	return info
end

local s32to64 = util.SteamID64 or util.SteamIDTo64
local function AddFriendsID(cached)
	local networkid = cached and cached.networkid
	local friendsid = cached.friendsid
	if (friendsid == nil or friendsid == 0 or friendsid == "0") and cached.networkid and isstring(cached.networkid) and cached.networkid:find("STEAM_") then
		cached.friendsid = util.AccountIDFromSteamID(cached.networkid)
	end
	if cached.steamid64 == nil and cached.networkid and isstring(cached.networkid) and cached.networkid:find("STEAM_") then
		cached.steamid64 = s32to64(cached.networkid)
	end
end

local changecache = {}
local function MergeData(cached,info)
	local dirty
	for k,now in next,info do
		local prev = cached[k]
		local first = prev == nil
		if k=="name" then
			local setoverride = info.name_overriden
			local changeoverride = setoverride ~= nil
			local is_overriden = cached.name_overriden
			if changeoverride then
				if setoverride then
					if is_overriden then
					else
						cached._name = cached.name
					end	
				else 
					if is_overriden then
						now = cached._name
					else
						if now ~= (prev or now) then
							MsgN("[NameOverride] Uh " )
							print(now,prev)
						end
						now = prev or now
					end			
				end
			else
				if is_overriden then
					k = "_name"
				else
					cached._name = now
				end
			end
		elseif k == "networkid" and now == "NULL" and cached.networkid ~= nil and cached.networkid ~= "NULL" then
			Msg("[GAME-EVENT] Prevented networkid mangling: ")
			print(cached.networkid,">>",now)
			continue
		end
		if prev ~= now then
			if dirty == nil then
				for k,v in next,changecache do changecache[k] = false end
				dirty = true
			end
			if prev == nil then
				changecache[k] = true
			else 
				changecache[k] = prev
			end
		end
		cached[k] = now
	end
	local ret = dirty and changecache
	if ret and ret.networkid then AddFriendsID(cached) end
	return ret
end

local function DoStateTransition(id,cached,prevdatas)
	local oldid = cached.statename
	if oldid == id or oldid == "player_disconnect" then return end
	if id ~= "player_info" and id ~= "player_activate" and id ~= "player_connect" and id ~= "player_disconnect" then return end	
	cached.statetime,cached.statename,cached.state = Now(),id,event_num[id]
	return id
end

local META = {}
function META:GetEntity()
	local e = self.entity
	return e and e[1]
end

local infometa={}
infometa.__index = META
local function FindSmallBig(id)
	local smal = xevent.smallest_id or math.huge
	local bigg = xevent.biggest_id or 0
	if id < smal then xevent.smallest_id = id end
	if id > bigg then xevent.biggest_id = id end
end

for userid,_ in next,xevent.eventcache do FindSmallBig(userid) end

local function MakeCache(userid)
	local t = {name = nil}
	FindSmallBig(userid)
	setmetatable(t,infometa)
	userid_to_data[userid] = t
	return t
end

local LOST_ENTITY = {entity_valid=false,Entity=false}
local player_changename_cachetbl,player_changenamefake_cachetbl,player_appear_cachetbl,player_appear_cachetbl2,player_spawn_cache = {},{},{},{},{}
local player_activate_cache = {connecting=false}
function xeventIncoming(id,info)
	local userid = info.userid
	if not userid then
		ErrorNoHalt("[GAME-EVENT] No UserID "..tostring(id)..'\n')
		return
	elseif userid < 0 then
		local ent = info.entity
		local cache = ent and entity_to_data[info.entity]
		userid = cache and cache.userid
		if not userid or userid<0 then
			ErrorNoHalt("[GAME-EVENT] UserID negative, no data?? "..tostring(id)..'\n')
			return
		end
	end
	local cached = userid_to_data[userid]
	local prevent_name_change
	if id == "player_disconnect" then
		info.disconnected = true
	elseif id == "player_activate" then
		info = player_activate_cache
	elseif id == "player_changename" then
		local name_overriden = info.name_overriden
		local fake = name_overriden ~= nil
		local newname = info.newname
		if fake then
			info = player_changenamefake_cachetbl
			info.name_overriden = name_overriden
			info.name = newname
		else
			info = player_changename_cachetbl
			info.name = newname
		end
	elseif id == "player_appear" then
		local p = info.entity
		assert(p:IsValid(),"Invalid player?")
		info = player_appear_cachetbl
		info.index			= p:EntIndex()-1
		info.userid			= userid
		info.networkid		= p:SteamID()
		info.bot			= p:IsBot() and 1 or 0
		info.entity 		= cached and cached.entity or setmetatable({p},{__mode="v"})
		info.entity_valid   = true
		info.name			= xevent.EngineNick(p)
		info.connecting     = false
		info.Entity         = p
		info.teamid         = false
	elseif id == 'player_lost' then
		local p = info.entity
		info = LOST_ENTITY
		local teamid = p:IsValid() and p:Team()
		if teamid then
			info.teamid	= teamid
		else
			info.teamid = nil
		end
	elseif id == "player_spawn" then
		info = player_spawn_cache
		info.last_spawn = Now()
	end
	local pl = info.Entity
	info = CleanupData(id,info,cached)
	if cached == nil then cached = MakeCache(userid)
	end
	if pl and entity_to_data[pl] == nil then entity_to_data[pl] = cached end
	local prevdatas = MergeData(cached,info) 
	local changedto = DoStateTransition(id,cached,prevdatas)
	hook.Run("player_info_changed",userid,cached,prevdatas,changedto)
end

local Tag2="NameOverride"
local data = {}
local _playernick_enabled_ = true
xevent.player_changename=function(userid,name,force)
	if force ~= true and not _playernick_enabled_ then return end
	data.userid = userid
	local cache = GetCache(userid)
	data.name_overriden = not not name
	if name then
		name = tostring(name)
		data.newname = name
		data.oldname = cache and cache.name or "unconnected"
	else
		data.newname = cache and (cache._name or cache.name) or "unconnected"
		data.oldname = cache and cache.name or "unconnected"
	end
	xeventIncoming("player_changename",data)
	hook.Run("player_changename",data)
end
if SERVER then
	function Player.SetNick(pl,name)
		local userid = pl:UserID()
		if not name then name = nil end
		pl:SetNetData(Tag2,name)
		return xevent.player_changename(userid,name)
	end
end

local NickOverride
if CLIENT then
	local _playernick_enabled = CreateClientConVar("_playernick_enabled","1",true,false)
	_playernick_enabled_ = _playernick_enabled:GetBool()
	local function func(pl,func,args,paramstr)
		_playernick_enabled_ = func == "playernick_enable" and paramstr ~= "0"
		RunConsoleCommand("_playernick_enabled",_playernick_enabled_ and "1" or "0")
		if _playernick_enabled_ then
			MsgN("Enabling all player nicks...")
			for k,v in next,player.GetAll() do
				local userid = v:UserID()
				local n = v:GetNetData(Tag2)
				if n then xevent.player_changename(userid,tostring(n),true) end
			end
		else
			MsgN("Disabling all player nicks...")
			for k,v in next,player.GetAll() do
				local userid = v:UserID()
				xevent.player_changename(userid,false,true)
			end
		end
	end
	concommand.Add("playernick_enable",func)
	concommand.Add("playernick_disable",func)
	NickOverride = function(userid,name)
		if not _playernick_enabled_ then return end
		xevent.player_changename(userid,name)
	end
	
end

xevent.PlayerWantChangeNick = function(pl,name) 
	if not name then name = nil end
	xevent.player_changename(pl:UserID(),name) 
	return true
end

hook.Add("NetData",Tag2,function(pl,k,name)
	if k == Tag2 then
		if SERVER then
			if name ~= nil and not isstring(name) then return end
			return xevent.PlayerWantChangeNick(pl,name)
		end
		NickOverride(pl,name)
	end
end)

if CLIENT then
	local SVGUID="xsystem"
	local key = Tag2.."_"..SVGUID
	
	local function Get()
		return util.GetPData("",key)
	end
	
	local function Set(val)
		if not val or val == "" then
			util.RemovePData("",key)
			return Get()
		end
		val = tostring(val)
		util.SetPData("",key,val)
		return Get()
	end
	
	local function SetNick(nick,nostore)
		if nostore ~= true then nick = Set(nick) end
		if not nick then nick = nil end
		return LocalPlayer():SetNetData(Tag2,nick)
	end
	
	local GetStoredNick = Get
	concommand.Add("setnick",function(_,_,_,nick)
		if not nick or nick == "" or nick == '""' or nick == " " then
			nick=  nil
			MsgN("Unsetting custom nick...")
		else
			Msg("Trying to change nick to ")
			print("'"..nick.."'")
		end
		SetNick(nick)
	end,nil,"override your steam nick")

	function Player.SetNick(pl,nick)
		assert(pl==LocalPlayer(),"not LocalPlayer()...")
		if not nick then nick = nil end
		SetNick(nick)
	end

	hook.Add("ChatCommand","nickname",function(com,nick)
		com = com:lower()
		if com == 'nick' or com == 'name' or com == 'rpname' then
			LocalPlayer():SetNick(nick)
			return true
		end
	end)

	local mynick = GetStoredNick()
	if mynick then
		hook.Add("NetworkEntityCreated",Tag2,function(e)
			if e~=LocalPlayer() then return end
			hook.Remove("NetworkEntityCreated",Tag2)
			Msg("[XName] Setting nick to ")
			print("'"..mynick.."'")
			SetNick(mynick,true)
		end)
	end
end

hook.Add("player_info_changed",Tag,function(uid,data,datachanged,t)
	local old = datachanged and datachanged.name
	if not old or old==true then return end
	local new = data.name
	local pl = data:GetEntity()
	if pl then
		Msg("[XName] ")
		print(tostring(pl).." ("..old..") changed name to "..new)
	else
		if not new then
			ErrorNoHalt("Namechange and no new nick "..tostring(old).." "..uid.." - "..(tostring(data and data.userid)).."??\n")
		end
		Msg("[XName] ")
		print("Player '"..old.."' (UserID "..tostring(uid or "?!!?")..") changed name to '"..tostring(new).."'")
	end
	if SERVER then return end
	local col = team.GetColor(IsValid(pl) and pl:Team() or -1)
	local func = SERVER and MsgC or chat.AddText
	func(col,old,color_white," is now called ",col,new,color_white,SERVER and "\n" or ".")
end)

hook.Remove("player_info_changed",Tag..'2',function(uid,data,datachanged,t)
	if SERVER then return end
	MsgN("== EVENT: Uid="..tostring(uid).." type=",t or "noevent"," ==")
	MsgN("Changed data: ")
	for k,v in next,datachanged or {empty=true} do
		if v then Msg(('    %15s'):format(tostring(k))," ")print(v==true and "<NEW>" or v,">>",data[k],type(data[k])=="number" and "(num)" or "") end
	end
	MsgN("================================================")
	MsgN("")
end)

local c_disc = Color(255,100,100,255)
local c_norm = Color(255,255,255,255)
local function concmd(pl,listwhat,_,paramstr)
	if SERVER and pl and pl:IsValid() and not pl:IsSuperAdmin() then return end
	local ec = xevent.eventcache
	MsgN("Listing xevent cache...")
	for i=xevent.smallest_id,xevent.biggest_id do
		local t = ec[i]
		if t ~= nil then
			if listwhat == "xevent_listconnected" and t.disconnected then continue end
			local c = t.disconnected == true and c_disc or c_norm
			MsgC(c,("%4d %-30s %-30s %-30s %-30s %-30s\n"):format(t.userid,t.networkid or "No ID",t.statename  or "NO STATE?",string.NiceTime(Now()-(t.statetime or Now())),t.name,t.name == t._name and "" or ('('..t._name..')')))
		end
	end
end
concommand.Add("xevent_listall",concmd)
concommand.Add("xevent_listconnected",concmd)