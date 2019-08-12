if SERVER then 
	AddCSLuaFile("pretty_date.lua")

end

local dd,hh,mm= 60*60*24,60*60,60
local function datetable(a)
	local n = false
    if a < 0 then n,a = true,a*-1 end
	local f,s,m,h,d
    f = a-math.floor(a)
	f = math.Round(f*10)*0.1
    a = math.floor(a)
    d = math.floor(a/dd)
    a = a-d*dd
    h = math.floor(a/hh)
    a = a-h*hh
    m = math.floor(a/mm)
    a = a-m*mm
    s = a
    return {f=f,s=s,m=m,h=h,d=d,n=n}
end

local prettydate do
	local conjunction  = " and"
	local conjunction2 = ","
	prettydate = function(t)
		if type(t) == "number" then t = datetable(t) end
		local tbl = {}
		if t.d ~= 0 then table.insert(tbl,t.d.." day"..(t.d == 1 and "" or "s")) end
		local lastand
		if t.h ~= 0 then
			if #tbl > 0 then
				lastand = table.insert(tbl,conjunction)
				table.insert(tbl," ")
			end
			table.insert(tbl,t.h.." hour"..(t.h == 1 and "" or "s"))
		end
		if t.m ~= 0 then
			if #tbl > 0 then
				lastand = table.insert(tbl,conjunction)
				table.insert(tbl," ")
			end
			table.insert(tbl,t.m.." minute"..(t.m == 1 and "" or "s"))
		end
		if t.s ~= 0 or #tbl == 0 then
			if #tbl > 0 then
				lastand = table.insert(tbl,conjunction)
				table.insert(tbl," ")
			end
			table.insert(tbl,t.s.."."..math.Round(t.f*10).." seconds")
		end
		if t.n then table.insert(tbl," in the past") end
		for k,v in pairs(tbl) do
			if v == conjunction and k ~= lastand then
				tbl[k] = conjunction2
			end
		end
		return table.concat(tbl,"")
	end
end

_G.os.datetable  = datetable
_G.os.prettydate = prettydate