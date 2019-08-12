local Tag = "xcppi"
module(Tag,package.seeall)

net.Receive(Tag,function()
	local c = tobool(net.ReadBit())
	if c then
		local i = net.ReadDouble()
		if i == 1 then
			for k,v in pairs(ents.GetAll()) do
				v.___owner = nil
			end
			Msg("[XPP] ")
			print("Reset all entity ownership data")
		end
		return
	end
	local e,id = net.ReadEntity(), net.ReadDouble()
	e.___owner = id
end)

local function ReceiveOwner(e)
	assert(e:EntIndex() > 0,"invalid entity index")
	if e.___owner then return end
	e.___owner = true
	net.Start(Tag)
		net.WriteEntity(e)
	net.SendToServer()
end

FindMetaTable("Entity").CPPIGetOwner = function(ent)
	if not IsValid(ent) then return end
	if not ent.___owner then return ReceiveOwner(ent) end
	if ent.___owner == true then return end
	if ent.___owner < 1 then return NULL end
	local ownerpl
	for k,v in next,player.GetAll() do
		if ent.___owner == v:UserID() then
			ownerpl = v
			break
		end
	end
	return ownerpl
end

local xcppi_showmode = CreateClientConVar("xcppi_showmode","1",true)
hook.Add("Think",Tag,function()
	local mode = xcppi_showmode:GetInt()
	if mode == 0 then return end
	vec = nil
	local lp = LocalPlayer()
	local e = lp:GetEyeTrace().Entity
	if not IsValid(e) or e:IsWorld() or e:IsPlayer() then return end
	local userid = e.___owner
	if userid and userid == true then
		userid = false
	elseif not userid then
		ReceiveOwner(e)
		return
	end
	local iown = userid == lp:UserID()
	arefriends = nil
	if userid and not iown then
		for k,v in pairs(player.GetAll()) do
			if v:UserID() == userid then
				arefriends = lp:AreFriends(v) and true or false
				break
			end
		end
	end
	if e.___owner == true then return end
	local ownr = tonumber(e.___owner)
	local Now = RealTime()
	local lastshow = e.___lastshow or Now
	e.___lastshow = Now
	local st = e.___showntime or 0
	noannoy = false
	if Now-lastshow > 120 then st = 0 end
	if st > 2.5 then noannoy=true end
	st = st+FrameTime()
	e.___showntime = st
	if ownr and ownr < 0 then return end
	vec = mode == 2 and e:LocalToWorld(e:OBBCenter())
	local plname = userid == 0 and "World" or userid and player.UserIDToName(userid) or "Unknown player"     .." ("..tostring(e.___owner)..")"
	txt = plname
	time = Now
end)