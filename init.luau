local module = {}

-- Generic method for capturing metamethods, only works if the metamethod generated an error
function module.CaptureMetamethod(usercallback: () -> never): ((...any) -> (...any))?
	local metamethod
	xpcall(usercallback, function()
		metamethod = debug.info(2, 'f')
	end)
	return metamethod
end

-- Captures Instance __index metamethod capitalizing on custom error handler behavior
function module.InstanceIndexMetamethod(): ((Instance, any) -> any)?
	return module.CaptureMetamethod(function()
		return game.____
	end)
end

-- Captures Instance __newindex metamethod capitalizing on custom error handler behavior
function module.InstanceNewIndexMetamethod(): ((Instance, any, any) -> ())?
	return module.CaptureMetamethod(function()
		game.____ = false
	end)
end

-- Returns human name from a capability ID
function module.CapabilityName(id: number): string
	local names = {
		[0] = "None",
		[1] = "PluginSecurity",
		[3] = "LocalUserSecurity",
		[4] = "WritePlayerSecurity",
		[5] = "RobloxScriptSecurity",
		[6] = "RobloxSecurity",
		[7] = "NotAccessibleSecurity",
		--[[
			No extra information available on this capability,
			required to call StreamingService.ExecuteCommandAsync
		]]
		[1000] = "Assistant",
		--[[
			OpenCloud does not have it's own capability, but it's as a sum capability
			of Plugin and OpenCloud called PluginOrOpenCloud.
			For disambiguation, in this script, OpenCloud has been granted it's own ID
			alongside Plugin's PluginSecurity
		]]
		[1001] = "OpenCloud"
	}
	if names[id] then
		return names[id]
	end
	error(`Unknown capability ID: {id}`)
end

-- Tests certain capabilities by known methods, returns an array of available capabilities' ID
function module.GetCapabilities(): {number}
	local __index = module.InstanceIndexMetamethod()
	local __newindex = module.InstanceNewIndexMetamethod()
	local function test(func, ...)
		local s, _ = pcall(func, ...)
		return s
	end
	
	local capabilities = {}

	if test(__index, game, "Name") then
		table.insert(capabilities, 0)
	end
	if test(settings) or test(function()
			return game:GetService("CoreGui").Name
		end) then
		table.insert(capabilities, 1)
	end
	if test(__index, game, "DataCost") then
		table.insert(capabilities, 3)
	end
	if test(Instance.new, "Player") then
		table.insert(capabilities, 4)
	end
	if test(function()
			return game:GetService("CorePackages").Name
		end) then
		table.insert(capabilities, 5)
	end
	if test(__index, Instance.new("SurfaceAppearance"), "TexturePack") then
		table.insert(capabilities, 6)
	end
	if test(__newindex, Instance.new("MeshPart"), "MeshId", "") then
		table.insert(capabilities, 7)
	end
	if test(function()
			game:GetService("StreamingService"):ExecuteCommandAsync()
		end) then
		table.insert(capabilities, 1000)
	end
	
	return capabilities
end

-- Returns a human name from identity ID
function module.IdentityName(id: number): string
	local names = {
		[-1] = "Unknown",
		[0] = "Anonymous",
		[1] = "LocalGui",
		[2] = "GameScript",
		[3] = "ElevatedGameScript",
		[4] = "CommandBar",
		[5] = "StudioPlugin",
		[6] = "ElevatedStudioPlugin",
		[7] = "COM",
		[8] = "WebService",
		[9] = "Replicator",
		[10] = "Assistant",
		[11] = "OpenCloudSession"
	}
	if names[id] then
		return names[id]
	end
	error(`Unknown identity ID: {id}`)
end

-- Gets current running script's identity comparing capabilities or other special behavior
-- Returns -1 if script's identity could not be determined
function module.GetScriptIdentity(): number
	local capabilities = module.GetCapabilities()
	local function hasCapabilities(...): boolean
		local cap = {...}
		if table.find(capabilities, 0) then
			table.insert(cap, 0)
		end
		if #cap ~= #capabilities then
			return false
		end
		for _, v in cap do
			if v == 0 then
				continue
			end
			if not table.find(capabilities, v) then
				return false
			end
		end
		return true
	end

	-- identity 2
	if #capabilities == 1 and capabilities[1] == 0 then
		return 2
	end
	-- identity 1
	do
		local _, e: string = pcall(error, 1)
		if e:match("expressionEval:%d: 1") then -- and hasCapabilities(1, 3) then
			return 1
		end
	end
	-- identity 4
	do
		--[[
			identity 5 and 4 have same capabilities (None & PluginSecurity)
			but 4th (CommandBar) has access to loadstring regardless of
			ServerScriptService.LoadStringEnabled property
		]]
		if hasCapabilities(1) then
			local s, e = pcall(loadstring, '')
			if s and e == 1 then
				return 4
			elseif not s and e == "loadstring() is not available" then
				return 5
			end
		end
	end
	local tests = {
		[0] = {1, 3, 6, 7},
		[3] = {1, 3, 6},
		[6] = {1, 3, 6, 1000},
		-- no known way to differ 7 and 8 identities
		[7] = {1, 3, 4, 5, 6, 7},
		[8] = {1, 3, 4, 5, 6, 7},
		[9] = {4, 5},
		[10] = {1, 3, 1000},
		[11] = {1001}
	}
	for capability, test in tests do
		if hasCapabilities(unpack(test)) then
			return capability
		end
	end
	return -1
end

module.test = {}

function module.test.capabilities()
	local capabilities = module.GetCapabilities()
	local cap = {}
	for _, v in capabilities do
		print(`[{v}]`, module.CapabilityName(v))
	end
end

function module.test.identity()
	print("===== Identity Test Start =====")
	
	local ident = module.GetScriptIdentity()
	printidentity()
	print(`Estimated identity is {ident} ({module.IdentityName(ident)})`)

	print("Capabilities:")
	module.test.capabilities()

	print("===== Identity Test End =====")
end

return module
