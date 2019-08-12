local function FindPlayer(name,self)
	if not isstring(name) then return end
	if name == "#me" then return self end
	for k,v in pairs(player.GetAll()) do
		if string.find(string.lower(v:Nick()),string.lower(name),1,true) then
			return v
		end
	end
end

local function IsPlayer(ply)
	return type(ply) == "Player"
end

local function Option(var,def)
	if var ~= nil then return var
	else return def end
end

local green = Color(100,200,100)
local lgray = Color(240,240,240)
local gray = Color(191,191,191)
local enabled = CreateClientConVar("chat_formatting","1",true)

local ccf = {}
ccf.cmds = {}

function ccf:AddCommand(data)
	if not istable(data) then return end
	if not data.command then return end
	if isstring(data.command) then
		self.cmds[data.command] = data
	elseif istable(data.command) then
		for _,cmd in next, data.command do
			if isstring(cmd) then
				self.cmds[cmd] = table.Copy(data)
				self.cmds[cmd].command = cmd
			end
		end
	end
end

local PLACEHOLDER_PARAMETERS = 0xFA10
hook.Add("OnPlayerChat","chatcommands-style",function(player,message,team,dead)
	if not enabled:GetBool() then return end
	if not IsValid(player) then return end
	local command = message:lower():match("^[!./](%w*)")
	if not command or not ccf.cmds[command] then return end
	local IsLocalPlayer = player == LocalPlayer()
	local IsAdmin = player:IsAdmin()
	local parameters,HasParameters
	local cdata = ccf.cmds[command]
	local HideChatPrint = true
	if isbool(cdata.HideChatPrint) then
		if not cdata.HideChatPrint then HideChatPrint = nil end
	end
	local HideOwnChatPrint = true
	if isbool(cdata.HideOwnChatPrint) then
		if not cdata.HideOwnChatPrint then HideOwnChatPrint = nil end
	end
	if not istable(cdata.InfoText) or (istable(cdata.InfoText) and #cdata.InfoText == 0) then
		if not isfunction(cdata.ParameterHandler) then error("PrintData Error: No InfoText and no ParameterHandler!") end
	end
	local InfoText = table.Copy(cdata.InfoText)
	local SelfInfoText = cdata.SelfInfoText
	local PlayerCanUse = Option(cdata.PlayerCanUse,true)
	local AdminCanUse = Option(cdata.AdminCanUse,true)
	local NeedsParameters = Option(cdata.NeedsParameters,false)
	local CanUseParameters = NeedsParameters or Option(cdata.CanUseParameters,false)
	local ParameterIsPlayer = false
	if CanUseParameters then ParameterIsPlayer = Option(cdata.ParameterIsPlayer,false) end
	local NeedsTarget = Option(cdata.NeedsTarget,false)
	local ParameterHandler = cdata.ParameterHandler
	local Parameter = {}
	if ParameterIsPlayer then
		Parameter.PlayerOnPlayer        = Option(cdata.PlayerOnPlayer,false)
		Parameter.AdminOnPlayer         = Option(cdata.AdminOnPlayer,true)
		Parameter.AdminOnAdmin          = Option(cdata.AdminOnAdmin,true)
		Parameter.PlayerOnSelf          = Option(cdata.PlayerOnSelf,true)
		Parameter.AdminOnSelf           = Option(cdata.AdminOnSelf,true)
		Parameter.UnallowedTargetIsSelf = Option(cdata.UnallowedTargetIsSelf,false)
		Parameter.InvalidTargetIsSelf   = Option(cdata.InvalidTargetIsSelf,false)
		Parameter.NoTargetIsSelf        = Option(cdata.NoTargetIsSelf,false)
	end
	if string.sub(message,string.len(command)+2,string.len(command)+2) == " " then
		parameters = string.sub(message,string.len(command)+3)
		HasParameters = string.len(parameters) > 0
	else
		parameters = ""
		HasParameters = nil
	end
	local info = {}
	if not PlayerCanUse and not IsAdmin then return end
	if not AdminCanUse and IsAdmin then return end
	if NeedsParameters and not HasParameters then return end
	if isfunction(ParameterHandler) then
		local success = nil
		success,info = ParameterHandler(player,parameters,FindPlayer(parameters,player))
		if not success then return end
		if not istable(info) then return end
	elseif CanUseParameters then
		local Target = nil
		if ParameterIsPlayer then
			if HasParameters then
				Target = FindPlayer(parameters,player)
			elseif Parameter.NoTargetIsSelf then
				Target = player
			end
			if not IsValid(Target) then
				if Parameter.InvalidTargetIsSelf then Target = player end
			end
			if IsValid(Target) then
				local TargetIsUnallowed = false
				local TargetIsAdmin = Target:IsAdmin()
				local TargetIsSelf = Target == player
				if not IsAdmin then
					if not Parameter.PlayerOnSelf and TargetIsSelf then TargetIsUnallowed = true end
					if not Parameter.PlayerOnPlayer and not TargetIsSelf then TargetIsUnallowed = true end
				else
					if not Parameter.AdminOnSelf and TargetIsSelf then TargetIsUnallowed = true end
					if not Parameter.AdminOnPlayer and not TargetIsAdmin then TargetIsUnallowed = true end
					if not Parameter.AdminOnAdmin and TargetIsAdmin then TargetIsUnallowed = true end
				end
				if TargetIsUnallowed and Parameter.UnallowedTargetIsSelf then
					Target = player
				elseif TargetIsUnallowed then
					Target = nil
				end
			end
			if NeedsTarget and not IsValid(Target) then return end
			if Target == player and isstring(SelfInfoText) then
				info = {SelfInfoText}
			else
				info = InfoText
				for key,inf in next,info do
					if inf == PLACEHOLDER_PARAMETERS then info[key] = Target end
				end
			end
		else
			info = InfoText
			for key,inf in next,info do
				if inf == PLACEHOLDER_PARAMETERS then info[key] = parameters end
			end
		end
	else
		info = InfoText
	end
	for key,inf in next,info do
		if inf == player then
			info[key] = green
			table.insert(info,key+1,"themself")
		end
	end
	local data = {player,gray,unpack(info)}
	chat.AddText(unpack(data))
	if player == LocalPlayer() then
		return HideOwnChatPrint
	else
		return HideChatPrint
	end
end)

ccf:AddCommand({command = "tp",InfoText = {" teleported"}})
ccf:AddCommand({command = {"die","kill","suicide"},InfoText = {" commited suicide"}})
ccf:AddCommand({
	command = "spawn",
	CanUseParameters = true,
	ParameterIsPlayer = true,
	UnallowedTargetIsSelf = true,
	NeedsTarget = true,
	NoTargetIsSelf = true,
	SelfInfoText = " respawned",
	InfoText = {" respawned ",PLACEHOLDER_PARAMETERS,gray}
})
ccf:AddCommand({
	command = "bring",
	NeedsParameters = true,
	ParameterIsPlayer = true,
	NeedsTarget = true,
	PlayerOnSelf = false,
	AdminOnSelf = false,
	InfoText = {" brought ",PLACEHOLDER_PARAMETERS,gray}
})
ccf:AddCommand({
	command = {"revive","respawn"},
	CanUseParameters = true,
	ParameterIsPlayer = true,
	NeedsTarget = true,
	UnallowedTargetIsSelf = true,
	NoTargetIsSelf = true,
	InfoText = {" revived ",PLACEHOLDER_PARAMETERS,gray}
})
ccf:AddCommand({
	command = "back",
	CanUseParameters = true,
	ParameterIsPlayer = true,
	UnallowedTargetIsSelf = true,
	NeedsTarget = true,
	NoTargetIsSelf = true,
	InfoText = {" teleported back"}
})

local function GotoFormat(player,input,target)
	local IsGotoLocation = false
	if xsys.Data.Locations then
		for k,v in pairs(xsys.Data.Locations) do
			local loc,map = k:match("(.*)@(.*)")
			if input == k or (map and loc == input and string.find(game.GetMap(),"^"..map)) then
				IsGotoLocation = true
			end
		end
	end
	if IsGotoLocation then
		return true,{" has gone to ",green,input,gray}
	elseif IsValid(target) and target ~= player then
		return true,{" has gone to ",target,gray}
	else
		return true,{" has gone to ",lgray,target,gray}
	end
end
ccf:AddCommand({
	command = {"goto","go"},
	ParameterHandler  = GotoFormat,
	NeedsParameters = true
})

local function RestrictionParameters(p,i,t)
	if t and IsValid(t) then
		local isres = p.Unrestricted
		if isres ~= nil then
			return true,{" has ",green,(not isres) and "enabled" or "disabled",grey," restrictions for ",t == p and "themselves" or t,grey}
		end
	else
		return true,{" has ",green,(not isres) and "enabled" or "disabled",grey," restrictions for themselves",grey}
	end
end

ccf:AddCommand({
	command = "restrictions",
	UnallowedTargetIsSelf = true,
	NeedsTarget = true,
	NoTargetIsSelf = true,
	ParameterHandler = RestrictionParameters
})

local function SendFormat(player,input,target)
	local parameters = string.Split(input,",")
	input = parameters[2]
	local target = FindPlayer(parameters[2],player)
	local traveller = FindPlayer(parameters[1],player) or parameters[1]
	local IsGotoLocation = false
	if xsys.Data.Locations then
		for k,v in pairs(xsys.Data.Locations) do
			local loc,map = k:match("(.*)@(.*)")
			if input == k or (map and loc == input and string.find(game.GetMap(),"^"..map)) then
				IsGotoLocation = true
			end
		end
	end
	if IsGotoLocation then
		return true,{" sent ",lgray,traveller,gray," to ",green,input,gray}
	elseif IsValid(target) and target ~= traveller then
		return true,{" sent ",lgray,traveller,gray," to ",target,gray}
	else
		return true,{" sent ",lgray,traveller,gray," to ",lgray,input,gray}
	end
end

ccf:AddCommand({
	command = "send",
	ParameterHandler  = SendFormat,
	NeedsParameters = true,
	PlayerCanUse = false
})