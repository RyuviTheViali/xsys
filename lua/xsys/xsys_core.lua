if not easylua then error("[XSYS] Unable to initialize without Easylua") end

xsys = xsys or {}

xsys.StringPatterns = {
	Prefix    = "[!|/|%.|;]",
	String    = "[\"|']",
	Separator = "[,]",
	Escape    = "[\\]"
}

team.SetUp(1,"default",Color(128,128,128))

xsys.Notify = function(msg,txt)
	local ok = hook.Run("XsysNotification",msg,txt)
	if ok == false then return end
	local nmsg = msg and tostring(msg) or ""
	MsgC(Color(55,205,255),"[XSYS] "..nmsg.." ")
	MsgN(txt)
end

xsys.Compare = function(a,b)
	if a == b or a:find(b,nil,true) or (a:lower() == b:lower()) or a:lower():find(b:lower(),nil,true) then
		return true
	end
	return false
end

xsys.Data = xsys.Data or {}
xsys.Data.Locations = xsys.Data.Locations or {}

do
	--todo: default goto locations
end

xsys.ParseString = function(s)
	local tab,found,str,c,esc = {},false,"","",false
	for i=1,#s do
		local cc = s[i]
		if esc then
			c,esc = c..cc,false
			continue
		end
		if cc:find(xsys.StringPatterns.String) and not found and not esc then
			found,str = true,cc
		elseif cc:find(xsys.StringPatterns.Escape) then
			esc = true
			continue
		elseif found and cc == str then
			table.insert(tab,c:Trim())
			c,found = "",false
		elseif cc:find(xsys.StringPatterns.Separator) and not found then
			if c ~= ""  then
			    table.insert(tab,c)
			    c = ""
			end
		else
			c = c..cc
		end
	end
	if c:Trim():len() ~= 0 then table.insert(tab,c) end
	return tab
end

xsys.SteamIDToCID = function(sid)
	if ({["BOT"]=true,["NULL"]=true,["STEAM_ID_PENDING"]=true,["UNKNOWN"]=true})[sid] then
		return 0
	end
	local seg = sid:Split(":")
	local a,b = seg[2],seg[3]
	return tostring("7656119"..7960265728+a+(b*2))
end

xsys.CIDToSteamID = function(cid)
	if cid:sub(1,11) ~= "76561197960" then return "UNKNOWN" end
	local c,a = tonumber(id),id%2 == 0 and 0 or 1
	local b = (c-76561197960265728-a)/2
	return "STEAM_0:"..a..":"..(b+2)
end

xsys.GetAvatar = function(sid)
	local c = xsys.SteamIDToCID(sid)
	http.Get("http://steamcommunity.com/profiles/"..c.."?xml=1","",function(content,size)
		local ret = content:match("<avatarIcon><!%[CDATA%[(.-)%]%]></avatarIcon>")
		callback(ret)
	end)
end

xsys.NotificationTypes = {
	["GENERIC"] = 0,
	["ERROR"]   = 0,
	["UNDO"]    = 0,
	["HINT"]    = 0,
	["CLEANUP"] = 0
}

xsys.Message = function(ply,msg,typ,dur)
	ply,dur = ply or all,dur or 5
	ply:SendLua(string.format("local s=%q notification.AddLegacy(s,%u,%s)MsgN(s)","XSYS: "..msg,xsys.NotificationTypes[(typ and typ:upper())] or xsys.NotificationTypes.GENERIC,dur))
end

do --Commands Core
	xsys.cmds = xsys.cmds or {}
	
	xsys.CallCommand = function(ply,cmd,txt,arg)
		if ply.IsBanned and ply:IsBanned() and not ply:IsAdmin() then return end
		local sid
		if type(ply) == "string" and ply:find("STEAM_") then sid = ply end
		local ok,err = pcall(function()
			cmd = xsys.cmds[cmd]
			if cmd and (sid and xsys.CheckUserGroupFromSteamID(sid,cmd.group) or (not ply:IsValid() or ply:CheckUserGroupLevel(cmd.group))) then
				if sid then ply = NULL end
				local can,reason = hook.Call("XsysCommand",GAMEMODE,cmd,ply,txt,unpack(arg))
				if can ~= false then
					easylua.Start(ply)
						local ok = false
						ok,can,reason = xpcall(cmd.callback,debug.traceback,ply,txt,unpack(arg))
					easylua.End()
					if not ok then
						ErrorNoHalt("Xsys cmd "..tostring(cmd and cmd.cmd).." failed:\n    "..tostring(can)..'\n')
						reason,can = "INTERNAL ERROR",false
					end
				end
				if ply:IsValid() then
					if reason then xsys.Message(ply,reason,not can and "ERROR" or "GENERIC") end
					if can == false then ply:EmitSound("buttons/combine_button_locked.wav",100,120) end
				end
			end
		end)
		if not ok then
			ErrorNoHalt(err)
			return err
		end
	end
	
	xsys.AddCommand = function(cmd,cb,g)
		if istable(cmd) then
			for k,v in pairs(cmd) do xsys.AddCommand(v,cb,g) end
			return
		end
		xsys.cmds[cmd] = {
			callback = cb,
			group = g or "players",
			cmd = cmd
		}
		hook.Run("XsysCommandAdded",cmd,cb,g)
	end
end

do --Commands
	xsys.NoTarget = function(t)
		return string.format("could not find: %q",t or "<no target>")
	end
	
	if SERVER then
		AddCSLuaFile("xsys/xsys_commands.lua")
	end
	include("xsys/xsys_commands.lua")
end

do --Rank System
	local UserFile = "xsys/users.txt"
	
	do --Team Creation
		function team.GetIDByName(n)
			for k,v in pairs(team.GetAllTeams()) do
				if v.Name == n then
					return k
				end
			end
			return 1
		end
	end
	
	xsys.Ranks = xsys.Ranks or {}
	
	local ranklist = {
		["players"] = 1,
		["designers"] = 2,
		["owners"] = math.huge
	}
	local rankaliases = {
		["users"] = "players",
		["none"] = "players",
		["devs"] = "designers",	
		["editors"] = "designers",
		["creators"] = "owners",
		["superadmins"] = "owners",
		["owner"] = "owners",
		["dev"] = "designers",
		["designer"] = "designers"
	}
	
	local pm = FindMetaTable("Player")
	function pm:CheckUserGroupLevel(name)
		name = rankaliases[name] or name
		local g = self:GetUserGroup()
		local a,b = ranklist[g],ranklist[name]
		return a and b and a >= b
	end
	
	function pm:ShouldHideAdmins()
		return self.HideAdmins or false
	end
	
	function pm:IsAdmin()
		if self:ShouldHideAdmins() then return false end
		return self:CheckUserGroupLevel("designers")
	end
	
	function pm:IsSuperAdmin()
		if self:ShouldHideAdmins() then return false end
		return self:CheckUserGroupLevel("designers")
	end
	
	function pm:IsUserGroup(g)
		g = (rankaliases[g] or g):lower()
		local gg = self:GetUserGroup()
		return g == gg or false
	end
	
	function pm:GetUserGroup()
		if self:ShouldHideAdmins() then return "players" end
		return self:GetNetworkedString("Rank"):lower()
	end
	
	team.SetUp(1,"players",Color(32,32,80))
	team.SetUp(2,"designers",Color(128,170,255))
	team.SetUp(3,"owners",Color(64,128,255))
	
	if SERVER then
		local nostore = {
			"moderators",
			"players",
			"users"
		}
		
		local function clean(u,sid)
			for k,v in pairs(u) do
				k = k:lower()
				if not ranklist[k] then
					u[k] = nil
				else
					for kk,vv in pairs(v) do
						if kk:lower() == sid:lower() then
							v[sid] = nil
						end
					end
				end
			end
			return u
		end
		
		local function issafe(s)
			return s:gsub("{",""):gsub("}","")
		end
		
		function pm:SetUserGroup(name,force)
			name = name:Trim()
			name = rankaliases[name] or name
			self:SetTeam(team.GetIDByName(name))
			self:SetNetworkedString("Rank",name)
			if force == false or #name == 0 then return end
			name = name:lower()
			if force or (not table.HasValue(nostore,name) and ranklist[name]) then
				local u = luadata.ReadFile(UserFile)
				u[name] = u[name] or {}
				u[name][self:SteamID()] = self:Nick():gsub("%A","") or "N/A"
				file.CreateDir("xsys")
				luadata.WriteFile(UserFile,u)
				xsys.Notify("Rank",string.format("Changing %s (%s)'s rank to %s",self:Nick(),self:SteamID(),name))
			end
		end
		
		xsys.GetUserGroupFromSteamID = function(sid)
			for k,v in pairs(luadata.ReadFile(UserFile)) do
				for kk,vv in pairs(v) do
					if kk == sid then
						return k,vv
					end
				end
			end
		end
		
		xsys.CheckUserGroupFromSteamID = function(sid,g)
			local gr = xsys.GetUserGroupFromSteamID(sid)
			if gr then
				g = rankaliases[g] or g
				local a,b = ranklist[gr],ranklist[gr]
				return a and b and a >= b
			end
			return false
		end

		local ufd,ufc = -2,nil
		hook.Add("PlayerSpawn","XsysPlayerAuthentication",function(ply)
			ply:SetUserGroup("players")
			if game.SinglePlayer() or ply:IsListenServerHost() then
				ply:SetUserGroup("owners")
				return
			end
			local time = file.Time(UserFile,"DATA")
			time = time and time > 0 and time or 1/0
			if ufd ~= time then
				ufc = luadata.ReadFile(UserFile) or {}
				ufd = time
			end
			for k,v in pairs(ufc) do
				for kk,vv in pairs(v) do
					if ply:SteamID() == kk or ply:UniqueID() == kk then
						ply:SetUserGroup(k,false)
					end
				end
			end

			timer.Simple(0, function() -- frame delay
				if not IsValid(ply) then return end

				if ply:GetNoCollideWithTeammates() then
					ply:SetNoCollideWithTeammates(false)
				end
			end)
		end)
		
		hook.Add("InitPostEntity","XsysLoadUnlimited",function()
			local pm = FindMetaTable("Player")
			local GetCount = pm.GetCount
			function pm.GetCount(self,lim,min)
				if self.Unrestricted then
					return -1
				else
					return GetCount(self,lim,min)
				end
			end
		end)
	end
end

if SERVER then
	AddCSLuaFile("xsys/xsys_core.lua")
	--AddCSLuaFile("xsys/xsys_countdown.lua") -- Todo
	AddCSLuaFile("xsys/xsys_commandfactory.lua")
end

--include("xsys/xsys_countdown.lua") -- Todo
include("xsys/xsys_commandfactory.lua")

XSYS_FUNCTIONAL = true