
syntax = {}
local syntax = syntax
syntax.DEFAULT    = 1
syntax.KEYWORD    = 2
syntax.IDENTIFIER = 3
syntax.STRING     = 4
syntax.NUMBER     = 5
syntax.OPERATOR   = 6
syntax.types = {
	"default",
	"keyword",
	"identifier",
	"string",
	"number",
	"operator",
	"ccomment",
	"cmulticomment",
	"comment",
	"multicomment",
	"luadevspecial"
}
syntax.patterns = {
	[2]  = "(_%d+)",
	[3]  = "([%a_][%w_]*)",
	[5]  = "(\".-\")",
	[6]  = "([%d]+%.?%d*)",
	[7]  = "([%+%-%*/%%%(%)%.,<>~=#:;{}%[%]])",
	[8]  = "(//[^\n]*)",
	[9]  = "(/%*.-%*/)",
	[10] = "(%-%-[^%[][^\n]*)",
	[11] = "(%-%-%[%[.-%]%])",
	[12] = "(%[%[.-%]%])",
	[13] = "('.-')",
	[14] = "(!+)",
}
syntax.colors = {
	Color(255,255,255), -- default 1
	Color(153,127,255), -- luadev special 2
	Color(65 ,105,225), -- keyword 3
	Color(180,225,180), -- identifier 4
	Color(170,170,170), -- string 5
	Color(244,164,96 ), -- number 6
	Color(255,255,255), -- operator 7
	Color(34 ,139,34 ), -- ccomment 8
	Color(34 ,139,34 ), -- cmulticomment 9
	Color(34 ,139,34 ), -- comment 10
	Color(34 ,139,34 ), -- multicomment 11 
	Color(255,255,255), -- operators? 12
	Color(255,99 ,71 ), -- unknown 13
	Color(255,99 ,71 ) -- bad character 14
}

syntax.keywords = {
	["local"]    = true,
	["function"] = true,
	["return"]   = true,
	["break"]    = true,
	["continue"] = true,
	["end"]      = true,
	["if"]       = true,
	["not"]      = true,
	["while"]    = true,
	["for"]      = true,
	["repeat"]   = true,
	["until"]    = true,
	["do"]       = true,
	["then"]     = true,
	["true"]     = true,
	["false"]    = true,
	["nil"]      = true,
	["in"]       = true
}

syntax.luadevspecials = {
	["me"] = true,
	["this"] = true,
	["there"] = true,
	["wep"] = true,
	["all"] = true,
	["bots"] = true,
	["us"] = true,
	["randply"] = true,
	["_"] = true,
}

function syntax.process(code)
	local output,finds,types,a,b,c = {},{},{},0,0,0
	while true do
		local temp = {}
		for k,v in pairs(syntax.patterns) do
			local aa,bb = code:find(v,b+1)
			if aa then table.insert(temp,{k,aa,bb}) end
		end
		if #temp == 0 then break end
		table.sort(temp,function(a,b) return (a[2] == b[2]) and (a[3] > b[3]) or (a[2] < b[2]) end)
		c,a,b = unpack(temp[1])
		table.insert(finds,a)
		table.insert(finds,b)
		local cc = ""
		if c == 3 then
			cc = (syntax.keywords[code:sub(a,b)] and 3 or syntax.luadevspecials[code:sub(a,b)] and 2 or 4)
		else
			cc = c
		end
		table.insert(types,cc)
	end
	for i=1,#finds-1 do
		local asdf = (i-1)%2
		local sub = code:sub(finds[i+0]+asdf,finds[i+1]-asdf)
		table.insert(output,asdf == 0 and syntax.colors[types[1+(i-1)/2]] or Color(0,0,0,255))
		table.insert(output,(asdf == 1 and sub:find("^%s+$")) and sub:gsub("%s", " ") or sub)
	end
	return output
end

local methods = {
	["l"]      = "server",
	["lb"]	   = "both",
	["lc"]     = "clients",
	["lm"]     = "self",
	["ls"]     = "shared",
	["p"]      = "server",
	["print"]  = "server",
	["printb"] = "both",
	["printc"] = "clients",
	["printm"] = "self",
	["table"]  = "server",
	["keys"]   = "server",
	["say"]    = "client",
	["cmd"]    = "console",
	["f"]      = "server",
	["fire"]   = "server",
	["cexec"]  = "client",
	["cx"]     = "client"
}

local methods2 = {
	["p"]      = "print",
	["print"]  = "print",
	["printb"] = "print",
	["printc"] = "print",
	["printm"] = "print",
	["table"]  = "table",
	["keys"]   = "keys",
	["say"]    = "chat",
	["f"]      = "fire",
	["fire"]   = "fire",
	["cexec"]  = "console",
	["cx"]     = "console",
}

local col_server  = Color(91 ,130,229)
local col_client  = Color(229,108,91 )
local col_console = Color(91 ,229,108)

local colors = {
	["l"]      = col_server,
	["lc"]     = col_client,
	["p"]      = col_server,
	["print"]  = col_server,
	["printc"] = col_client,
	["table"]  = col_server,
	["keys"]   = col_server,
	["say"]    = col_client,
	["cmd"]    = col_console,
	["f"]      = col_server,
	["fire"]   = col_server
}

local function ServerName()
	if GetHostName():lower():find("xenora") then
		return "Xenora"
	elseif GetHostName():lower():find("concorde") then
		return "CSA"
	end
end

local grey = Color(191,191,191)
hook.Add("OnChatSyntaxParse","syntax",function(ply,message,tm,d)
	local normal = false
	local method,color
	local cmd,code = message:match("^!(l[bcms]?) (.*)$")
	if not code then cmd,code = message:match("^!(p) (.*)$") end
	if not code then cmd,code = message:match("^!(print[bcm]?) (.*)$") end
	if not code then cmd,code = message:match("^!(table) (.*)$") end
	if not code then cmd,code = message:match("^!(keys) (.*)$") end
	if not code then cmd,code = message:match("^!(say) (.*)$") end
	if not code then cmd,code = message:match("^!(cmd) (.*)$") end
	if not code then cmd,code = message:match("^!(f) (.*)$") end
	if not code then cmd,code = message:match("^!(fire) (.*)$") end
	if not code then cmd,code = message:match("^!(cexec) (.*)$") end
	if not code then cmd,code = message:match("^!(cx) (.*)$") end
	if not code then
		method,code = message:match("^!lsc ([^,]+),(.*)$")
		color = colors["lc"]
		method = easylua.FindEntity(method)
		method = IsValid(method) and (method:IsPlayer() and method:Nick() or tostring(method)) or tostring(method)
	end
	if cmd == "cexec" or cmd == "cx" then
		local cdr = code
		method,code = message:match("([^,]+),(.*)$")
		if not method then
			method,code = message:match("([^,]+),(.*)$")
		end
		if not method then method = cdr end
		color = colors["lc"]
		if not method then return end
		if not code then
			code = method
			method = easylua.FindEntity(method)
		else
			if string.Explode(",",cdr)[1] == "#me" then
				method = ply
			elseif string.Explode(",",cdr)[1] == "#all" then
				method = "ALL"
			else
				method = string.Explode(",",cdr)[1] == "#this" and player:GetEyeTrace().Entity or easylua.FindEntity(tostring(string.Explode(",",cdr)[1]))
			end
		end
		method = method == "ALL" and "Everyone" or (IsValid(method) and (method:IsPlayer() and method:Nick() or tostring(method)) or tostring(method))
	end
	if cmd == "f" or cmd == "fire" then
		local cdr = code
		method,code = message:match("([^,]+),(.*)$")
		if not method then
			method,code = message:match("([^,]+),(.*)$")
		end
		if not method then method = cdr end
		color = colors["f"]
		if not method then return end
		if not code then
			code = method
			method = ply:GetEyeTrace().Entity
		else
			method = string.Explode(",",cdr)[1] == "#this" and player:GetEyeTrace().Entity or easylua.FindEntity(tostring(string.Explode(",",cdr)[1]))
		end
		method = IsValid(method) and method:IsPlayer() and method:Nick() or tostring(method)
	end
	if not code then normal = true end
	if not normal then
		if ply:CanRunLua() then
			if cmd == "cmd" then
				chat.AddText(team.GetColor(ply:Team()),ply:Nick(),grey,"@",color or colors[cmd] or "",method or methods[cmd] or "",grey,grey,": ",Color(200,200,200),code)
			elseif cmd == "f" or cmd == "fire" then
				chat.AddText(team.GetColor(ply:Team()),ply:Nick(),grey,"@",color or colors[cmd] or "",method or methods[cmd] or "",grey,methods2[cmd] and "("..(methods2[cmd])..")" or "",grey,": ",Color(200,200,200),code)
			else
				chat.AddText(team.GetColor(ply:Team()),ply:Nick(),grey,"@",color or colors[cmd] or "",method or methods[cmd] or "",grey,methods2[cmd] and "("..(methods2[cmd])..")" or "",grey,": ",unpack(syntax.process(code)))
			end
		else
			chat.AddText(team.GetColor(ply:Team()),ply:Nick(),grey,"@",color or colors[cmd] or "",method or methods[cmd] or "",Color(200,40,40),"(Access Denied)",grey,grey,": ",Color(200,200,200),code)
		end
	else
		local tod = {}
		if d then
			tod[#tod+1] = Color(255,64,64)
			tod[#tod+1] = "[DEAD] "
		end
		if tm then
			tod[#tod+1] = Color(64,255,64)
			tod[#tod+1] = "[TEAM] "
		end
		if not ply:IsValid() then
			chat.AddText(unpack(tod),Color(180,128,255),ServerName(),Color(255,255,255),": "..message)
		else
			chat.AddText(unpack(tod),team.GetColor(ply:Team()),ply:Nick(),Color(255,255,255),": "..message)
		end
	end
	return true
end)
