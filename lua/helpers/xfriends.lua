local Tag = "xfriends"
module(Tag,package.seeall)

function XMsg(...)
	--Msg("[Friendsh"..(SERVER and "_sv" or "_cl").."] ") print(...)
end

function topl(id)
	id=tonumber(id)
	for k,v in pairs(player.GetAll()) do
		if v:UserID()==id then return v end
	end
end

local LocalID
function myuid()
	return SERVER and 0 or LocalID or IsValid(LocalPlayer()) and LocalPlayer():UserID() or false
end
function id(ply)
	if not ply then error("invalid input") end
	return tonumber(ply) or IsValid(ply) and ply:UserID()
end

local isfriend = {
	none = false,
	blocked = false,
	friend = true,
	requested = true,
	requestrecipient = false,
	error_nofriendid = false,
	[true] = true,
	[false] = false,
	[1] = true,
	["1"] = true,
	[0] = false,
	["0"] = false,
}

Friends = _M.Friends or {}
local Friends = Friends

function SetFriendState(pid,userid,state)
	XMsg("SetFriendState",topl(pid) or pid or "EEK",topl(userid) or userid or "EEK",state)
	assert(CLIENT or pid ~= nil)
	pid = pid or myuid()
	Friends[pid] = Friends[pid] or {}
	local ftbl = Friends[pid]
		local prev = ftbl[userid]
		local changed = not prev or prev ~= state
	local tbl = Friends[pid]
		tbl[userid] = state
	return changed
end

function GetFriendStatus(pid,userid)
	if not Friends[pid] then return 0 end
	return Friends[pid][userid] or 0
end

function EnumData(func)
	for k,v in pairs(Friends) do
		for userid,state in pairs(v) do
			func(k,userid,state)
		end
	end
end

local pm = FindMetaTable("Player")
function IsFriend(pid,friend)
	if not friend then
		friend = pid
		pid = myuid()
	end
	return isfriend[GetFriendStatus(pid,friend)]
end

pm.IsFriend = function(pl,pl2) return IsFriend(id(pl),id(pl2)) end

function AreFriends(userid1,userid2)
	if not userid2 then
		userid2 = userid1
		userid1 = myuid()
	end
	return isfriend[GetFriendStatus(userid1,userid2)] and isfriend[GetFriendStatus(userid2,userid1)]
end

pm.AreFriends = function(pl,pl2) return AreFriends(id(pl),id(pl2)) end

function PartialFriends(userid1,userid2)
	if not userid2 then
		userid2 = userid1
		userid1 = myuid()
	end
	return isfriend[GetFriendStatus(userid1,userid2)] and isfriend[GetFriendStatus(userid2,userid1)]
end

pm.PartialFriends = function(pl,pl2) return PartialFriends(id(pl),id(pl2)) end

function BroadcastFriendStatus(id,state,pid,towho)
	XMsg("BroadcastFriendStatus",topl(pid) or pid or "EEK",topl(id) or id or "EEK",state,towho)
	state = tonumber(state)
	id = tonumber(id)
	assert(state ~= nil)
	assert(id ~= nil)
	if SERVER and not pid then
	    XMsg("ERR",id,state,pid)
	    assert(CLIENT)
	end
	if CLIENT then
		assert(not towho)
		RunConsoleCommand("cmd",Tag,tostring(id),tostring(state))
	else
		umsg.Start(Tag,towho)
			umsg.Short(pid)
			umsg.Short(id)
			umsg.Short(state)
		umsg.End()
	end
end

function ReceiveFriendData(pl,uid,state)
	local pid = id(pl)
	XMsg("ReceiveFriendData",topl(pid) or pid or "EEK",topl(uid) or uid or "EEK",state)
	local last = GetFriendStatus(pid,uid)
	if last ~= state then
		SetFriendState(pid,uid,isfriend[state] and 1 or 0)
	end
	if SERVER then
		BroadcastFriendStatus(uid,state,pid)
	end
end

if CLIENT then
	tmpfriends = _M.tmpfriends or {} local tmpfriends=tmpfriends
	local loaded = false
	function GetFriendStatusOverride(steamid)
		if luadata and not loaded then
			tmpfriends = luadata.ReadFile("friends_override.txt")
			loaded = true
		end
		return tmpfriends[steamid]
	end
	function SetFriendStatusOverride(steamid,state)
		if luadata and not loaded then
			tmpfriends = luadata.ReadFile("friends_override.txt")
			loaded = true
		end
		if state ~= true and state ~= false and state ~= nil then error("invalid state") end
		tmpfriends[steamid] = state
		if luadata then
			luadata.WriteFile("friends_override.txt",tmpfriends)
		end
	end
end

function CheckPlayer(ply)
	if CLIENT then
		local friendid = id(ply)
		local status = friendid and GetFriendStatusOverride(ply:SteamID())
		if status == nil then
			status = isfriend[ply:GetFriendStatus()]
		end
		if (status or false) ~= (IsFriend(friendid) or false) then
			SetFriendState(myuid(),friendid,status and 1 or 0)
			BroadcastFriendStatus(friendid,status and 1 or 0)
		end
	else
	end
end

if CLIENT then

	usermessage.Hook(Tag,function(umsg)
		local pid = umsg:ReadShort()
		local userid = umsg:ReadShort()
		local state = umsg:ReadShort()
		ReceiveFriendData(pid,userid,state)
	end)

	timer.Simple(2,function()
		local i = 0
		local pls = {}
		timer.Create(Tag,0.3,0,function()
			i = i+1
			local ply = pls[i]
			if not ply then
				pls=player.GetHumans()
				i = 1
				ply = pls[i]
				if not ply then return end
			end
			if ply:IsValid() and ply:IsPlayer() then
				CheckPlayer(ply)
			end
		end)
	end)
	timer.Simple(8,function()
		RunConsoleCommand("cmd","_syncfriends")
	end)
else
	concommand.Add(Tag,function(pl,_,tbl)
		local userid,state=tbl[1],tbl[2]
		state = state and tonumber(state)
		userid = userid and tonumber(userid)
		if not state or not userid then
		    XMsg(pl,"sent concmd bogus data",tbl[1],tbl[2])
		end
		ReceiveFriendData(pl,userid,state)
	end)
	
	concommand.Add("_syncfriends",function(towho)
		local x = 0
		EnumData(function(pid,userid,state)
			timer.Simple(x,function()
				if IsValid(towho) then
					BroadcastFriendStatus(userid,state,pid,towho)
				end
			end)
			x = x+0.01
		end)
	end)
end
local f = function(ply)
	if ply:IsPlayer() then
		if not ply:IsValid() then
			Msg("[XFriends] ")
			print("Not valid player",ply)
			return
		end
		if not LocalID and LocalPlayer and ply == LocalPlayer() then
			LocalID = LocalPlayer():UserID()
		end
		CheckPlayer(ply)
	end
end
local function init()
	hook.Add("OnEntityCreated",Tag,f)
	if CLIENT then
		hook.Add("NetworkEntityCreated",Tag,f)
	end
end

if SERVER then
	timer.Simple(0,init)
else
	init()
end
