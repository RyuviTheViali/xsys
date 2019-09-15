xgeoip = xgeoip or {}

xgeoip.Cache = {}

xgeoip.GetGeoIP = function(ip,callback)
	ip = ip:match("%d+%.%d+%.%d+%.%d+") or ""
	
	if ip == "" then
		callback({
			ok = false,
			err = "Invalid IP",
			data = {}
		})
	end
	
	http.Fetch("http://ip-api.com/json/"..ip,function(b,s,h,c)
		local tab = util.JSONToTable(b)
		
		xgeoip.Cache[ip] = tab
		
		callback({
			ok = true,
			err = "",
			data = xgeoip.Cache[ip]
		})
	end,function(e)
		callback({
			ok = false,
			err = "Error: "..e,
			data = {}
		})
	end)
end