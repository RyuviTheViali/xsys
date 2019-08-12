require("socket")

stcp = stcp or {}

stcp.Msg = function(...)
	--Msg("[STCP2] ")
	--print(...)
end

stcp.Clients = stcp.Clients or {}

stcp.Delimiters = {
	sep = "\\",
	header = "%%",
	body = "~~"
}

stcp.FormatMsg = function(header,body)
	local msg = ""
	for i=1,#header do msg = i == #header and msg..header[i] or msg..header[i]..stcp.Delimiters.header end
	msg = msg..stcp.Delimiters.sep
	for i=1,#body   do msg = i == #body   and msg..body  [i] or msg..body  [i]..stcp.Delimiters.body   end
	msg = msg.."\n"
	return msg
end

stcp.ExplodeMsg = function(msg)
	local data = string.Split(msg,stcp.Delimiters.sep)
	local head = string.Split(data[1],stcp.Delimiters.header)
	local body = string.Split(data[2],stcp.Delimiters.body)
	return {head,body}
end

stcp.SendCmd = function(header,body,ip,port)
	header = type(header) == "string" and {header} or header
	body   = type(body)   == "string" and {body}   or body
	local data = stcp.FormatMsg(header,body)
	stcp.cl = gsocket.Connect(ip,port or 27039)
	if not stcp.cl:IsValid() then stcp.Msg("Client object invalid") return end
	stcp.Msg("Started client")
	stcp.cl:Send(data)
	if not stcp.cl._C.receive then
		stcp.Msg("FATAL ERROR, client unable to receive success message")
		return
	end
	local res,status,partial = (stcp.cl._C.receive and stcp.cl._C:receive("*l") or nil)
	local r = res or partial
	if status == "closed" then
		stcp.Msg("Client channelstr closed")
		stcp.cl._C:close()
		stcp.cl = nil
		return
	end
	if r ~= nil and r ~= "" then
		r = r:sub(-1) == "\n" and r:sub(1,-2) or r
		local h,b = unpack(stcp.ExplodeMsg(r))
		hook.Call("stcp",nil,unpack(stcp.ExplodeMsg(r)),ip)
		stcp.cl._C:close()
		stcp.cl = nil
	end
end

stcp.StartServer = function(ip,port)
	if stcp.sv then stcp.sv:close() stcp.sv = nil end
	stcp.sv = socket.tcp()
	stcp.sv:settimeout(0)
	stcp.sv:setoption("reuseaddr",true)
	assert(stcp.sv:bind(ip,port))
	assert(stcp.sv:listen(8))
	if not stcp.sv then stcp.Msg("Server object invalid") return end
	stcp.Msg("Started server")
end

stcp.ProcessData = function(db,data)
	stcp.Msg("Client",db.clid,'from',db.ip,"end transmission. ".."Data ("..#data.." bytes)")
	if #data == 0 then stcp.Msg("Empty packet from",db.ip,', ignoring.') return end
	local header,body = data:match("(.-)"..stcp.Delimiters.sep.."(.*)")
	if not header then
		stcp.Msg("Malformed request from",db.ip,", no sep. Data "..(#data).." Bytes: '"..data:sub(1,128).."'")
		header = data
	end
	if not body then stcp.Msg("Malformed request from",db.ip) end
	stcp.Msg("In '"..header.."' ("..(#data).." Bytes)")
	local sendh,sendb = unpack(stcp.ExplodeMsg(header..stcp.Delimiters.sep..body))
	local reply = hook.Call("stcp",nil,sendh,sendb,db.ip,db)
	if reply and type(reply) == "string" then db.socket:send(reply) end
end

local CLM = {}
function CLM:getdata()
	return table.concat(self.buff)
end

local function CL(tbl)
	setmetatable(tbl or {},{__index=CLM})
	return tbl
end

stcp.Process = function(client,db)
	if db.new then stcp.Msg("Connection from",db.ip) end
	local ok,err,data = client:receive("*l")
	if not ok and err == "timeout" then
		if not data or #data == 0 then return end
		ok = data
		err,data = nil,nil
	end
	if ok then
		assert(type(data) ~= "string")
		data = ok
	end
	if data then
		assert(type(data) == "string")
		stcp.Msg("\tdata from",db.ip,"'"..tostring(data).."'",data == ok)
		table.insert(db.buff,data)
	end
	if not ok then
		if err == "closed" then
			local d = db:getdata()
			local ok,errmsg = pcall(stcp.ProcessData,db,d)
			if not ok then stcp.Msg("Processing error:",errmsg) end
			return true
		end
		stcp.Msg("Socket error:"..tostring(err))
		stcp.Msg("\tReceived data from "..db.ip..": '"..db:getdata().."'")
		return true
	end
end

stcp.Think = function()
	if not stcp.sv then return end
	local newclient,err = stcp.sv and stcp.sv.accept and stcp.sv:accept() or stcp.StartServer("0.0.0.0",GetHostName():lower():find("private") ~= nil and 27038 or 35001)
	if not newclient and err == "closed" then error("Server socket closed") end
	if not newclient and err ~= "timeout" then error("FATAL socket error: "..tostring(err)) end
	if newclient then
		stcp.Msg("Added new client")
		newclient:settimeout(0)
		local ip,port = newclient:getpeername()
		assert(ip ~= nil)
		assert(port ~= nil)
		stcp.Msg("New connection",newclient,"from",ip,port)
		local clid = #stcp.Clients+1
		assert(not stcp.Clients[clid])
		stcp.Clients[clid] = CL{clid=clid,socket=newclient,buff={},ip=ip,port=port,new=true}
	end
	for clid,db in pairs(stcp.Clients) do
		if stcp.Process(db.socket,db) == true then
			stcp.Msg("Closing socket",clid,db.socket,db.ip)
			db.socket:close()
			stcp.Clients[clid] = nil
		end
		if db.new then db.new = false end
	end
end
hook.Add("Think","STCP-Think",stcp.Think)

hook.Add("stcpcl","getcmdsuccess",function(client,data)
	local name,suc = string.Explode("\\",data)
	if suc == "success" then
		stcp.Msg("Stage 1 success")
		--stcp.StartServer("*",12345)
		client:Close()
		stcp.Msg("Closed client")
	end
end)

stcp.StartServer("0.0.0.0",GetHostName():lower():find("private") ~= nil and 27038 or 35001)
