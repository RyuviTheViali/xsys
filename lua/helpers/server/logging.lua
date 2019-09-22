module("xlog",package.seeall)

if file.Read("cfg/nolog.cfg",'GAME') then 
	function Log() end
	function LogMsg() end
	function EntLogStr() end
	function PlayerLogStr() end
	function Log_XsysCommand() end
	return 
end

local Tag = "XLog"
local ACT_NEXT,ACT_PREV,ACT_RESET,ACT_NOP=1,2,3,0
local i = 1
local log_verbose_level = CreateConVar("xlog_verbose_level", 0)
local logFile
local lastday

CreateConVar("log_spawn_enable", 0)
if not file.Exists("sv_logs",'DATA') then file.CreateDir("sv_logs","DATA") end

local openfilelength
local openfile
local function openlogfile()
	openfilelength = file.Size(logFile,'DATA') or 0
	openfile = file.Open(logFile,'ab','DATA')
	if not openfile then openfile = file.Open(logFile,'wb','DATA') end
	local sz = openfile and openfile:Size() or 0
	openfilelength = sz > openfilelength and sz or openfilelength
	
end

local function toobig()
	return openfilelength > 200*1024
end

function nowtime()
	local hour = os.date("%H")
	local APM =" AM"
	if tonumber(hour) > 12 then hour,APM = hour%12," PM" end
	local str = hour..os.date(":%M:%S")..APM
	return str
end

function checkreset()
	local day = os.date("%d")
	if lastday == day and not toobig() then return end
	lastday = day
	if openfile then openfile:Flush() end
	local i = 0
	repeat
		i = i+1
		assert(i < 300,"too many log files, spam?")
		logFile = string.format("sv_logs/%s%.3d.txt",os.date("%Y%m%d"),i)
		openlogfile()
	until(not toobig())
	assert(openfile,"LogFile "..logFile.." could not be opened, this is bad")
	Msg("[Logging] Logging to nr. "..i..": ") print(logFile)
end

function Log(str)
	checkreset()
	local str = "["..nowtime().."] "..str.."\n"
	openfilelength = openfilelength+#str
	openfile:Write(str)
end

Log("Logging start")
function PlayerLogStr(ply)
	local str = ""
	if istable(ply) and ply.all then
		return "#all"
	elseif (ply and ply:IsValid()) then
		if ply:IsPlayer() then
			local address = ply:IPAddress()
			if ply:SteamID() == "BOT" then address = "none" end
			return "["..ply:EntIndex().."]"..(ply.RealNick and ply:RealNick() or ply:Nick()).."["..ply:SteamID().."]"
		elseif IsValid(ply:CPPIGetOwner()) then
			return "["..ply:EntIndex().."]"..ply:GetClass().."[Owner:"..ply:CPPIGetOwner():Nick().."]"
		else
			return "["..ply:EntIndex().."]"..ply:GetClass()
		end
	else
		return "Console"
	end
end

function EntLogStr(model,ent)
	if model and ent then
		return "["..ent:EntIndex().."]["..model.."]"
	elseif ent then
		return "["..ent:EntIndex().."]["..ent:GetClass().."]"
	elseif model then
		return model
	end
end

function LogMsg(addition,ply,ent,model)
	local log,col
	if ply and (ent or model) and not ply:IsBot() then
		if ent and model then
			log = "[XSpawn] "
			col = Color(255,130,255)
		elseif ent then
			log = "[XSpawn:"..tostring(ent).."] "
			col = Color(100,255,255)
		end
	else
		log = "[XLog] "
		col = Color(0,200,255)
	end
	MsgC(col,log)
	MsgC(Color(255,255,255),"["..ply:EntIndex().."]["..ply:Nick():gsub("<(.-)=(.-)>", ""):gsub("%^%d","").."]") print((addition and " "..tostring(addition).."" or ""))
end

hook.Add("PlayerConnect","Log_PlayerConnect",function(name,address)
	local data
	if address ~= "none" then
		address = address:match("(.-):")
		if GeoIP and GeoIP.Get then data = GeoIP.Get(tostring(address)) end
	end
	Log(name.." ["..address.."] connect "..(data and " ("..(data.country_name or "N/A")..")" or "???"))
end)

hook.Add("PlayerSay","Log_PlayerSay",function(ply,txt)
	Log(PlayerLogStr(ply)..": "..txt)
end)

local show_toolmode = {
	fireworks = true,
	adv_duplicator = {nt = 1},
	advdupe2 = true,
	duplicator = {nt = 1}
}

hook.Add("CanTool","Log_ToolHook",function(ply,tr,mode,ent)
	if ply.lasttoolclick and CurTime() - ply.lasttoolclick < 0.3 then return end
	ply.lasttoolclick = CurTime()
	local tool = "[XTool] "..mode
	local nick = " "..PlayerLogStr( ply ).." "
	local target = ""
	if tr.Entity and IsValid(tr.Entity) then
		target = " >> " .. EntLogStr(nil,tr.Entity)
		if IsValid(tr.Entity:CPPIGetOwner()) then
			target = target.." (owner:"..PlayerLogStr(tr.Entity:CPPIGetOwner())..")"
		end
	else
		target = ">> Vector("..tr.HitPos.x..", "..tr.HitPos.y..", "..tr.HitPos.z..")"
	end
	Log(tool..nick..target)
	if not show_toolmode[mode] or (istable(show_toolmode[mode]) and show_toolmode[mode].nt and not(tr.Entity and IsValid(tr.Entity))) then return end
	MsgC(Color(255,0,0),tool)
	print(nick..target)
end)

local target_commands = {
	goto = true,
	bring = true,
	cleanup = true,
	kick = true,
	exit = true,
	back = true,
	rank = true,
	cexec = true,
}

hook.Add("XsysCommand","Log_XsysCommand",function(data,ply,line,...)
	if line and target_commands[data.cmd] then return end
	local args = {...}
	line = line or ""
	Log("[XSYS "..data.cmd.."] "..PlayerLogStr( ply )..(line ~= "" and " ("..line..")" or ""))
end)

hook.Add("XsysMessage","Log_XsysMessage",function(cmd,msg)
	if target_commands[cmd] then return false end
end)

hook.Add("XsysTargetCommand","Log_XsysCommand",function(ply,cmd,target,...)
	local str = ""
	local count = select("#",...)
	for i=1, count do
		str = str..tostring(select(i,...))
		if i ~= count then str = str..", " end
	end
	MsgC(Color(0,255,255),"[XSYS] "..cmd.." ")
	print(PlayerLogStr( ply ) .." >> "..PlayerLogStr( target )..(str ~= "" and " ("..str..")" or ""))
	Log("[XSYS "..cmd.."] "..PlayerLogStr(ply) .." >> "..PlayerLogStr(target)..(str ~= "" and " ("..str..")" or ""))
end)

hook.Add("PlayerDeath","Log_PlayerDeath",function(ply,inf,killer)
	if ply ~= killer then Log(PlayerLogStr(ply).." was killed by "..PlayerLogStr(killer)..".") end
end)

hook.Add("InitPostEntity","Log_InitPostEntity",function()
	Log("== Map : '"..game.GetMap().."' Gamemode : '"..GAMEMODE.Name.."' ==" )
end)

hook.Add("PlayerDisconnected","Log_PlayerDisconnected",function(ply)
	Log(PlayerLogStr(ply).." disconnect")
	if log_verbose_level:GetInt() > 0 then LogMsg("Disconnect.",ply,ent,model) end
end)

hook.Add("PlayerInitialSpawn","Log_PlayerInitialSpawn",function(ply)
	Log(PlayerLogStr(ply).." connect finish")
	if log_verbose_level:GetInt() > 0 then LogMsg("Spawn",ply) end
end)
 
hook.Add("PlayerSpawnedProp","Log_SpawnHook",function(ply,model,ent)
	Log(PlayerLogStr(ply).." spawned prop "..EntLogStr(model,ent))
	if not GetConVar("log_spawn_enable"):GetBool() then return end
	LogMsg(EntLogStr(model,ent),ply,ent,model)
end)

hook.Add("PlayerSpawnedSENT","Log_SpawnHook",function(ply,ent)
	local class = IsValid(ent) and ent:GetClass() or tostring(ent)
	Log(PlayerLogStr(ply).." spawned scripted entity "..EntLogStr(class,ent))
	LogMsg(EntLogStr(class,ent),ply,"Entity",class)
end)
 
hook.Add("PlayerSpawnedNPC","Log_SpawnHook",function(ply,ent)
	Log(PlayerLogStr(ply).." spawned npc "..EntLogStr(model,ent))
	LogMsg(EntLogStr(model,ent),ply,"NPC",model)
end)
 
hook.Add("PlayerSpawnedVehicle","Log_SpawnHook",function(ply,ent)
	Log(PlayerLogStr(ply).." spawned vehicle "..EntLogStr(model,ent))
	LogMsg(EntLogStr(model,ent),ply,"Vehicle",model)
end)
 
hook.Add("PlayerSpawnedEffect","Log_SpawnHook",function(ply,model,ent)
	Log(PlayerLogStr(ply).." spawned effect "..EntLogStr(model,ent))
	LogMsg(EntLogStr(model,ent),ply,ent,model)
end)
 
hook.Add("PlayerSpawnedRagdoll","Log_SpawnHook",function(ply,model,ent)
	Log(PlayerLogStr(ply).." spawned ragdoll "..EntLogStr(model,ent))
	LogMsg(EntLogStr(model,ent),ply,ent,model)
end)

local crashes,inited
function init()
	local files = file.Find("data/sv_logs/*.txt","GAME")
	if inited == #files then return end
	inited,crashes = #files,files
	table.sort(crashes,function(a,b)
		local aa = tonumber((a:gsub(".txt","")))
		local bb = tonumber((b:gsub(".txt","")))
		return aa < bb
	end)
end

util.AddNetworkString(Tag)
net.Receive(Tag,function(len,pl)
	init()
	if openfile then openfile:Flush() end
	local which,re,rs,act = net.ReadUInt(5),net.ReadEntity(),net.ReadString(),pl.__crashact or #crashes
	if which == ACT_RESET then
		act = #crashes
	elseif which == ACT_NEXT then
		act = act+1
		if re == pl then
			for i=1,50 do
				if (not crashes[act] or string.lower(file.Read("data/sv_logs/"..crashes[act],"GAME")):find(string.lower(rs))) then break end
				act = act+1
			end
		end
		if not crashes[act] then return end
	elseif which == ACT_PREV then
		act = act-1
		if re == pl then
			for i=1,50 do
				if (not crashes[act] or string.lower(file.Read("data/sv_logs/"..crashes[act],"GAME")):find(string.lower(rs))) then break end
				act = act-1
			end
		end
		if not crashes[act] then return end
	end
	pl.__crashact = act
	local filename = crashes[act]
	local date = tonumber((filename:gsub(".txt","")))-20000000000
	local data = file.Read("data/sv_logs/"..filename,"GAME")
	if re == pl then
		local find,temp = rs,data
		data = {}
		for _, line in pairs(temp:Split("\n")) do
			if string.lower(line):find(string.lower(find)) then
				table.insert(data,line)
			end
		end
		table.insert(data,(table.Count(data).." hits"))
		data = table.concat(data,"\n")
	end
	net.Start(Tag)
		net.WriteUInt(date,32)
		net.WriteString(data)
	net.Send(pl)
end)

if xsys and xsys.AddCommand then
	xsys.AddCommand({"log","logview"},function(ply,line)
		ply:ConCommand("logview")
	end,"developers")
else
	hook.Add("XsysInitialized","logcmd",function()
		xsys.AddCommand({"log","logview"},function(ply,line)
			ply:ConCommand("logview")
		end,"developers")
		hook.Remove("XsysInitialized","logcmd")
	end)
end