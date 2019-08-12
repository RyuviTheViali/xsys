local function ChatPrint(printconsole,msg,a)
	if printconsole then
		Msg("> ")
		print(msg,a or "")
	end
	for k,v in pairs(player.GetHumans()) do
		v:ChatPrint(msg..(a and " "..a or ""))
	end
end

hook.Add("stcp","addonupdate",function(header,body,addr)
	if header[1] == "rehash" and header[2] == "success" then
		ChatPrint(false,[[STCP >> Updating Repo ]]..(header[3])..[[...]])
		return stcp.FormatMsg({header[1],"retrieved",header[3]},{""})
	end
	if header[1] == "rehashfin" then
		ChatPrint(false,[[STCP >> Repo update finished]])
		ChatPrint(false,[[---------------------------]])
		local lines = body
		for k,v in pairs(lines) do
			ChatPrint(false," > "..v)
			if v:match("([^\\/]+%.lua)") then
				if v:find("server/") then
					include(v:match("/(.+%.lua)"))
				end
				if v:find("client/") then
					all:SendLua([[include("]]..v:match("/(.+%.lua)")..[[")]])
					AddCSLuaFile(v:match("/(.+%.lua)"))
				end
				if not v:find("client/") and not v:find("server/") then
					include(v:match("/(.+%.lua)"))
					AddCSLuaFile(v:match("/(.+%.lua)"))
				end
			end
		end
		return stcp.FormatMsg({header[1],"finished",header[3]},{""})
	end
end)