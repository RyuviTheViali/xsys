if not GetNetChannel and not CNetChan then
	pcall(require, 'sourcenetinfo')
	if not GetNetChannel and not CNetChan then
		pcall(require, 'sourcenet3')
		if not GetNetChannel and not CNetChan then
			MsgC(Color(255, 127, 127), debug.getinfo(1).source .. " could not find sourcenet(info) binary module!\n")
			return
		end
	end
end

local CNetChan = CNetChan
local pm = FindMetaTable("Player")
function pm:GetNetChannel()
	if self:IsBot() then return end
	return GetNetChannel and GetNetChannel(self) or CNetChan and CNetChan(self:EntIndex())
end
pm.NetChan = pm.GetNetChannel

function pm:SetConVar(name,value)
	if not name then error("no name") end
	if not value then error("no value") end
	if self:IsBot() then return end
	if NetChannel then
		if not GetNetChannel then error("???") end
		local chan = GetNetChannel(self)
		if chan and chan.ReplicateData then
			chan:ReplicateData(name,value)
			return
		end
	end
	if pm.ReplicateData then
		return self:ReplicateData(name,value)
	end
	local netchan = CNetChan(self:EntIndex())
	if !netchan then return end
	local buf = netchan:GetReliableBuffer()
	buf:WriteUBitLong(net_SetConVar,NET_MESSAGE_BITS)
	buf:WriteByte(1)
	buf:WriteString(tostring(name))
	buf:WriteString(tostring(value))
end