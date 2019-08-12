
// ************************************
// * GSocket - Socket Module for GMod 10 *
// ************************************
// By thomasfn

require( "socket" )

local socket = socket
if (!socket) then
	ErrorNoHalt( "Socket library not present!\n" )
	return
end

log = {}
function log.Write( id, msg )
	print( id, msg )
end

module( "gsocket", package.seeall )

local HandleClient, HandleServer

local DebugMode = false

local BaseHooks = {}

local Clients = {}
local Servers = {}

local clmeta = {}

	function clmeta:New( client )
		local o = {}
		setmetatable( o, { __index = self } )
		o:OnCreate( client )
		return o
	end
	
	function clmeta:OnCreate( client )
		self._C = client
		client:settimeout( 0 )
		local ip, port = client:getpeername()
		self._IP = ip
		self._PORT = port
		self._VALID = true
		--self:Log( "Client object created! " .. ip .. "," .. port )
	end
	
	function clmeta:Send( msg )
		self._C:send( msg )
		--self:Log( "Sent: " .. msg )
	end
	
	function clmeta:GetPort()
		return self._PORT
	end
	
	function clmeta:GetIP()
		return self._IP
	end
	
	function clmeta:IsValid()
		return self._VALID
	end
	
	function clmeta:Invalidate()
		self._VALID = false
	end
	
	function clmeta:IsClient() return true end
	function clmeta:IsServer() return false end
	
	function clmeta:Call( name, ... )
		local hookname = name
		if (BaseHooks[ name ]) then
			local b, err = pcall( BaseHooks[ name ], self, ... )
			if (!b) then
				ErrorNoHalt( res .. "\n" )
				BaseHooks[ name ] = nil
			end
		end
		local tab = hook.GetTable()[ hookname ]
		if (!tab) then return end
		for k, v in pairs( tab ) do
			local b, res = pcall( v, self, ... )
			if (!b) then
				ErrorNoHalt( res .. "\n" )
				hook.Remove( hookname, k )
			end
			if (res != nil) then return res end
		end
	end
	
	function clmeta:RunCheck()
		local client = self._C
		if (!client) then
			self:Call( "ConnectionClosed", "unknown" )
			self:Invalidate()
			return
		end
		local res, status, partial = client:receive( 1024 )
		local r = res or partial
		if (status == "closed") then
			self:Call( "ConnectionClosed", "peer" )
			self:Invalidate()
			return
		end
		if (r != "") then
			self:Call( "NetMessageRecieved", r )
			--self:Log( "Recieved: " .. r )
			r = r:sub(-1) == "\n" and r:sub(1,-2) or r
			--hook.Call("stcpcl",nil,self,r)
		end
	end
	
	function clmeta:Close()
		self._C:close()
		self:Call( "ConnectionClosed", "local" )
		self:Invalidate()
		--self:Log( "Connection closed!" )
	end
	
	function clmeta:Log( message )
		log.Write( "gsocket", "CLIENT: " .. message )
	end


debug.getregistry().SocketClient = clmeta

local svmeta = {}

	function svmeta:New( server )
		local o = {}
		setmetatable( o, { __index = self } )
		o:OnCreate( server )
		return o
	end
	
	function svmeta:OnCreate( server )
		self._S = server
		server:settimeout( 0 )
		self._VALID = true
		self:Log( "Now listening!" )
	end

	function svmeta:IsValid()
		return self._VALID
	end
	
	function svmeta:Invalidate()
		self._VALID = false
	end
	
	function svmeta:IsClient() return false end
	function svmeta:IsServer() return true end
	
	function svmeta:Call( name, ... )
		local hookname = name
		if (BaseHooks[ hookname ]) then
			local b, err = pcall( BaseHooks[ name ], self, ... )
			if (!b) then
				ErrorNoHalt( res .. "\n" )
				BaseHooks[ hookname ] = nil
			end
		end
		local tab = hook.GetTable()[ hookname ]
		if (!tab) then return end
		for k, v in pairs( tab ) do
			local b, res = pcall( v, self, ... )
			if (!b) then
				ErrorNoHalt( res .. "\n" )
				hook.Remove( hookname, k )
			end
			if (res != nil) then return res end
		end
	end
	
	function svmeta:RunCheck()
		local server = self._S
		if (!server) then
			self:Call( "ServerHalted" )
			self:Invalidate()
			return
		end
		local client = server:accept()
		if (!client) then return end
		local ip, port = client:getpeername()
		local accept = self:Call( "ShouldAcceptConnection", ip, port )
		if (accept == nil) then accept = true end
		if (!accept) then
			self:Log( "Client denied! " .. ip .. "," .. port )
			client:close()
			return
		end
		self:Log( "Client connected! " .. ip .. "," .. port )
		local clienthandle = HandleClient( client )
		if (clienthandle:IsValid()) then
			self:Call( "OnConnection", clienthandle )
		end
	end
	
	function svmeta:Stop()
		self._S:close()
		self:Call( "ServerHalted" )
		self:Invalidate()
		self:Log( "Stopped listening" )
	end
	
	function svmeta:Log( message )
		log.Write( "gsocket", "SERVER: " .. message )
	end

debug.getregistry().SocketServer = svmeta

local Clients = {}
local Servers = {}

function HandleClient( client )
	local c = clmeta:New( client )
	table.insert( Clients, c )
	return c
end

function HandleServer( server )
	local s = svmeta:New( server )
	table.insert( Servers, s )
	return s
end

function Listen( ip, port, maxconnections )
	local server = socket.bind( ip, port, maxconnections or 1 )
	local handle = HandleServer( server )
	if (handle:IsValid()) then
		handle:Call( "ServerStarted" )
		return handle
	end
end

function Connect( ip, port )
	local client = socket.connect( ip, port )
	local handle = HandleClient( client )
	if (handle:IsValid()) then
		handle:Call( "ConnectionMade" )
		return handle
	end
end

local function Tick()
	for k, v in pairs( Clients ) do
		if ((!v) || (!v:IsValid())) then
			table.remove( Clients, k )
			break
		end
		local b, err = pcall( v.RunCheck, v )
		if (!b) then
			ErrorNoHalt( "GSocket: " .. err .. "\n" )
		end
	end
	for k, v in pairs( Servers ) do
		if ((!v) || (!v:IsValid())) then
			table.remove( Servers, k )
			break
		end
		local b, err = pcall( v.RunCheck, v )
		if (!b) then
			ErrorNoHalt( "GSocket: " .. err .. "\n" )
		end		
	end
end
hook.Add( "Tick", "GSocket:Tick", Tick )

function GetAllClients()
	return Clients
end

function GetAllServers()
	return Servers
end

function BaseHooks.ConnectionClosed( handle, by )
	if (!DebugMode) then return end
	print( "GSocket: Connection was closed by " .. by .. "!" )
end

function BaseHooks.MessageRecieved( handle, msg )
	if (!DebugMode) then return end
	print( "GSocket: Message recieved!" )
	print( msg )
end

function BaseHooks.ServerHalted( handle )
	if (!DebugMode) then return end
	print( "GSocket: Server was halted!" )
end

function BaseHooks.ShouldAcceptConnection( handle, ip, port )
	if (!DebugMode) then return end
	print( "GSocket: Requesting verification on incoming connection!" )
	print( ip, port )
end

function BaseHooks.OnConnection( handle )
	if (!DebugMode) then return end
	print( "GSocket: Incoming connection!" )
	print( handle:GetIP(), handle:GetPort() )
end

function BaseHooks.ServerStarted( handle )
	if (!DebugMode) then return end
	print( "GSocket: Server was started!" )
end

function BaseHooks.ConnectionMade( handle )
	if (!DebugMode) then return end
	print( "GSocket: Outgoing connection established!" )
end

concommand.Add( "socket_enabledebug", function( pl, com, args )
	if (!pl:IsAdmin()) then return end
	DebugMode = (args[1] == "1")
	print( "GSocket: Debug mode set to " .. tostring( DebugMode ) .. "!" )
end )