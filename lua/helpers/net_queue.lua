local meta    = {__index = table}
local queue   = setmetatable({},meta)
local started = false
local next    = next
local pcall   = pcall
local debug   = debug

local function doqueue()
	local sent

	for pl,plqueue in next,queue do
		sent = true
		if not pl:IsValid() or not type(pl) == "player" then
			queue[pl] = nil
		else
			local func = plqueue:remove(1)

			if not func then
				queue[pl] = nil
			else
				local ok,err = xpcall(func,debug.traceback)

				if not ok then
					ErrorNoHalt(err..'\n')
				end
			end
		end
	end

	if not sent then
		started = false
		hook.Remove("Think",'netqueue')
	end
end

function net.queuesingle(pl,func)
	if not started then
		hook.Add("Think",'netqueue',doqueue)
	end
	
	local plqueue = queue[pl] or setmetatable({},meta)
	queue[pl] = plqueue
	plqueue:insert(func)
end

function net.queue(targets,func)
	if targets == true then
		targets = nil
	elseif targets and isentity(targets) then
		targets = {targets}
	end

	for k,pl in pairs(targets or player.GetHumans()) do
		net.queuesingle(pl,function()
			func(pl)
		end)
	end
end

concommand.Add("netqueue_dump",function(pl)
	if SERVER and IsValid(pl) then return end

	print("Lua NetQueue:")

	local ok
	for pl,v in next,queue do
		Msg("\t",pl,": ")
		print(table.Count(v))

		if not ok then
			ok = true
		end
	end

	if not ok then
		print("\tEMPTY")
	end
end)

xsys = xsys or {}

xsys.NET_QUEUE_INITIALIZED = true