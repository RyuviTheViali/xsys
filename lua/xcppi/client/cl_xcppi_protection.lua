module("xcppi",package.seeall)
local Tag="prop_owner_protect"

local propprotect_disable =  CreateClientConVar("propprotect_disable","0",false,true)
local propprotect_physgunning =  CreateClientConVar("propprotect_physgunning","0",true,true)
local propprotect_unrestrictme =  CreateClientConVar("propprotect_unrestrictme","0",true,true)
local propprotect_hate_everyone =  CreateClientConVar("propprotect_hate_everyone","0",true,true)
local propprotect_hate_self =  CreateClientConVar("propprotect_hate_self","0",false,true)
local propprotect_restrictme =  CreateClientConVar("propprotect_restrictme","0",false,true)

local function cmd(_,cmdname,args,str)
	RunConsoleCommand("cmd",cmdname,args[1])
end
local function cmdautocomplete(_,str)
	local str=str:sub(2,-1)
	if str:find" " then return end
	local t={}
	for k,v in pairs(player.GetAll()) do
		table.insert(t,_..' '..v:UserID()..' - '..v:Name())
	end
	return t
end
concommand.Add("cleanup_player",cmd,cmdautocomplete)