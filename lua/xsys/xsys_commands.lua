do --Xsys Kill
	if SERVER then
		do
			util.AddNetworkString("XSys_Kill")
		end
		xsys.AddCommand({"kill","die","suicide","rip"},function(ply,txt,v,a)
			local cankill = hook.Run("CanPlayerSuicide",ply)
			if cankill == false then return end
			if ply.lastkill and CurTime()-ply.lastkill < 0.05 then return end
			ply.lastkill = CurTime()
			v,a = tonumber(v),tonumber(a)
			ply:Kill()
			if v then
				net.Start("XSys_Kill")
					net.WriteEntity(ply)
					net.WriteFloat(v)
					net.WriteFloat(a or 0)
				net.Broadcast()
			end
		end)
	else
		net.Receive("XSys_Kill",function(len,ply)
			local p,v,a = net.ReadEntity(),net.ReadFloat(),net.ReadFloat()
			if p:IsValid() then
				timer.Create("XsysKillFindRagdoll",0,100,function()
					if not p:IsValid() then return end
					local rag = p:GetRagdollEntity() or NULL
					if not rag:IsValid() then return end
					local phys = rag:GetPhysicsObject() or NULL
					if not phys:IsValid() then return end
					local vel,angv = p:GetAimVector()*v,VectorRand()*a
					for i=0,rag:GetPhysicsObjectCount()-1 do
						local lphy = rag:GetPhysicsObjectNum(i) or NULL
						if not lphy:IsValid() then continue end
						lphy:SetVelocity(vel ~= 0 and vel or lphy:GetVelocity())
						lphy:AddAngleVelocity(angv)
					end
					timer.Destroy("XsysKillFindRagdoll")
				end)
			end
		end)
	end
end

do
	if SERVER then
		xsys.AddCommand({"revive","respawn"},function(ply,txt,target,bool)
			local ok,reason = hook.Run("CanPlayerRespawn",ply)
			if ok == false then
				return false,reason and tostring(reason) or "You can't revive right now"
			end
			local revivee = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if revivee:IsValid() and revivee:IsPlayer() and not revivee:Alive() then
				local pos,ang = revivee:GetPos(),revivee:EyeAngles()
				revivee:Spawn()
				revivee:SetPos(pos)
				revivee:SetEyeAngles(ang)
			end
		end)
		
		hook.Add("CanPlyGotoPly","aowl_togglegoto",function(ply1,ply2)
			if ply2.ToggleGoto_NoGoto then
				if ply2.IsFriend and ply2:IsFriend(ply) then return end
				if ply1.Unrestricted then return end
				return false,ply2:Nick().." doesn't want to be disturbed!"
			end
		end)
		
		local t = {start=nil,endpos=nil,mask=MASK_PLAYERSOLID,filter=nil}
		local function IsStuck(ply)
			t.start = ply:GetPos()
			t.endpos,t.filter = t.start,ply
			return util.TraceEntity(t,ply).StartSolid
		end
		
		local function SendPlayer(from,to)
			local ok,err = hook.Run("CanPlyGotoPly",from,to)
			if ok == false then return "HOOK",err or "" end
			if not to:IsInWorld() then return false end
			local times = 16
			local anginc = 360/times
			local ang = to:GetVelocity():Length2D() < 1 and (to:IsPlayer() and to:GetAimVector() or to:GetForward()) or -to:GetVelocity()
			ang.z = 0
			ang:Normalize()
			ang = ang:Angle()
			local pos = to:GetPos()
			local frompos = from:GetPos()
			if from:IsPlayer() and from:InVehicle() then from:ExitVehicle() end
			local origy = ang.y
			for i=0,times do
				ang.y = origy+(-1)^i*(i/times)*180
				from:SetPos(pos+ang:Forward()*64+Vector(0,0,10))
				if not IsStuck(from) then return true end
			end
			from:SetPos(frompos)
			return false
		end
		
		local function Goto(ply,txt,target)
			local ok,err = hook.Run("CanPlyGoto",ply)
			if ok == false then return false,err or "" end
			if not ply:Alive() then ply:Spawn() end
			if not txt then return end
			local x,y,z = txt:match("(%-?%d+%.*%d*)[,%s]%s-(%-?%d+%.*%d*)[,%s]%s-(%-?%d+%.*%d*)")
			if x and y and z and ply:CheckUserGroupLevel("designers") then ply:SetPos(Vector(tonumber(x),tonumber(y),tonumber(z))) return end
			for k,v in pairs(xsys.Data.Locations) do
				local loc,map = k:match("(.*)@(.*)")
				if target == k or (target and map and loc:lower():Trim():find(target) and string.find(game.GetMap(),map,1,true) == 1) then
					if type(v) == "Vector" then
						if ply:InVehicle() then ply:ExitVehicle() end
						ply:SetPos(v)
						return
					else
						if ply:InVehicle() then ply:ExitVehicle() end
						return v(ply)
					end
				end
			end
			local ent = easylua.FindEntity(target)
			if not ent:IsValid() then return false,xsys.NoTarget(target) end
			if ent:GetParent():IsValid() and ent:GetParent():IsPlayer() then ent = ent:GetParent() end
			
			if ent == ply then return false,xsys.NoTarget(target) end
			local dir = ent:GetAngles()
			dir.p,dir.r = 0,0
			dir = (dir:Forward()*-100)
			local oldpos = ply:GetPos()+Vector(0,0,32)
			--sound.Play("npc/dog/dog_footstep"..math.random(1,4)..".wav",oldpos)
			local ok,err = SendPlayer(ply,ent)
			if ok == "HOOK" then return false,err end
			if not SendPlayer(ply,ent) then
				if ply:InVehicle() then ply:ExitVehicle() end
				ply:SetPos(ent:GetPos()+dir)
				ply:DropToFloor()
			end
			--xsys.Notify("goto",tostring(ply) .." >> ".. tostring(ent))
			if ply.UnStuck then timer.Simple(1,function() if IsValid(ply) then ply:UnStuck() end end) end
			ply:SetEyeAngles((ent:EyePos()-ply:EyePos()):Angle())
			--ply:EmitSound("buttons/button15.wav")
			--ply:EmitSound("npc/dog/dog_footstep_run"..math.random(1,8)..".wav")
			ply:SetVelocity(-ply:GetVelocity())
			hook.Run("XsysTargetCommand",ply,"goto",ent)
		end
		
		local function xsysgoto(ply,txt,target)
			if ply.IsBanned and ply:IsBanned() then return false,"Access Denied" end
			ply.xsys_tpprevious = ply:GetPos()
			return Goto(ply,txt,target)
		end
		xsys.AddCommand({"goto","go"},xsysgoto)
		
		xsys.AddCommand("togglegoto",function(ply,txt,target)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			local nogoto = not ent.ToggleGoto_NoGoto
			ent.ToggleGoto_NoGoto = nogoto
			ply:ChatPrint(nogoto and "Disabled goto on "..(ent == ply and "yourself" or ent:Nick()) or "Enabled goto on "..(ent == ply and "yourself" or ent:Nick()))
			if ply ~= ent then
				ent:ChatPrint(nogoto and ply:Nick().." disabled goto on you" or ply:Nick().." enabled goto on you")
			end
		end)
	
		xsys.AddCommand("tp",function(ply,txt,target,...)
			if target and #target > 1 then return xsysgoto(ply,txt,target,...) end
			local ok,err = hook.Run("CanPlyTeleport",ply)
			if ok == false then return false,err or "" end
			local start = ply:GetPos()+Vector(0,0,1)
			local pltr = ply:GetEyeTrace()
			local endpos = pltr.HitPos
			local wasinworld = util.IsInWorld(start)
			local diff = start-endpos
			local len = diff:Length()
			len = len > 100 and 100 or len
			diff:Normalize()
			diff = diff*len
			if not wasinworld and util.IsInWorld(endpos-pltr.HitNormal*120) then pltr.HitNormal = -pltr.HitNormal end
			start = endpos+pltr.HitNormal*120
			if math.abs(endpos.z-start.z) < 2 then endpos.z = start.z end
			local tracedata = {start=start,endpos=endpos}
			tracedata.filter = pl
			tracedata.mins = Vector(-16,-16,0 )
			tracedata.maxs = Vector( 16, 16,72)
			tracedata.mask = MASK_SHOT_HULL
			local tr = util.TraceHull(tracedata)
			if tr.StartSolid or (wasinworld and not util.IsInWorld(tr.HitPos)) then
				tr = util.TraceHull(tracedata)
				tracedata.start = endpos+pltr.HitNormal*3
			end
			if tr.StartSolid or (wasinworld and not util.IsInWorld(tr.HitPos)) then
				tr = util.TraceHull(tracedata)
				tracedata.start = ply:GetPos()+Vector(0,0,1)
			end
			if tr.StartSolid or (wasinworld and not util.IsInWorld(tr.HitPos)) then
				tr = util.TraceHull(tracedata)
				tracedata.start = endpos+diff
			end
			if tr.StartSolid then return false,"Unable to perform teleportation without getting stuck" end
			if not util.IsInWorld(tr.HitPos) and wasinworld then return false,"Couldn't teleport there" end
			if ply:GetVelocity():Length() > 10*math.sqrt(GetConVarNumber("sv_gravity")) then
				--pl:EmitSound("physics/concrete/boulder_impact_hard".. math.random(1, 4) ..".wav")
				ply:SetVelocity(-ply:GetVelocity())
			end
			ply.xsys_tpprevious = ply:GetPos()
			ply:SetPos(tr.HitPos)
			--pl:EmitSound"ui/freeze_cam.wav"
		end)
		
		xsys.AddCommand("send",function(ply,txt,p,where)
			local who = easylua.FindEntity(p)
			if who:IsPlayer() then
				who.xsys_tpprevious = who:GetPos()
				return Goto(who,"",where:Trim())
			end
			return false,xsys.NoTarget(p)
		end,"designers")
		
		xsys.AddCommand("back",function(ply,line,target)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if not IsValid(ent) then return false, "Invalid player" end
			if not ent.xsys_tpprevious or not type( ent.xsys_tpprevious ) == "Vector" then return false,"Nowhere to return you to" end
			local prev = ent.xsys_tpprevious
			ent.xsys_tpprevious = ent:GetPos()
			ent:SetPos(prev)
			hook.Run("XsysTargetCommand",ply,"back",ent)
		end)

		xsys.AddCommand("bring",function(ply,txt,target,yes)
			local ent = easylua.FindEntity(target)
			if ent:IsValid() and ent ~= ply then
				if ply:CheckUserGroupLevel("designers") or (ply.IsBanned and ply:IsBanned()) then
					if ent:IsPlayer() and not ent:Alive() then ent:Spawn() end
					if ent:IsPlayer() and ent:InVehicle() then ent:ExitVehicle() end
					ent.xsys_tpprevious = ent:GetPos()
					ent:SetPos(ply:GetEyeTrace().HitPos+(ent:IsVehicle() and Vector(0,0,ent:BoundingRadius()) or Vector(0,0,0)))
					ent[ent:IsPlayer() and "SetEyeAngles" or "SetAngles"](ent,(ply:EyePos()-ent:EyePos()):Angle())
					xsys.Notify("bring",tostring(ply).." << "..tostring(ent))
				end
				return
			end
			if IsValid(ent) then
				return false,xsys.NoTarget(target)
			end
		end)
		
		xsys.AddCommand("spawn",function(ply,txt,target)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if ent:IsValid() then
				ent.xsys_tpprevious = ent:GetPos()
				ent:Spawn()
				xsys.Notify("spawn",tostring(ply).." spawned "..(ent==ply and "self" or tostring(ent)))
			end
		end)
		
		xsys.AddCommand("slay",function(ply,txt,target)
			target = target and easylua.FindEntity(target) or nil
			if not target then return false,xsys.NoTarget(target) end
			target:Kill()
		end,"designers")
		
		xsys.AddCommand({"decals","cleardecals"},function(ply,txt)
			local allowed = ply:CheckUserGroupLevel("designers")
			if allowed then
				all:ConCommand("r_cleardecals")
			else
				pl:ConCommand("r_cleardecals")
			end
		end)
		
		xsys.AddCommand("rank",function(ply,txt,target,rank)
			local p = easylua.FindEntity(target)
			if p:IsPlayer() and rank then
				rank = rank:lower():Trim()
				p:SetUserGroup(rank,true)
				hook.Run("XsysTargetCommand",ply,"rank",p,rank)
			end
		end,"owners")
		
		xsys.AddCommand("god",function(ply,txt,target,g)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if not ply:CheckUserGroupLevel(ent:GetUserGroup()) then
				ent = ply
			end
			local newgm = tonumber(target) or (tonumber(g) or (ent:GetInfoNum("cl_godmode",0) == 1 and 0 or 1))
			ent:ConCommand("cl_godmode "..newgm)
		end)

		xsys.AddCommand("gag",function(ply,txt,target,g)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if not ply:CheckUserGroupLevel(ent:GetUserGroup()) then
				ent = ply
			end
			local newgm = tonumber(target) or (tonumber(g) or (ent:GetNWBool("xsys_gagged") and 0 or 1))
			ent:SetNWBool("xsys_gagged",newgm == 1)
		end,"designers")
		
		xsys.AddCommand({"name","nick","setnick","setname","nickname"},function(ply,txt)
			if txt then
				txt = txt:Trim()
				if txt == "" or txt:gsub(" ","") == "" then txt = nil end
				if txt and #txt > 40 then
					if not txt.ulen or txt:ulen() > 40 then
						return false,"my god what are you doing"
					end
				end
			end
			timer.Create("setnick"..ply:UserID(),1,1,function()
				if IsValid(player) then
					ply:SetNick(txt)
				end
			end)
		end)

		xsys.AddCommand("map",function(ply,txt,map)
			if map and file.Exists("maps/"..map..".bsp","GAME") then
				game.ConsoleCommand("changelevel "..map.."\n")
			else
				if all then
					all:ChatPrint("[XSys] Map \""..map.."\" doesn't exist")
				end
			end
		end)

		xsys.AddCommand("maps",function(ply,txt)
			local files = file.Find("maps/"..(txt or ""):gsub("[^%w_]", "").."*.bsp","GAME")
			for k,v in pairs(files) do
				ply:ChatPrint(v)
			end
			
			local msg = "Total maps found: "..#files
			
			ply:ChatPrint(("="):rep(msg:len()))
			ply:ChatPrint(msg)
		end)
		
		xsys.AddCommand({"retry","rejoin"},function(ply,txt,target)
			target = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if not IsValid(target) or not target:IsPlayer() then target = ply end
			target:SendLua("LocalPlayer():ConCommand('retry')")
		end)
		
		xsys.AddCommand("rehash",function(ply,txt,server,repo)
			if not repo then return false,"All repos at once not supported yet" end
			stcp.SendCmd({"rehash",repo},{"git -C /home/steam/srcds/xenora"..server.."/garrysmod/addons/"..repo.." pull"},"gmod.xenora.net",27039)
		end,"developers")

		xsys.AddCommand("kick",function(ply,line,target,reason)
			local ent = easylua.FindEntity(target)
			if ent:IsPlayer() then
				if cleanup and cleanup.CC_Cleanup then cleanup.CC_Cleanup(ent,"gmod_cleanup",{}) end
				local rsn = reason or "*kicked*"
				hook.Run("XsysTargetCommand",ply,"kick",ent,rsn)
				return ent:Kick(rsn or "*kicked*")
			end
			return false,xsys.TargetNotFound(target)
		end,"guardians")
		
		xsys.AddCommand("ban",function(ply,line,target,length,reason)
			if not xsys.xban then return false,"XBan not initialized" end

			local ent = easylua.FindEntity(target)

			if type(target) == "string" and target:find("STEAM_") then
				xsys.xban.BanID(target,ply,length ~= "" and tonumber(length) or nil,false,reason)
			else
				if not IsValid(ent) or not ent:IsPlayer() then return false,xsys.NoTarget(target) end
				xsys.xban.BanID(ent,ply,length ~= "" and tonumber(length) or nil,false,reason)
			end
		end,"guardians")

		xsys.AddCommand("hardban",function(ply,line,target,length,reason)
			if not xsys.xban then return false,"XBan not initialized" end

			local ent = easylua.FindEntity(target)

			if type(target) == "string" and target:find("STEAM_") then
				xsys.xban.BanID(target,ply,length ~= "" and tonumber(length) or nil,true,reason)
			else
				if not IsValid(ent) or not ent:IsPlayer() then return false,xsys.NoTarget(target) end
				xsys.xban.BanID(ent,ply,length ~= "" and tonumber(length) or nil,true,reason)
			end
		end,"overwatch")

		xsys.AddCommand("unban",function(ply,line,target,reason)
			if not xsys.xban then return false,"XBan not initialized" end

			local ent = easylua.FindEntity(target)

			if type(target) == "string" and target:find("STEAM_") then
				xsys.xban.UnbanID(target,ply,reason)
			else
				if not IsValid(ent) or not ent:IsPlayer() then return false,xsys.NoTarget(target) end
				ent:Unban(ply,reason)
			end
		end,"guardians")

		xsys.AddCommand("baninfo",function(ply,line,target)
			local ent = easylua.FindEntity(target)
			if not IsValid(ent) or not ent:IsPlayer() then return false,xsys.NoTarget(target) end
			if not xsys.xban then return false,"XBan not initialized" end

			local ban = xsys.xban.GetBan(ent)

			if not ban then
				all:ChatPrint("[XBan] No ban info on record for: "..ent:Nick())
			else
				all:ChatPrint("[XBan] Ban info for player: "..ent:Nick().." ["..ent:SteamID().."]:")

				all:ChatPrint("\tName: "..ban.NickName.." / "..ban.Name)
				all:ChatPrint("\tSteamID64: "..ban.SteamID64)
				all:ChatPrint("\tRank: "..ban.Rank)
				all:ChatPrint("\tBanner Name: "..ban.BannerNickName.." / "..ban.BannerName)
				all:ChatPrint("\tBanner SteamID: "..ban.BannerSteamID)
				all:ChatPrint("\tBanner SteamID64: "..ban.BannerSteamID64)
				all:ChatPrint("\tBan Reason: "..ban.Reason)
				all:ChatPrint("\tStart Date: "..os.date("%B %d, %Y at %I:%M:%S %p",ban.StartTime))
				all:ChatPrint("\tEnd Date: "..(ban.Length == 0 and "Never" or os.date("%B %d, %Y at %I:%M:%S %p",ban.EndTime)))
				all:ChatPrint("\tBan Length: "..(ban.Length == 0 and "Infinite" or xsys.xban.GetTimeLength(ban.Length+4)))
				all:ChatPrint("\tTime Remaining: "..(ban.Length == 0 and "Infinite" or (ban.Expired and "0" or xsys.xban.GetTimeLength((((os.time()+4)-ban.StartTime)/(ban.EndTime-ban.StartTime))*ban.Length)))
				all:ChatPrint("\tHas Expired: "..tostring(ban.Expired))
				all:ChatPrint("\tHas Been Interrupted: "..tostring(ban.Interrupted))
				all:ChatPrint("\tIs Hard Ban: "..tostring(ban.HardBanned))
				all:ChatPrint("\tBan Number: "..tostring(ban.TimesBanned))
			end
		end,"players")

		xsys.AddCommand("strip",function(ply,line,target,weapon)
			local ent = easylua.FindEntity(target)
			if not IsValid(ent) or not ent:IsPlayer() then ent = ply end
			if weapon then
				ent:StripWeapon(weapon)
			else
				for k,v in pairs(ent:GetWeapons()) do
					if v:GetClass() == "none" then continue end
					ent:StripWeapon(v:GetClass())
				end
			end
		end,"guardians")

		xsys.AddCommand({"drop","disconnect"},function(ply,line,target)
			local ent = easylua.FindEntity(target)
			if not ent then return false,xsys.NoTarget(target) end
			ent:ConCommand("disconnect")
		end,"guardians")

		xsys.AddCommand({"clean","cleanup"},function(ply,line,target)
			local ent = easylua.FindEntity(target)
			if not IsValid(ent) or not ent:IsPlayer() then ent = ply end
			if cleanup and cleanup.CC_Cleanup then 
				cleanup.CC_Cleanup(ent,"gmod_cleanup",{})
			end
		end,"guardians")

		xsys.AddCommand("freeze",function(ply,line,target,freeze)
			local ent = easylua.FindEntity(target)
			if not ent then return false,xsys.NoTarget(target) end
			if freeze then
				ent:Freeze(freeze == "1")
			else
				ent:Freeze(not ent:IsFrozen())
			end
		end,"designers")
		
		local function dow(v,t)
			if not v:IsValid() then return end
			v:StripAmmo()
			v:StripWeapons()
			for kk,vv in pairs(t["data"]) do
				v:Give(kk)
				local w = v:GetWeapon(kk)
				w:SetClip1(vv["clip1"])
				w:SetClip2(vv["clip2"])
				v:SetAmmo(vv["ammo1"],w:GetPrimaryAmmoType())
				v:SetAmmo(vv["ammo2"],w:GetSecondaryAmmoType())
			end
			if t["wep"] then v:SelectWeapon(t["wep"]) end
		end
		
		local function gsd(v)
			local t = {}
			t["health"],t["armor"] = v:Health(),v:Armor()
			if v:GetActiveWeapon():IsValid() then t["wep"] = v:GetActiveWeapon():GetClass() end
			local w,data = v:GetWeapons(),{}
			for kk,vv in ipairs(w) do
				local n = vv:GetClass()
				data[n] = {}
				data[n]["clip1"] = vv:Clip1()
				data[n]["clip2"] = vv:Clip2()
				data[n]["ammo1"] = v:GetAmmoCount(vv:GetPrimaryAmmoType())
				data[n]["ammo2"] = v:GetAmmoCount(vv:GetSecondaryAmmoType())
			end
			t["data"] = data
			return t
		end
		
		local spawndata = {}
		local function pspaw(v,b)
			v:Spawn()
			if b and spawndata[v] then
				local t = spawndata[v]
				v:SetHealth(t["health"])
				v:SetArmor(t["armor"])
				timer.Simple(0.1,function() dow(v,t) end)
				spawndata[v] = nil
			end
		end
		
		local function rag(v)
			if v:InVehicle() then v:ExitVehicle() end
			spawndata[v] = gsd(v)
			local r = ents.Create("prop_ragdoll")
			r.player = v
			r:SetPos(v:GetPos())
			local vel = v:GetVelocity()
			r:SetAngles(v:GetAngles())
			r:SetModel(v:GetModel())
			r:Spawn()
			r:Activate()
			v:SetParent(r)
			v:Spectate(OBS_MODE_CHASE)
			v:SpectateEntity(r)
			v:StripWeapons()
			for k,v in pairs(r:GetPhysicsObjects() or {}) do
				if v and v:IsValid() then v:SetVelocity(vel) end
			end
			v.rag = r
			v.ragstart = CurTime()
		end
		
		local function unrag(v)
			local oea = v:EyeAngles()
			v:SetParent()
			v:UnSpectate()
			local r = v.rag
			v.rag = nil
			if r then
				if not r:IsValid() then
					pspaw(v,true)
				else
					local pos = r:GetPos()
					pos.z = pos.z+10
					pspaw(v,true)
					v:SetPos(pos)
					v:SetVelocity(r:GetVelocity())
					local yaw = r:GetAngles().y
					v:SetEyeAngles(oea)
					r:Remove()
				end
			end
		end
		
		hook.Add("Think","XsysRagdollCheck",function()
			for k,v in pairs(player.GetAll()) do
				if v.rag and not IsValid(v.rag) then v:SetParent(nil) unrag(v) end
			end
		end)
		
		xsys.AddCommand({"rag","ragdoll"},function(ply,txt,target)
			local ent = ply:CheckUserGroupLevel("designers") and target and easylua.FindEntity(target) or ply
			if not ent:IsPlayer() then return false,xsys.NoTarget(target) end
			if ent.rag then unrag(ent) elseif not ent.rag then rag(ent) end
		end)
		
		do -- Restrictions
			xsys.AddCommand({"restrictions"},function(ply,txt,target,bool)
				local ent = easylua.FindEntity(target)
				local restrictions = true
				if bool or target then restrictions = util.tobool(bool or target) end
				ply = bool and ent or ply
				if not IsValid(ply) then return false,"nope" end
				local unrestricted  = not restrictions
				if unrestricted  then
					ErrorNoHalt("Restrictions disabled for "..tostring(ply)..".")
				elseif restrictions then
					ErrorNoHalt("Restrictions enabled for "..tostring(ply)..".")
				end
				ply.Unrestricted = unrestricted
			end,"designers")
		end
	end
end