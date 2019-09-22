module("xlog",package.seeall)

local Tag="XLog"

local ACT_NEXT  = 1
local ACT_PREV  = 2
local ACT_RESET = 3
local ACT_NOP   = 0

local i = 1

local log_verbose_level = CreateConVar("xlog_verbose_level",0)
		
local logFile
local lastday

local SEARCH_MODE
local SEARCH_STR

function SEARCHMODE()
	return SEARCH_MODE and SEARCH_STR and SEARCH_STR ~= ""
end

function Net_SEARCH()
	if not SEARCHMODE() then return end
	net.WriteEntity(LocalPlayer())
	net.WriteString(SEARCH_STR)
end

concommand.Add("logview",function()
	local frame = vgui.Create("DFrame",nil,"logview")
	frame:SetTitle("logview")
	frame:SetSize(1024,ScrH()-100)
	frame:Center()
	frame:SetSizable(true)
	frame:MakePopup()
	local cont = vgui.Create("EditablePanel",frame)
	cont:Dock(TOP)
	net.Start(Tag)
		net.WriteUInt(ACT_NOP,5)
		Net_SEARCH()
	net.SendToServer()
			
	local prev = vgui.Create("DButton",cont)
	prev:Dock(LEFT)
	prev:SetText("PREV")
	prev.DoClick = function(n)
		net.Start(Tag)
			net.WriteUInt(ACT_PREV,5)
			Net_SEARCH()
		net.SendToServer()
	end
		
	local n = vgui.Create("DButton",cont)
	n:Dock(LEFT)
	n:SetText("NEXT")
	n.DoClick = function(n)
		net.Start(Tag)
			net.WriteUInt(ACT_NEXT,5)
			Net_SEARCH()
		net.SendToServer()
	end
		
	local n = vgui.Create("DButton",cont)
	n:Dock(LEFT)
	n:SetText("RESET")
	n.DoClick = function(n)
		SEARCH_MODE = false
		SEARCH_STR  = nil
		net.Start(Tag)
			net.WriteUInt(ACT_RESET,5)
			Net_SEARCH()
		net.SendToServer()
	end
		
	local n = vgui.Create("DButton",cont)
	n:Dock(LEFT)
	n:SetText("SEARCH")
	n.DoClick = function(n)
		if ValidPanel(SEARCH_Panel) then return end
		SEARCH_Panel = Derma_StringRequest("SEARCH","Enter your text to find","",function(txt)
			SEARCH_MODE = true
			SEARCH_STR  = txt
			net.Start(Tag)
				net.WriteUInt(ACT_NOP,5)
				Net_SEARCH()
			net.SendToServer()
		end,function(txt)
			SEARCH_MODE = false
			SEARCH_STR  = nil
			net.Start(Tag)
				net.WriteUInt(ACT_NOP,5)
			net.SendToServer()
			return false
		end,"SEARCH Enable","SEARCH Disable")
	end
		
	local txt = vgui.Create("RichText",frame)
	txt:Dock(FILL)

	net.Receive(Tag,function(l,p)
		local date = net.ReadUInt(32)
		frame:SetTitle("[Log]  "..string.Left(date,2).."-"..string.Right(string.Left(date,4),2).."-"..string.Right(string.Left(date,6),2).."  ["..string.Right(date,3).."] "..(SEARCHMODE() and "SEARCH : "..SEARCH_STR or ""))
		
		local data = net.ReadString()
		if not txt or not txt:IsValid() then
			return
		end

		txt:SetText("")

		for line in data:gmatch("[^\n]+") do
			local a,b,c = line:match('(%[.-%] )(%[.-%])(.+)')
			if a and b and c then
				txt:InsertColorChange(120,50,120,255)
				txt:AppendText(a)
				txt:InsertColorChange(120,50,25,255)
				txt:AppendText(b)
				txt:InsertColorChange(60,60,60,255)
				txt:AppendText(c..'\n')
			else
				local a,b = line:match('(%[.-%] )(.+)')
				if a and b then
					txt:InsertColorChange(120,50,120,255)
					txt:AppendText(a)
					txt:InsertColorChange(60,60,60,255)
					txt:AppendText(b..'\n')
				else
					txt:InsertColorChange(60,60,60,255)
					txt:AppendText(line..'\n')
				end
			end
		end
	end)

	txt:SetFontInternal("DefaultFixedDropShadow")
	txt.Paint = function(txt,w,h)
		surface.SetDrawColor(200,200,200,255)
		surface.DrawRect(0,0,w,h)
	end

	net.Start(Tag)
		net.WriteUInt(ACT_RESET,5)
		Net_SEARCH()
	net.SendToServer()
end)