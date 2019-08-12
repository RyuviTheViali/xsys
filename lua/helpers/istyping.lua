local tag = 'IsTyping'

FindMetaTable("Player").IsTyping = function(ply)
	return ply:GetNetData(tag)
end

if CLIENT then
	local started = false
	hook.Add("ChatTextChanged",tag,function(msg)
		if started or not msg or #msg < 1 then return end
		started = true
		local l = LocalPlayer()
		if l.SetNetData and l:IsValid() then
			l:SetNetData(tag,true)
		end
	end)
	hook.Add("FinishChat",tag,function()
		started = false
		local l = LocalPlayer()
		if l.SetNetData and l:IsValid() then
			l:SetNetData(tag,false)
		end
	end)
end