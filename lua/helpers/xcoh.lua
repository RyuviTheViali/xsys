local tag = "coh"

module(tag,package.seeall)

Enums = {
	Typing = 1,
	EndTyping = 2,
	Data = 3,
	AppendData = 4,
	Local = 5
}

function Msg(...)
	_G.Msg("[XCOH] ")
	print(...)
end

local cdata = rawget(_M,"cdata") or {}
_M.cdata = cdata

function ReinitPlayer(ply)
	if ply:IsPlayer() then cdata[ply] = nil end
end

local tr = {}
function CanSee(a,b,dist)
	if not IsValid(a) then Msg("[CanSee]: First entity invalid")  return false end
	if not IsValid(b) then Msg("[CanSee]: Second entity invalid") return false end
	dist = dist or 1024
	local d = a:GetPos():Distance(b:GetPos())
	if d > dist then return false end
	if SERVER then
		if not a:Visible(b) then return false end
	end
	tr.start,tr.endpos = a:GetShootPos(),b:GetShootPos()
	tr.filter,tr.mask  = a,MASK_VISIBLE
	if util.TraceLine(tr).HitWorld then return false end
	return true
end

function CanAppend(old,new)
	if old == new then return "" end
	local len = #old
	local can = new:sub(1,len) == old
	if can then
		local ret = true
		ret = new:sub(len+1,-1)
		return ret
	end
	return false
end

if SERVER then
	util.AddNetworkString(tag)
	function GetVisiblePlayers(ply,dist)
		local vis = {}
		for k,v in pairs(player.GetAll()) do
			if v ~= ply and CanSee(ply,v,dist) then
				if v:GetInfoNum(tag.."_enabled",0) ~= 0 then
					table.insert(vis,v)
				end
			end
		end
		return vis
	end

	function RelayMessage(ply,mtype,msg)
		if mtype == Enums.Data then
			local pls = GetVisiblePlayers(ply)
			net.Send(pls)
			WriteMessage(ply,Enums.Local)
		elseif mtype == Enums.Local then
			net.Send(ply)
		elseif mtype == Enums.Typing or mtype == Enums.EndTyping then
			net.SendOmit(ply)
		else
			Msg("Invalid message type: "..tostring(mtype))
		end
	end
end

if CLIENT then
	local enabled  = CreateClientConVar(tag.."_enabled" ,"1",true,true)
	local drawself = CreateClientConVar(tag.."_drawself","0",true,true)

	local lp = nil

	hook.Add("NetworkEntityCreated",tag,ReinitPlayer)
	hook.Add("EntityRemoved"       ,tag,ReinitPlayer)

	local ang = Angle(0,0,90)
	local mindist,maxdist = 512,768
	mindist,maxdist = mindist*mindist,maxdist*maxdist

	function DrawMsg(ply,msg,pos,t)
		if msg == true then msg = "" end
		local distance = ply:GetPos():DistToSqr(pos)
		local alpha = 255
		if distance > mindist then
			alpha = alpha-((distance-mindist)/(maxdist-mindist))*255
		end
		if alpha <= 1 then return end
		local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
		local pos = bone and ply:GetBonePosition(bone)
		pos = pos or ply:GetShootPos()
		pos = pos+ply:GetUp()*8+ply:GetForward()*4
		surface.SetFont("Default")
		if msg ~= ply.XCohLastMsg or not ply.XCohCachedMsgData then
			local d = {lines = {}}
			local x,y,w,h = 0,0,0,0
			if ply.XCohSplitMsg and #ply.XCohSplitMsg > 1 then
				if not ply.XCohTextHeight then
					local ww,hh = surface.GetTextSize("W")
					ply.XCohTextHeight = hh*table.Count(ply.XCohSplitMsg)/2
				end
				for k,v in pairs(ply.XCohSplitMsg) do
					local ww = surface.GetTextSize(v)
					w = ww > w and ww or w
				end
				h = ply.XCohTextHeight
			else
				w,h = surface.GetTextSize(msg)
			end
			w,h = w+4,h > 20 and h*2 or h
			d.x,d.y,d.w = x,y,w
			local lines = string.Explode("\n",msg)
			local max = #lines
			for k,v in pairs(lines) do
				if v == "" then v = " " end
				d.lines[k] = {s=v,x=x,y=y}
				if max > 1 and k ~= max then
					local ww,hh = surface.GetTextSize(v)
					y = y+hh
				end
			end
			local scale = 1
			if msg == "" then
				msg = "["..("."):rep(math.floor(t*2)%4).."]"
				w,h = surface.GetTextSize(msg)
			elseif h > 50 then
				y = y-h
				scale = math.min(w/h,1)
			end
			d.h,d.scale = h+y+(#lines >= 2 and 14 or 0),scale
			ply.XCohCachedMsgData,ply.XCohLastMsg = d,msg
		end
		local d = ply.XCohCachedMsgData
		local x,y,w,h,scale = d.x,d.y,d.w,d.h,d.scale
		local trace

		local finalang = ply:EyeAngles()
		local forward = finalang:Forward()
		local delta = (lp:GetPos()-pos):GetNormalized()
		local dot = forward:Dot(delta)
		local dx = 15

		ang.y = ply:EyeAngles().y+90
		if dot < 0 then
			ang.y = ang.y-180
			dx = w+4
		end
		cam.Start3D2D(pos,ang,0.15*scale)
			surface.SetDrawColor(0,0,0,alpha)
			surface.DrawRect(x-dx-2,y-h,w,h)
			surface.SetTextColor(255,255,255,alpha)
			for k,v in pairs(d.lines) do
				surface.SetTextPos(v.x-dx,v.y-h)
				surface.DrawText(v.s)
			end
		cam.End3D2D()
		draw.RoundedBox(0,0,0,0,0,Color(0,0,0))
	end

	istyping = false
	function StartChat()
		if not enabled:GetBool() then return end
		if not istyping then istyping = true elseif istyping then return end
		WriteMessage(nil,Enums.Typing)
		lasttxt = false
		textqueue = false
	end
	hook.Add("StartChat",tag,StartChat)

	function FinishChat()
		if istyping then istyping = false elseif not istyping then return end
		WriteMessage(nil,Enums.EndTyping)
		lasttxt = false
		textqueue = false
	end
	hook.Add("FinishChat",tag,FinishChat)

	function ChatTextChanged(msg)
		if not istyping then return end
		SendTypedMessage(msg)
	end
	hook.Add("ChatTextChanged",tag,ChatTextChanged)

	local function suppressframes()
		local lfra,cfra,cfrac = 0,0,0
		return function()
			local f = FrameNumber()
			if f == lfra then
				cfra = cfra+1
			else
				lfra = f	
				if cfrac ~= cfra then cfrac = cfra end
				cfra = 1
			end
			return cfra < cfrac
		end
	end

	local suppress = suppressframes()
	function PostDrawTranslucentRenderables()
		cam.Start3D()		
			if not enabled:GetBool() then return end
			if suppress() then return end
			lp = lp or LocalPlayer()
			local q = {}
			for k,v in pairs(cdata) do
				if CanSee(lp,k) then
					if k ~= lp or drawself:GetBool() then q[#q+1] = k end
				end
			end
			local cpos,t = lp:EyePos(),RealTime()
			table.sort(q,function(a,b) return cpos:Distance(a:GetPos()) > cpos:Distance(b:GetPos()) end)
			for k,v in ipairs(q) do
				local msg = cdata[v]
				cam.IgnoreZ(true)
					DrawMsg(v,msg,cpos,t)
				cam.IgnoreZ(false)
			end
		cam.End3D()
	end
	hook.Add("PostDrawEffects",tag,PostDrawTranslucentRenderables)
end

waiting,lasttxt,textqueue = false,false,false
function SendTypedMessage(msg)
	if msg == true then
		waiting = false
		if not lasttxt then
			cdata[LocalPlayer()] = nil
		else
			cdata[LocalPlayer()] = lasttxt
		end
		if textqueue then
			assert(textqueue ~= true,"internal failure")
			SendTypedMessage(textqueue)
		end
		return
	end
	if waiting then textqueue = msg return end
	local append = isstring(lasttxt) and isstring(mag) and CanAppend(lasttxt,msg)
	lasttxt = msg
	assert(isstring(msg),"msg is not text: "..tostring(msg))
	textqueue = false
	local tosend = append and append or msg
	WriteMessage(nil,append and Enums.AppendData or Enums.Data,tosend)
	if #msg <= 256 then waiting = false else waiting = true end
	return
end

function GotMessage(ply)
	if CLIENT then
		ply = net.ReadEntity(ply)
		if not IsValid(ply) then return end
	end
	local mtype = net.ReadUInt(8)
	local msg
	if mtype == Enums.Typing then
		cdata[ply] = true
	elseif mtype == Enums.EndTyping then
		cdata[ply] = nil
	elseif mtype == Enums.Data or mtype == Enums.AppendData then
		msg = net.ReadString()
		assert(isstring(msg))
		local oldmsg = cdata[ply]
		if oldmsg then cdata[ply] = msg end
	elseif mtype == Enums.Local then
		assert(ply == LocalPlayer(),"Player is not local player")
		SendTypedMessage(true)
	else
		ErrorNoHalt("[XCOH]: Invalid message type"..mtype..'\n')
		return
	end
	if SERVER then WriteMessage(ply,mtype,msg) end
end

function WriteMessage(ply,mtype,msg)
	net.Start(tag)
	if SERVER then net.WriteEntity(ply) end
	net.WriteUInt(mtype,8)
	if mtype == Enums.Data or mtype == Enums.AppendData then
		msg = msg:sub(1,64*1024-64)
		net.WriteString(msg)
	else
		assert(not msg,"Attempting to write data in a non-data-type message")
	end
	if CLIENT then return net.SendToServer() end
	RelayMessage(ply,mtype,msg)
end
net.Receive(tag,function(len,ply) GotMessage(ply) end)