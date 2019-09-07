xsys.xban = xsys.xban or {}

xsys.xban.NetStrings = {
	Msg      = "XbanMsg",
	Restrict = "XBanRestrict"
}

local PlayerMeta = FindMetaTable("Player")
PlayerMeta.VoidBan = PlayerMeta.VoidBan and PlayerMeta.VoidBan or PlayerMeta.Ban

function PlayerMeta:IsBanned()
	return self:GetNWBool("XsysBanned")
end

if SERVER then
	function PlayerMeta:Ban(banner,time,hardban,reason)
		xsys.xban.Ban(self,banner or "Xenora",time or xsys.xban.DefaultBanTime,hardban or false,reason or "Doing something dumb")
	end
	
	function PlayerMeta:Unban(unbanner,reason)
		xsys.xban.Unban(self,unbanner or "Xenora",reason or "They're okay now")
	end
end

xsys.xban.GetTimeLength = function(time)
	time = math.max(0,time)-4
	
	local length = ""
	
	local years = math.floor(time/86400 /365)
	local days  = math.floor(time/86400)%365
	
	if     time < 3600  then -- Less than 1 hour
		length = string.format("%02d:%02d",math.floor(time/60),time%60)
	elseif time < 86400 then -- Less than 1 day
		length = string.format("%02d:%02d:%02d",math.floor(time/3600),math.floor(time/60)%60,time%60)
	elseif years == 0   then -- Less than 1 year
		length = string.format("%d day%s, %02d:%02d:%02d",days,days == 1 and "" or "s",math.floor(time/3600)%24,math.floor(time/60)%60,time%60)
	elseif years < 1e8  then -- Less than 100,000,000 years
		length = string.format("%d year%s, %d day%s, %02d:%02d:%02d",years,years == 1 and "" or "s",days,days == 1 and "" or "s",math.floor(time/3600)%24,math.floor(time/60)%60,time%60)
	elseif time ~= 0    then -- Less than infinity
		length = string.format("%.2f U-235 half-lives",years/7.038e8)
	else -- Infinity
		length = "Infinity"
	end
	
	return length
end

if SERVER then
	
	for k,v in pairs(xsys.xban.NetStrings) do
		util.AddNetworkString(v)
	end
	
	xsys.xban.BanFile        = "xsys/bans.txt"
	xsys.xban.DefaultBanTime = 3600 -- Seconds (1 Hour)
	xsys.xban.Hooks = {}
	
	xsys.xban.LiveBans = {}
	
	xsys.xban.BanData = {
		Name            = "N/A",
		NickName        = "N/A",
		SteamID64       = "N/A",
		Rank            = "N/A",
		BannerName      = "N/A",
		BannerNickName  = "N/A",
		BannerSteamID   = "N/A",
		BannerSteamID64 = "N/A",
		Reason          = "N/A",
		StartTime       = 0    , -- Epoch time
		EndTime         = 0    , -- Epoch time
		Length          = 0    , -- In seconds
		Expired         = 0    ,
		TimesBanned     = 0    ,
		HardBanned      = false,
		Interrupted     = false, -- In case someone is unbanned before EndTime.
		PreviousBans    = {}   ,
	}
	
	xsys.xban.PendingBans = xsys.xban.PendingBans or {}
	
	xsys.xban.Msg = function(...)
		local t = {...}
		net.Start(xsys.xban.NetStrings.Msg)
			net.WriteTable(t)
		net.Broadcast()
		
		local svmsg = ""
		for k,v in pairs(t) do
			if type(v) ~= "table" then
				svmsg = svmsg..tostring(v)
			end
		end
		
		print(svmsg)
		MsgC(...,"\n")
	end
	
	xsys.xban.GetAllBans = function()
		return util.JSONToTable(file.Read(xsys.xban.BanFile,"DATA")) or {}
	end
	
	xsys.xban.GetBan = function(id) -- id == ply:SteamID()
		id = type(id) == "Player" and id:SteamID() or id
		local bans = xsys.xban.GetAllBans()
		
		local ban = {}
		
		for k,v in pairs(bans) do
			if id == k then
				ban = v
				break
			end
		end
		
		return table.Count(ban) ~= 0 and ban or nil
	end
	
	xsys.xban.RefreshLiveBans = function()
		xsys.xban.LiveBans = xsys.xban.GetAllBans()
		
		local time = os.time()
		
		for k,v in pairs(xsys.xban.LiveBans) do
			if v.Length == 0 then continue end -- Infinite
			if time >= v.EndTime then
				xsys.xban.UnbanID(k,"Ban has Expired")
				continue
			end
		end
	end
	
	xsys.xban.WriteBanData = function(id,data)
		local bans = xsys.xban.GetAllBans()
		
		bans[id] = data
		xsys.xban.LiveBans[id] = data
		
		if player.GetBySteamID(id) then
			net.Start(xsys.xban.NetStrings.Restrict)
				net.WriteTable(bans[id])
			net.Send(player.GetBySteamID(id))
		end
		
		local banfile = file.Open(xsys.xban.BanFile,"w","DATA")
		banfile:Write(util.TableToJSON(bans))
		banfile:Close()
	end
	
	xsys.xban.UpdateBan = function(id,data)
		local bans = xsys.xban.GetAllBans()
		local ban  = nil
		
		for k,v in pairs(bans) do
			if id == k then
				ban = v
				break
			end
		end
		
		if not ban then return end
		
		for k,v in pairs(data) do
			ban[k] = v
		end
		
		xsys.xban.WriteBanData(id,ban)
	end
	
	xsys.xban.IsBanned = function(id)
		local ban = xsys.xban.GetBan(id)
		if not ban then return false end
		return not (ban.Expired or ban.Interrupted)
	end
	
	xsys.xban.LookupPlayerInfo = function(id)
		local pdata = {}
		local key   = base64.decode("MjU1MkUwQTExNzYyNkVBMjVERUJBQkEyNkQ3RTNEMDI=")
		local id64  = SteamID64(id)
		
		http.Fetch("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key="..base64.decode("MjU1MkUwQTExNzYyNkVBMjVERUJBQkEyNkQ3RTNEMDI=").."&steamids=".."76561198987868394",function(b,s,h,c)
			return util.JSONToTable(b)
		end,function(e) end)
		
		return pdata
	end
	
	xsys.xban.SetupBanTable = function(ply,banner,time,hardban,reason)
		local ispending = type(ply) ~= "Player"
		local plyinfo   = ispending and xsys.xban.LookupPlayerInfo(ply) or {}
		local plydat    = table.Count(plyinfo) ~= 0 and plyinfo.response.players[1] or {}
		local isxenora  = type(banner) == "string"
		
		local currenttime = os.time()
		
		local oldban = xsys.xban.GetBan(ispending and ply or ply:SteamID()) or nil
		
		local newban = table.Copy(xsys.xban.BanData)
		newban.Name            = ispending and (plydat.personaname or "N/A") or ply:RealName()
		newban.NickName        = ispending and (plydat.personaname or "N/A") or ply:Nick()
		newban.SteamID64       = ispending and (plydat.steamid or SteamID64(ply)) or ply:SteamID64()
		newban.Rank            = team.GetName(ply:Team())
		newban.BannerName      = isxenora and "Xenora" or banner:RealName()
		newban.BannerNickName  = isxenora and "The Server" or banner:Nick()
		newban.BannerSteamID   = isxenora and "STEAM_XE:NO:RA" or banner:SteamID()
		newban.BannerSteamID64 = isxenora and "XENORA" or banner:SteamID64()
		newban.Reason          = reason or "Doing something dumb"
		newban.StartTime       = currenttime
		newban.EndTime         = time == 0 and 0xffffffff or currenttime+(time or xsys.xban.DefaultBanTime)
		newban.Length          = time == 0 and 0 or newban.EndTime-newban.StartTime
		newban.Expired         = false
		newban.HardBanned      = hardban
		newban.TimesBanned     = oldban and oldban.TimesBanned+1 or 1
		newban.PreviousBans    = oldban and oldban.PreviousBans or {}
		
		if oldban then
			oldban.PreviousBans = nil
			newban.PreviousBans[oldban.StartTime] = oldban
		end
		
		return newban
	end
	
	xsys.xban.Restrict = function(ply)
		if not xsys.xban.IsBanned(ply:SteamID()) then return end -- Can't restrict non-banned players.
		
		ply:SetUserGroup("banned")
		
		ply.OldUnrestricted = ply.Unrestricted ~= nil and ply.Unrestricted or false -- Restrict
		ply.Unrestricted = false
		
		ply.OldWeapons = {} -- Backup and strip weapons
		ply.OldSelectedWeapon = ply:GetActiveWeapon():GetClass()
		for k,v in pairs(ply:GetWeapons()) do
			ply.OldWeapons[v:GetClass()] = true
		end
		
		ply:StripWeapons()
		ply:Give("none")
		
		for k,v in pairs(ents.GetAll()) do -- Remove entities
			if v.CPPIGetOwner and v:CPPIGetOwner() == ply then
				SafeRemoveEntity(v)
			end
		end
		
		ply:ExitVehicle() -- Get out of vehicle
		ply:SetMoveType(MOVETYPE_WALK) -- Exit noclip
		
		ply.OldGodMode = ply:GetInfoNum("cl_godmode",0) or 0 -- Disable godmode
		ply:ConCommand("cl_godmode 0")
	end
	
	xsys.xban.Unrestrict = function(ply)
		if xsys.xban.IsBanned(ply:SteamID()) then return end -- Can't unrestrict banned players
		
		local oldgroup = xsys.xban.GetBan(ply).Rank
		ply:SetUserGroup(oldgroup ~= "N/A" and oldgroup or "players")
		
		ply.Unrestricted = ply.OldUnrestricted ~= nil and ply.OldUnrestricted or false -- Revert restrict
		ply.OldUnrestricted = nil
		
		if ply.OldWeapons then -- Give old weapons back
			for k,v in pairs(ply.OldWeapons) do
				ply:Give(k)
			end
			if ply.OldSelectedWeapon then
				ply:SelectWeapon(ply.OldSelectedWeapon)
			end
		end
		
		ply.OldWeapons = nil
		ply.OldSelectedWeapon = nil
		
		if ply.OldGodMode then -- Give old godmode back
			ply:ConCommand("cl_godmode "..(ply.OldGodMode == 1 and 0 or 1))
		end
		ply.OldGodMode = nil
	end
	
	xsys.xban.AddPendingBan = function(id,banner,time,hardban,reason)
		xsys.xban.PendingBans[id] = xsys.xban.SetupBanTable(id,banner,time,hardban,reason)
	end
	
	xsys.xban.RemovePendingBan = function(id)
		xsys.xban.PendingBans[id] = nil
	end
	
	local  red  = Color(255,0  ,0  )
	local lred  = Color(255,200,200)
	local  blue = Color(32 ,64 ,255)
	local lblue = Color(100,200,255)
	local black = Color(0  ,0  ,0  )
	local white = Color(255,255,255)
	
	xsys.xban.Ban = function(ply,banner,time,hardban,reason)
		if not ply:IsValid() then return end
		if xsys.xban.IsBanned(ply:SteamID()) then return end -- Already banned
		
		ply:SetNWString("XsysRealUserGroup",team.GetName(ply:Team()))
		
		local newban = xsys.xban.SetupBanTable(ply,banner,time,hardban,reason)
		local isxenora = type(banner) ~= "Player"
		
		xsys.xban.WriteBanData(ply:SteamID(),newban)
		
		if hardban then
			if isxenora then
				ply:Kick("You have been Banned by Xenora for "..xsys.xban.GetTimeLength(newban.Length)..
					". Ban lifts "..os.date("%B %d, %Y at %I:%M:%S %p",newban.EndTime).."."..
					" Reason: "..reason)
			else
				ply:Kick("You have been Banned by "..
					banner:Nick()..(banner:RealName() ~= banner:Nick() and " / "..banner:RealName() or "")..
					" for "..xsys.xban.GetTimeLength(newban.Length)..". Ban lifts "..os.date("%B %d, %Y at %I:%M:%S %p",newban.EndTime).."."..
					" Reason: "..reason)
			end
			xsys.xban.Msg(red  ,"[XBan]",
					  	  lred ," Player ",
					  	  team.GetColor(ply:Team()),ply:Nick()..(ply:RealName() ~= ply:Nick() and " / "..ply:RealName() or ""),
					  	  lred ," has been ",
					  	  black,"HARDBANNED",
					  	  lred ," until ",
					  	  red  ,newban.Length == 0 and "Infinity (A long time)"
					  		or os.date("%B %d, %Y at %I:%M:%S %p",newban.EndTime).." ("..xsys.xban.GetTimeLength(newban.Length+1)..") ",
					  	  lred ," by ",
					  	  isxenora and Color(150,100,255) or team.GetColor(banner:Team()),
					  	  	isxenora and "Xenora" or banner:Nick()..(banner:RealName() ~= banner:Nick() and " / "..banner:RealName() or ""),
					  	  lred ," for the reason: ",
					  	  white,reason)
			return
		end
		
		ply.XsysBanned = true
		ply:SetNWBool("XsysBanned",true)
		xsys.xban.Msg(red  ,"[XBan]",
					  lred ," Player ",
					  team.GetColor(ply:Team()),ply:Nick()..(ply:RealName() ~= ply:Nick() and " / "..ply:RealName() or ""),
					  lred ," has been ",
					  red  ,"BANNED",
					  lred ," until ",
					  red  ,newban.Length == 0 and "Infinity (A long time)"
					  	or os.date("%B %d, %Y at %I:%M:%S %p",newban.EndTime).." ("..xsys.xban.GetTimeLength(newban.Length+1)..") ",
					  lred ,"by ",
					  isxenora and Color(150,100,255) or team.GetColor(banner:Team()),
					  	isxenora and "Xenora" or banner:Nick()..(banner:RealName() ~= banner:Nick() and " / "..banner:RealName() or ""),
					  lred ," for the reason: ",
					  white,reason)
		xsys.xban.Restrict(ply)
		hook.Call("XsysBanPlayer",nil,false,ply,banner,time,hardban,reason)
	end
	
	xsys.xban.BanID = function(id,banner,time,hardban,reason)
		local inserver = player.GetBySteamID(id)
		local isxenora = type(banner) ~= "Player"
		
		if inserver then
			if xsys.xban.IsBanned(inserver:SteamID()) then return end -- Already banned
			xsys.xban.Ban(inserver,banner,time,hardban,reason)
			return
		end
		
		if xsys.xban.IsBanned(id) then return end -- Already banned
		
		local plyinfo = xsys.xban.LookupPlayerInfo(id) or {}
		
		local newban = xsys.xban.SetupBanTable(id,banner,time,hardban,reason)
		
		xsys.xban.WriteBanData(id,newban)
		
		xsys.xban.AddPendingBan(id,banner,time,hardban,reason)
		xsys.xban.Msg(red  ,"[XBan]",
					  lred ," Player ",
					  red  ,(plyinfo.personaname or "Unknown Name").." ["..id.."]",
					  lred ," will be ",
					  red  ,"BANNED",
					  lred ," on next join from now until ",
					  red  ,newban.Length == 0 and "Infinity (A long time)"
					  	or os.date("%B %d, %Y at %I:%M:%S %p",newban.EndTime).." ("..xsys.xban.GetTimeLength(newban.Length+4)..")",
					  lred ," by ",
					  isxenora and Color(150,100,255) or team.GetColor(banner:Team()),
					  	isxenora and "Xenora" or banner:Nick()..(banner:RealName() ~= banner:Nick() and " / "..banner:RealName() or ""),
					  lred ," for the reason: ",
					  white,reason)
		hook.Call("XsysAddPendingBan",nil,inserver or id,banner,time,hardban,reason)
	end
	
	xsys.xban.Unban = function(ply,unbanner,reason)
		if not xsys.xban.IsBanned(ply:SteamID()) then return end -- Not banned
		
		local ban = xsys.xban.GetBan(ply:SteamID())
		local isxenora = type(unbanner) ~= "Player"
		
		if not ban then print("wtf") return end
		
		if ban.Expired or ban.Interruped then return end -- Already Unbanned
		
		local interrupted = ban.hardban or os.time() < ban.EndTime
		
		if interrupted then
			ban.Interrupted = true
		end
		
		local plyinfo = xsys.xban.LookupPlayerInfo(ply:SteamID()) or {}
		
		if os.time() >= ban.EndTime then
			ban.Expired = true
		end
		
		xsys.xban.WriteBanData(ply:SteamID(),ban)
		
		if xsys.xban.LiveBans[ply:SteamID()] then
			xsys.xban.LiveBans[ply:SteamID()] = nil
		end
		
		local lentime = ban.Length == 0 and (os.time()-ban.StartTime) or ((os.time()-ban.StartTime)/(ban.EndTime-ban.StartTime))*ban.Length
		
		ply.XsysBanned = false
		ply:SetNWBool("XsysBanned",false)
		xsys.xban.Msg(blue  ,"[XBan]",
					  lblue ," Player ",
					  blue  ,ply:Nick()..(ply:RealName() ~= ply:Nick() and " / "..ply:RealName() or "").." ["..ply:SteamID().."]",
					  lblue ," has been ",
					  blue  ,"UNBANNED",
					  lblue ,interrupted and " by " or " after a ban length of ",
					  interrupted and blue or "",
					  	interrupted and (isxenora and "Xenora" or unbanner:Nick()..(unbanner:RealName() ~= unbanner:Nick() and " / "..unbanner:RealName() or "")..
					  		" ["..unbanner:SteamID().."]") or "",
					  interrupted and lblue or "",interrupted and " after being banned for " or "",
					  blue  ,interrupted and xsys.xban.GetTimeLength(lentime) or xsys.xban.GetTimeLength(ban.Length+4),
					  lblue ," with the reason: ",
					  white,reason)
		xsys.xban.Unrestrict(ply)
		hook.Call("XsysUnbanPlayer",nil,ply,reason)
	end
	
	xsys.xban.UnbanID = function(id,unbanner,reason)
		local inserver = player.GetBySteamID(id)
		
		if inserver then
			if not xsys.xban.IsBanned(inserver:SteamID()) then return end -- Not banned
			xsys.xban.Unban(inserver,unbanner,reason)
			return
		end
		
		if not xsys.xban.IsBanned(id) then return end -- Not banned
		
		local ban = xsys.xban.GetBan(id)
		
		local interrupted = ban.hardban or os.time() < ban.EndTime
		
		if interrupted then
			ban.Interrupted = true
		end
		
		local plyinfo = xsys.xban.LookupPlayerInfo(id) or {}
		
		if os.time() >= ban.EndTime then
			ban.Expired = true
		end
		
		xsys.xban.WriteBanData(id,ban)
		
		xsys.xban.RemovePendingBan(id)
		xsys.xban.Msg(blue  ,"[XBan]",
					  lblue ," Player ",
					  blue  ,(plyinfo.personaname or "Unknown Name").." ["..id.."]",
					  lblue ," will be ",
					  blue  ,"UNBANNED",
					  lblue ," on next join for the reason: ",
					  white,reason)
		hook.Call("XsysRemovePendingBan",nil,inserver or id,reason)
	end
	
	xsys.xban.Startup = function()
		if not file.Exists(xsys.xban.BanFile,"DATA") then
			local bf = file.Open(xsys.xban.BanFile,"w","DATA")
			bf:Close()
		end
		
		xsys.xban.RefreshLiveBans()
	end
	
	xsys.xban.Hooks.Prevention = function() -- For hook persistence
		local time = os.time()
		
		for k,v in pairs(xsys.xban.LiveBans) do
			if v.Length == 0 then continue end -- Ban is infinite, don't check it.
			if time >= v.EndTime and not (v.Expired or v.Interrupted) then -- Ban has expired without interruption.
				xsys.xban.UnbanID(k,"Xenora","Ban has Expired")
				continue
			end
		end
		
		for k,v in pairs(xsys.xban.PendingBans) do
			local ply = player.GetByID(k)
			if ply then
				xsys.xban.Ban(ply,true,v.StartTime,v.HardBanned,v.Reason)
				xsys.xban.PendingBans[k] = nil
				continue
			end
		end
	end
	hook.Add("Think","XSysXBanPrevention",xsys.xban.Hooks.Prevention)
	
	gameevent.Listen("player_connect")
	xsys.xban.Hooks.JoinDetection = function(data)
		local ban = xsys.xban.LiveBans[data.steamid]
		if ban then
			if ban.HardBanned then
				local remaining = 1-((os.time()-ben.StartTime)/(ban.EndTime-ban.StartTime))
				game.KickID(data.steamid,
					"You have been Hard-Banned from Xenora until: "..
					os.date("%B %d, %Y at %I:%M:%S %p",ban.EndTime)..
					"\n\n Time Remaining: "..
					xsys.xban.GetTimeLength(math.floor(ban.Length*remaining))..
					"\n( "..math.Round(2,remaining*100).."% )")
			end
		end
	end
	hook.Add("player_connect","XSysXBanJoinDetection",xsys.xban.Hooks.JoinDetection)
	
	xsys.xban.Hooks.InitialSpawnDetection = function(ply,transition)
		if xsys.xban.IsBanned(ply:SteamID()) then
			xsys.xban.Restrict(ply)
			ply.XsysBanned = true
			ply:SetNWBool("XsysBanned",true)
		end
		
		net.Start(xsys.xban.NetStrings.Restrict)
			net.WriteTable(xsys.xban.GetBan(ply:SteamID()))
		net.Send(ply)
	end
	hook.Add("PlayerInitialSpawn","XSysXNanInitialSpawnDetection",xsys.xban.Hooks.InitialSpawnDetection)
	
	
	xsys.xban.IsRestricted = function(ply)
		return ply:GetNWBool("XsysBanned")
	end
	
	xsys.xban.IsNotRestricted = function(ply)
		return not ply:GetNWBool("XsysBanned")
	end
	
	xsys.xban.RestrictionTag = "XsysXBanRestriction"
	
	hook.Add("CanPlayerEnterVehicle" ,xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("CanPlayerSuicide"      ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSwitchFlashlight",xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpray"           ,xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("PlayerUse"             ,xsys.xban.RestrictionTag,function (ply,ent) return xsys.xban.IsRestricted(ply) and false or nil end)
	hook.Add("PreChatSoundsSay"      ,xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("PlayerNoClip"          ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerFlyDisallow"     ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	
	hook.Add("PlayerSay",xsys.xban.RestrictionTag,function(ply)
		if xsys.xban.IsRestricted(ply) then
			return ""
		end
	end)
	
	xsys.xban.WeaponWhitelist = {none = true}
	hook.Add("WeaponEquip",xsys.xban.RestrictionTag,function(wep)
		timer.Simple(0,function()
			if IsValid(wep) then
				local ply = wep:GetOwner()
				if xsys.xban.IsRestricted(ply) and not xsys.xban.WeaponWhitelist[wep:GetClass()] then
					wep:Remove()
				end
			end
		end)
	end)
	
	hook.Add("PlayerCanHearPlayersVoice",xsys.xban.RestrictionTag,function(listener,speaker)
		if xsys.xban.IsRestricted(speaker) then
			return false
		end
	end)
	hook.Add("PlayerCanSeePlayersChat"  ,xsys.xban.RestrictionTag,function(listener,speaker)
		if xsys.xban.IsRestricted(speaker) and listener:GetPos():Distance(speaker:GetPos()) > 64 then
			return false
		end
	end)
	
	hook.Add("PlayerTraceAttack"        ,xsys.xban.RestrictionTag, function(_,dmginfo)
		if dmginfo:GetAttacker():IsPlayer() and xsys.xban.IsRestricted(dmginfo:GetAttacker()) then
			return false
		end
	end)
	
	hook.Add("OnPhysgunReload"   ,xsys.xban.RestrictionTag,function(_,ply)   return xsys.xban.IsRestricted(ply) end)
	hook.Add("PhysgunPickup"     ,xsys.xban.RestrictionTag,function(ply,ent) return xsys.xban.IsRestricted(ply) end)
	hook.Add("OnPhysgunReload"   ,xsys.xban.RestrictionTag,function(_,ply)   return xsys.xban.IsRestricted(ply) end)
	hook.Add("PlayerSpawnEffect" ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnVehicle",xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnNPC"    ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnSENT"   ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnSWEP"   ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnProp"   ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	hook.Add("PlayerSpawnObject" ,xsys.xban.RestrictionTag,xsys.xban.IsNotRestricted)
	
	local inclear
	hook.Add("PrePACConfigApply",xsys.xban.RestrictionTag,function(ply,data)
		if xsys.xban.IsRestricted(ply) and not inclear then
			return false,"Banned"
		end
	end)
	
	xsys.xban.PropertyWhitelist = {}
	hook.Add("CanProperty",xsys.xban.RestrictionTag,function(ply,property,ent)
		if xsys.xban.IsRestricted(ply) and not xsys.xban.PropertyWhitelist[property] then
			return false
		end
	end)
	
	hook.Add("PlayerGiveSWEP"    ,xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("PlayerSpawnRagdoll",xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("CanTool"           ,xsys.xban.RestrictionTag,xsys.xban.IsRestricted)
	hook.Add("PlayerDeath"       ,xsys.xban.RestrictionTag,function(ply)
		if xsys.xban.IsRestricted(ply) then
			local pos = ply:GetPos()
			timer.Simple(3,function()
				if IsValid(ply) and xsys.xban.IsRestricted(ply) then
					ply:Spawn()
					ply:SetPos(pos)
				end
			end)
		end
	end)
	
	hook.Add("PlayerShouldTakeDamage",xsys.xban.RestrictionTag,function(ply)
		if xsys.xban.IsRestricted(ply) then
			return true
		end
	end)
	
	
	xsys.xban.Startup()
	
else -- CLIENT

	xsys.xban.LocalBanData = xsys.xban.LocalBanData or {}

	xsys.xban.Receivers = {}
	
	local starting,started,ending,ended = false,false,false,false
	
	xsys.xban.Receivers[xsys.xban.NetStrings.Msg] = function(l,p)
		local msgtab = net.ReadTable()
		chat.AddText(unpack(msgtab))
	end
	
	xsys.xban.Receivers[xsys.xban.NetStrings.Restrict] = function(l,p)
		local msgtab = net.ReadTable()
		xsys.xban.LocalBanData = msgtab
		
		if not (msgtab.Interrupted or msgtab.Expired) then
			starting,started,ending,ended = false,false,false,false
		end
	end
	
	for k,v in pairs(xsys.xban.Receivers) do
		net.Receive(k,v)
	end
	
	surface.CreateFont("xban-header"   ,{font="Tahoma",size=96,weight=700,antialias=true})
	surface.CreateFont("xban-time"     ,{font="Tahoma",size=32,weight=400,antialias=true})
	surface.CreateFont("xban-timesmall",{font="Tahoma",size=24,weight=400,antialias=true})
	surface.CreateFont("xban-other"    ,{font="Tahoma",size=16,weight=400,antialias=true})
	
	local function MatrixText(text,font,x,y,mult,color,xal,yal,ol,olcol)
		local txtmatrix = Matrix()
		txtmatrix:Translate(Vector(x,y))
		txtmatrix:SetScale(Vector(mult,mult,mult))
		txtmatrix:SetTranslation(Vector(x,y))
		txtmatrix:Translate(-Vector(x,y))
		cam.PushModelMatrix(txtmatrix)
			draw.SimpleTextOutlined(text,font,x,y,color,xal,yal,ol,olcol)
		cam.PopModelMatrix()
	end
	
	local function XBanHUDinit()
		local a1,a2,a3,a4,a5 = 0,0,0,0,0
		local x,y = ScrW()/2,ScrH()/2-ScrH()/3
		xsys.xban.HUDWhileBanned = function()
			local banned = LocalPlayer():GetNWBool("XsysBanned")
			
			if banned and not started then
				started  = true
				starting = true
			end
			
			a1 = Lerp(0.1,a1,starting and 1 or 0)
			a2 = Lerp(0.1,a2,starting and 1 or 0)
			
			if started and starting and a1 > 0.98 and a2 > 0.98 then
				starting = false
			end
			
			a3 = Lerp(0.1,a3,started and not starting and not ended and 1 or 0)
			
			a4 = Lerp(0.1,a4,ending  and 1 or 0)
			a5 = Lerp(0.1,a5,ending  and 1 or 0)
			
			if not banned and started and not ended then
				ending  = true
				ended   = true
			end
			
			if ended and ending and a4 > 0.98 and a5 > 0.98 then
				ending = false
			end
			
			if not banned and a1 <= 0 and a2 <= 0 and a3 <= 0 and a4 <= 0 and a5 <= 0 then return end
			
			local b = xsys.xban.LocalBanData
			
			if table.Count(b) ~= 0 then
				local lift = b.Length == 0 and "Never" or os.date("%B %d, %Y at %I:%M:%S %p",b.EndTime)
				local remaining = b.Length == 0 and "Infinite"  or
					xsys.xban.GetTimeLength((1-((os.time()-b.StartTime)/(b.EndTime-b.StartTime)))*b.Length)
				local suffix = b.TimesBanned == 1 and "st" or b.TimesBanned == 2 and "nd" or b.TimesBanned == 3 and "rd" or "th"
				
				MatrixText("-Ban Lift-"      ,"xban-timesmall",x,y-96,0.5+a3*0.5,Color(255,255,255,a3*255),1,1,1,Color(0,0,0,a3*255))
				MatrixText(lift              ,"xban-time"     ,x,y-64,0.5+a3*0.5,Color(255,255,255,a3*255),1,1,1,Color(0,0,0,a3*255))
				
				if b.Length ~= 0 then
					local rem = 1-(((os.time()+4)-b.StartTime)/(b.EndTime-b.StartTime))
					local halfa = (0.5+a3*0.5)
					local xx,yy,ww,hh = x-halfa*ScrW()/4,y-32-(a3*10),halfa*ScrW()/2,(a3*20)
					surface.SetDrawColor(Color(0  ,0 ,0 ,a3*180))
					surface.DrawRect(xx,yy,ww,hh)
					surface.SetDrawColor(Color(255,64,64,a3*100))
					surface.DrawRect(xx+ww/2-rem*ww/2,yy+2,ww*rem,hh-4)
				end
				
				MatrixText("-Time Remaining-","xban-timesmall",x,y   ,0.5+a3*0.5,Color(255,255,255,a3*255),1,1,1,Color(0,0,0,a3*255))
				MatrixText(remaining         ,"xban-time"     ,x,y+32,0.5+a3*0.5,Color(255,255,255,a3*255),1,1,1,Color(0,0,0,a3*255))
				
				MatrixText("This is ban number "..b.TimesBanned,"xban-other",x,y+64,0.5+a3*0.5,Color(255,255,255,a3*255),1,1,1,Color(0,0,0,a3*255))
			end
			
			MatrixText("YOU HAVE BEEN","xban-header",x,y-32,0.5+a1*0.5,Color(255,0,0,a1*255),1,1,1,Color(0,0,0,a1*255))
			MatrixText("BANNED"       ,"xban-header",x,y+48,0.5+a2*1  ,Color(255,0,0,a2*255),1,1,1,Color(0,0,0,a2*255))
			
			MatrixText("YOU HAVE BEEN","xban-header",x,y-32,0.5+a4*0.5,Color(0,64,255,a4*255),1,1,1,Color(0,0,0,a4*255))
			MatrixText("UNBANNED"     ,"xban-header",x,y+48,0.5+a5*1  ,Color(0,64,255,a5*255),1,1,1,Color(0,0,0,a5*255))
		end
		hook.Add("HUDPaint","XSysXbanHUDWhileBanned",xsys.xban.HUDWhileBanned)
	end
	hook.Add("InitPostEntity","XSysXBanHUDInit",XBanHUDinit)
	
	if LocalPlayer and LocalPlayer():IsValid() then
		XBanHUDinit()
	end
end