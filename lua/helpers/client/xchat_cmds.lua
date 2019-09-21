if SERVER then return end

local ULib = {}
function ULib.explode(separator,str,limit )
	local t = {}
	local curpos = 1
	while true do
		local newpos,endpos = str:find(separator,curpos)
		if newpos ~= nil then
			table.insert(t,str:sub(curpos,newpos-1))
			curpos = endpos+1
		else
			if limit and table.getn(t) > limit then return t end
			table.insert(t,str:sub(curpos))
			break
		end
	end
	return t
end

function ULib.splitArgs(args,start_token,end_token)
	args = args:Trim()
	local argv = {}
	local curpos = 1
	local in_quote = false
	start_token = start_token or "\""
	end_token = end_token or "\""
	local args_len = args:len()
	while in_quote or curpos <= args_len do
		local quotepos = args:find(in_quote and end_token or start_token,curpos,true)
		local prefix = args:sub(curpos,(quotepos or 0)-1)
		if not in_quote then
			local trimmed = prefix:Trim()
			if trimmed ~= "" then
				local t = ULib.explode("%s+",trimmed)
				table.Add(argv,t)
			end
		else
			table.insert(argv,prefix)
		end
		if quotepos ~= nil then
			curpos = quotepos+1
			in_quote = not in_quote
		else
			break
		end
	end
	return argv,in_quote
end

local preventing = true
local cmds = {["!"]=true,["\\"]=true,["/"]=true,["."]=true}
local function PreventChatsounds(cmd)
	if not cmds[cmd:sub(1,1)] then
		preventing = false
		return
	end
	preventing = true
end

hook.Add("PreChatSound","stopitcmd",function(s)
	if preventing then return false end
end)

local LocalPlayer = LocalPlayer
local disable_legacy
local function Parse(pl,msg)
	if not cmds[msg:sub(1,1)] then return end
	local pos = string.find(msg," ",1,true)
	local com,paramstr
	if pos then
		com,paramstr = msg:sub(2,pos-1),msg:sub(pos+1,-1)
	else
		com = msg:sub(2,-1)
		paramstr = ""
	end
	return hook.Call("ChatCommand",nil,com,paramstr,msg,pl)
end
 
hook.Add("OnPlayerChat","AAChatCommand",function(ply,msg,tm,d)
	if preventing == false then preventing = true end
	PreventChatsounds(msg)
	if ply == LocalPlayer() then Parse(ply,msg) end
	ChathudImage(msg)
	return hook.Call("OnChatSyntaxParse",nil,ply,msg,tm,d)
end)

local function url_encode(str)
	if str then
		str = string.gsub(str,"\n","\r\n")
		str = string.gsub(str,"([^%w ])", function (c) return string.format("%%%02X",string.byte(c)) end)
		str = string.gsub(str," ","+")
	end
	return str
end

local C = {cs=true}

hook.Add("ChatCommand","copysound",function(com,paramstr,msg)
	if not C[com:lower()] then return end
	local dat = chatsounds.GetSound(paramstr)
	local txt = dat and dat.path
	if not txt then LocalPlayer():PrintMessage(3,"Not found") return end
	LocalPlayer():PrintMessage(3,"Copied "..txt)
	local snd = CreateSound(LocalPlayer(),txt)
	timer.Simple(1,function()
		snd:PlayEx(100,100)
		timer.Simple(2,function() if snd:IsPlaying() then snd:Stop(1) end end)
	end)
	SetClipboardText(txt)
	return true
end)

hook.Add("ChatCommand","cmd",function(com,paramstr,msg)
	if com:lower() ~= "cmd" then return end
	local t = ULib.splitArgs(paramstr)
	if not t or table.Count(t) == 0 then return end
	RunConsoleCommand(unpack(t))
end)

hook.Add("ChatCommand","ignorepac",function(com,paramstr,msg)
	if com:lower() ~= "ignorepac" then return end
	local ent = easylua.FindEntity(paramstr)
	if pac.IgnoreEntity then pac.IgnoreEntity(ent) end
end)

hook.Add("ChatCommand","unignorepac",function(com,paramstr,msg)
	if com:lower() ~= "unignorepac" then return end
	local ent = easylua.FindEntity(paramstr)
	if pac.UnIgnoreEntity then pac.UnIgnoreEntity(ent) end
end)

local lcmds = {
	["say"]    = function(s,e)
		if not LocalPlayer():CheckUserGroupLevel("developers") then return end
		luadev.RunOnSelf("Say("..s..")",nil,e)
	end,
	["name"]   = function(s,e) LocalPlayer():ConCommand([[xsys name "s"]]) end,
	["f"]      = function(s,e,p)
		if not LocalPlayer():CheckUserGroupLevel("developers") then return end
		local n = string.Explode(",",s)
		local f = table.Copy(n)
		table.remove(f,1)
		if #n == 1 then
			luadev.RunOnServer([[_]]..tonumber(p:EntIndex())..[[:GetEyeTrace().Entity:Fire("]]..s..[[")]],nil,e)
		else
			luadev.RunOnServer([[easylua.FindEntity("]]..tostring(n[1])..[["):Fire("]]..table.concat(f," ")..[[")]],nil,e)
		end
	end
}

hook.Add("ChatCommand","luadev cmds",function(com,paramstr,msg,ply)
	if lcmds[com:lower()] then
		lcmds[com:lower()](paramstr,LocalPlayer(),ply)
	end
end)

hook.Add("ChatCommand","cexec",function(com,paramstr,msg)
	if not LocalPlayer():CheckUserGroupLevel("developers") then return end
	if not (com:lower() == "cexec" or com:lower() == "cx") then return end

	local ply,cmd = unpack(string.Explode(",",paramstr))

	xsys.CallCommand(LocalPlayer(),"cexec",paramstr,{ply,cmd})
end)

hook.Add("ChatCommand","attribute",function(com,paramstr,msg)
	if not LocalPlayer():CheckUserGroupLevel("developers") then return end
	if not (com:lower() == "a" or com:lower() == "attr" or com:lower() == "attribute") then return end

	local dat = string.Explode(",",paramstr)
	local target = dat[1]
	local attribute = dat[2]
	local value = dat[3]

	xsys.CallCommand(LocalPlayer(),"attribute",paramstr,{target,attribute,value})
end)