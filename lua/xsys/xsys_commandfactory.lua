xsys.InternalCommand = function(ply,unused,args,txt)
	if xsys.cmds[args[1]] then
		local c = args[1]
		table.remove(args,1)
		_G.XCMD = true
		xsys.CallCommand(ply,c,table.concat(args," "),args)
		_G.XCMD = nil
	end
end

xsys.CommandAutocomplete = function(cmd,args)
	local tab = {}
	for k,v in pairs(xsys.cmds) do
		table.insert(tab,"xsys "..k)
	end
	return tab
end

xsys.SayCommand = function(ply,txt)
	if txt:sub(1,1):find(xsys.StringPatterns.Prefix) then
		local c = (txt:match(xsys.StringPatterns.Prefix.."(.-) ") or txt:match(xsys.StringPatterns.Prefix.."(.+)") or ""):lower()
		local l = txt:match(xsys.StringPatterns.Prefix..".- (.+)")
		if xsys.cmds[c] then
			_G.XCHAT = true
			xsys.CallCommand(ply,c,l,l and xsys.ParseString(l) or {})
			_G.XCHAT = nil
		end
	end
end

if SERVER then
	concommand.Add("xsys",xsys.InternalCommand,xsys.CommandAutocomplete,"Controlling XSYS")
	hook.Add("PlayerSay","XsysPlayerSayCommand",xsys.SayCommand)
end