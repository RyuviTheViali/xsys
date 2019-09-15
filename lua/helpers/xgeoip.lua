xgeoip = xgeoip or {}

xgeoip.Cache = {}


if SERVER then
	util.AddNetworkString("xgeoip-trans")
	
	xgeoip.GetGeoIP = function(ip,callback)
		ip = ip:match("%d+%.%d+%.%d+%.%d+") or ""
		
		if ip == "" then
			if callback then
				callback({
					ok = false,
					err = "Invalid IP",
					data = {}
				})
			end
		end
		
		http.Fetch("http://ip-api.com/json/"..ip,function(b,s,h,c)
			local tab = util.JSONToTable(b)
			
			xgeoip.Cache[ip] = tab
			
			if callback then
				callback({
					ok = true,
					err = "",
					data = xgeoip.Cache[ip]
				})
			end
		end,function(e)
			if callback then
				callback({
					ok = false,
					err = "Error: "..e,
					data = {}
				})
			end
		end)
	end
	
	xgeoip.GetCachedIP = function(ply,send,force)
		ply = ply:IsPlayer() and ply or easylua.FindEntity(ply)
		
		if ply and ply:IsValid() and ply:IsPlayer() then
			local ip = ply:IPAddress():match("%d+%.%d+%.%d+%.%d+") or ""
			
			if ip == "" then return end
			
			if xgeoip.Cache[ip] and not force then
				net.Start("xgeoip-trans")
					net.WriteEntity(ply)
					net.WriteTable(xgeoip.Cache[ip])
				net.Send(send)
			else
				net.Start("xgeoip-trans")
					net.WriteEntity(ply)
					net.WriteTable({false})
				net.Send(send)
				xgeoip.GetGeoIP(ip)
			end
		end
	end
	
	net.Receive("xgeoip-trans",function(l,p)
		local ply = net.ReadEntity()
		local forceupdate = net.ReadBool()
		xgeoip.GetCachedIP(ply,p,forceupdate)
	end)
else
	xgeoip.RequestGeoIP = function(ply,forceupdate)
		if not ply or not ply:IsValid() or not ply:IsPlayer() or ply:IsBot() then return end
		net.Start("xgeoip-trans")
			net.WriteEntity(ply)
			net.WriteBool(forceupdate or false)
		net.SendToServer()
	end

	net.Receive("xgeoip-trans",function(l,p)
		local ply = net.ReadEntity()
		local dat = net.ReadTable()
		if dat[1] ~= nil and dat[1] == false then --ip reception failure, try again in 5 seconds
			timer.Simple(5,function()
				xgeoip.RequestGeoIP(ply)
			end)
		else -- ip reception success
			xgeoip.Cache[dat.query] = dat
		end
	end)
end
