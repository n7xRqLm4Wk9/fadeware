local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('FadeWare', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/n7xRqLm4Wk9/fadeware/main/_compiled/'..select(1, path:gsub('fadeware/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('fadeware/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('FadeWare', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('FadeWare', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('FadeWare', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('FadeWare', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = (function()
-- HashLib by Egor Skriptunoff, boatbomber, and howmanysmall, I'm not trusting exploits to have a built in crypt library.

--[=[------------------------------------------------------------------------------------------------------------------------

Documentation here: https://devforum.roblox.com/t/open-source-hashlib/416732/1

--------------------------------------------------------------------------------------------------------------------------

Module was originally written by Egor Skriptunoff and distributed under an MIT license.
It can be found here: https://github.com/Egor-Skriptunoff/pure_lua_SHA/blob/master/sha2.lua

That version was around 3000 lines long, and supported Lua versions 5.1, 5.2, 5.3, and 5.4, and LuaJIT.
Although that is super cool, Roblox only uses Lua 5.1, so that was extreme overkill.

I, boatbomber, worked to port it to Roblox in a way that doesn't overcomplicate it with support of unreachable
cases. Then, howmanysmall did some final optimizations that really squeeze out all the performance possible.
It's gotten stupid fast, thanks to her!

After quite a bit of work and benchmarking, this is what we were left with.
Enjoy!

--------------------------------------------------------------------------------------------------------------------------

DESCRIPTION:
	This module contains functions to calculate SHA digest:
		MD5, SHA-1,
		SHA-224, SHA-256, SHA-512/224, SHA-512/256, SHA-384, SHA-512,
		SHA3-224, SHA3-256, SHA3-384, SHA3-512, SHAKE128, SHAKE256,
		HMAC
	Additionally, it has a few extra utility functions:
		hex_to_bin
		base64_to_bin
		bin_to_base64
	Written in pure Lua.
USAGE:
	Input data should be a string
	Result (SHA digest) is returned in hexadecimal representation as a string of lowercase hex digits.
	Simplest usage example:
		local HashLib = require(script.HashLib)
		local your_hash = HashLib.sha256("your string")
API:
		HashLib.md5
		HashLib.sha1
	SHA2 hash functions:
		HashLib.sha224
		HashLib.sha256
		HashLib.sha512_224
		HashLib.sha512_256
		HashLib.sha384
		HashLib.sha512
	SHA3 hash functions:
		HashLib.sha3_224
		HashLib.sha3_256
		HashLib.sha3_384
		HashLib.sha3_512
		HashLib.shake128
		HashLib.shake256
	Misc utilities:
		HashLib.hmac (Applicable to any hash function from this module except SHAKE*)
		HashLib.hex_to_bin
		HashLib.base64_to_bin
		HashLib.bin_to_base64

--]=]---------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LOCALIZATION FOR VM OPTIMIZATIONS
--------------------------------------------------------------------------------

local ipairs = ipairs

--------------------------------------------------------------------------------
-- 32-BIT BITWISE FUNCTIONS
--------------------------------------------------------------------------------
-- Only low 32 bits of function arguments matter, high bits are ignored
-- The result of all functions (except HEX) is an integer inside "correct range":
-- for "bit" library:	(-TWO_POW_31)..(TWO_POW_31-1)
-- for "bit32" library:		0..(TWO_POW_32-1)
local bit32_band = bit32.band -- 2 arguments
local bit32_bor = bit32.bor -- 2 arguments
local bit32_bxor = bit32.bxor -- 2..5 arguments
local bit32_lshift = bit32.lshift -- second argument is integer 0..31
local bit32_rshift = bit32.rshift -- second argument is integer 0..31
local bit32_lrotate = bit32.lrotate -- second argument is integer 0..31
local bit32_rrotate = bit32.rrotate -- second argument is integer 0..31

--------------------------------------------------------------------------------
-- CREATING OPTIMIZED INNER LOOP
--------------------------------------------------------------------------------
-- Arrays of SHA2 "magic numbers" (in "INT64" and "FFI" branches "*_lo" arrays contain 64-bit values)
local sha2_K_lo, sha2_K_hi, sha2_H_lo, sha2_H_hi, sha3_RC_lo, sha3_RC_hi = {}, {}, {}, {}, {}, {}
local sha2_H_ext256 = {
	[224] = {};
	[256] = sha2_H_hi;
}

local sha2_H_ext512_lo, sha2_H_ext512_hi = {
	[384] = {};
	[512] = sha2_H_lo;
}, {
	[384] = {};
	[512] = sha2_H_hi;
}

local md5_K, md5_sha1_H = {}, {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0}
local md5_next_shift = {0, 0, 0, 0, 0, 0, 0, 0, 28, 25, 26, 27, 0, 0, 10, 9, 11, 12, 0, 15, 16, 17, 18, 0, 20, 22, 23, 21}
local HEX64, XOR64A5, lanes_index_base -- defined only for branches that internally use 64-bit integers: "INT64" and "FFI"
local common_W = {} -- temporary table shared between all calculations (to avoid creating new temporary table every time)
local K_lo_modulo, hi_factor, hi_factor_keccak = 4294967296, 0, 0

local TWO_POW_NEG_56 = 2 ^ -56
local TWO_POW_NEG_17 = 2 ^ -17

local TWO_POW_2 = 2 ^ 2
local TWO_POW_3 = 2 ^ 3
local TWO_POW_4 = 2 ^ 4
local TWO_POW_5 = 2 ^ 5
local TWO_POW_6 = 2 ^ 6
local TWO_POW_7 = 2 ^ 7
local TWO_POW_8 = 2 ^ 8
local TWO_POW_9 = 2 ^ 9
local TWO_POW_10 = 2 ^ 10
local TWO_POW_11 = 2 ^ 11
local TWO_POW_12 = 2 ^ 12
local TWO_POW_13 = 2 ^ 13
local TWO_POW_14 = 2 ^ 14
local TWO_POW_15 = 2 ^ 15
local TWO_POW_16 = 2 ^ 16
local TWO_POW_17 = 2 ^ 17
local TWO_POW_18 = 2 ^ 18
local TWO_POW_19 = 2 ^ 19
local TWO_POW_20 = 2 ^ 20
local TWO_POW_21 = 2 ^ 21
local TWO_POW_22 = 2 ^ 22
local TWO_POW_23 = 2 ^ 23
local TWO_POW_24 = 2 ^ 24
local TWO_POW_25 = 2 ^ 25
local TWO_POW_26 = 2 ^ 26
local TWO_POW_27 = 2 ^ 27
local TWO_POW_28 = 2 ^ 28
local TWO_POW_29 = 2 ^ 29
local TWO_POW_30 = 2 ^ 30
local TWO_POW_31 = 2 ^ 31
local TWO_POW_32 = 2 ^ 32
local TWO_POW_40 = 2 ^ 40

local TWO56_POW_7 = 256 ^ 7

-- Implementation for Lua 5.1/5.2 (with or without bitwise library available)
local function sha256_feed_64(H, str, offs, size)
	-- offs >= 0, size >= 0, size is multiple of 64
	local W, K = common_W, sha2_K_hi
	local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
	for pos = offs, offs + size - 1, 64 do
		for j = 1, 16 do
			pos = pos + 4
			local a, b, c, d = string.byte(str, pos - 3, pos)
			W[j] = ((a * 256 + b) * 256 + c) * 256 + d
		end

		for j = 17, 64 do
			local a, b = W[j - 15], W[j - 2]
			W[j] = bit32_bxor(bit32_rrotate(a, 7), bit32_lrotate(a, 14), bit32_rshift(a, 3)) + bit32_bxor(bit32_lrotate(b, 15), bit32_lrotate(b, 13), bit32_rshift(b, 10)) + W[j - 7] + W[j - 16]
		end

		local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
		for j = 1, 64 do
			local z = bit32_bxor(bit32_rrotate(e, 6), bit32_rrotate(e, 11), bit32_lrotate(e, 7)) + bit32_band(e, f) + bit32_band(-1 - e, g) + h + K[j] + W[j]
			h = g
			g = f
			f = e
			e = z + d
			d = c
			c = b
			b = a
			a = z + bit32_band(d, c) + bit32_band(a, bit32_bxor(d, c)) + bit32_bxor(bit32_rrotate(a, 2), bit32_rrotate(a, 13), bit32_lrotate(a, 10))
		end

		h1, h2, h3, h4 = (a + h1) % 4294967296, (b + h2) % 4294967296, (c + h3) % 4294967296, (d + h4) % 4294967296
		h5, h6, h7, h8 = (e + h5) % 4294967296, (f + h6) % 4294967296, (g + h7) % 4294967296, (h + h8) % 4294967296
	end

	H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
end

local function sha512_feed_128(H_lo, H_hi, str, offs, size)
	-- offs >= 0, size >= 0, size is multiple of 128
	-- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
	local W, K_lo, K_hi = common_W, sha2_K_lo, sha2_K_hi
	local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
	local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
	for pos = offs, offs + size - 1, 128 do
		for j = 1, 16 * 2 do
			pos = pos + 4
			local a, b, c, d = string.byte(str, pos - 3, pos)
			W[j] = ((a * 256 + b) * 256 + c) * 256 + d
		end

		for jj = 34, 160, 2 do
			local a_lo, a_hi, b_lo, b_hi = W[jj - 30], W[jj - 31], W[jj - 4], W[jj - 5]
			local tmp1 = bit32_bxor(bit32_rshift(a_lo, 1) + bit32_lshift(a_hi, 31), bit32_rshift(a_lo, 8) + bit32_lshift(a_hi, 24), bit32_rshift(a_lo, 7) + bit32_lshift(a_hi, 25)) % 4294967296 +
				bit32_bxor(bit32_rshift(b_lo, 19) + bit32_lshift(b_hi, 13), bit32_lshift(b_lo, 3) + bit32_rshift(b_hi, 29), bit32_rshift(b_lo, 6) + bit32_lshift(b_hi, 26)) % 4294967296 +
				W[jj - 14] + W[jj - 32]

			local tmp2 = tmp1 % 4294967296
			W[jj - 1] = bit32_bxor(bit32_rshift(a_hi, 1) + bit32_lshift(a_lo, 31), bit32_rshift(a_hi, 8) + bit32_lshift(a_lo, 24), bit32_rshift(a_hi, 7)) +
				bit32_bxor(bit32_rshift(b_hi, 19) + bit32_lshift(b_lo, 13), bit32_lshift(b_hi, 3) + bit32_rshift(b_lo, 29), bit32_rshift(b_hi, 6)) +
				W[jj - 15] + W[jj - 33] + (tmp1 - tmp2) / 4294967296

			W[jj] = tmp2
		end

		local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
		local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
		for j = 1, 80 do
			local jj = 2 * j
			local tmp1 = bit32_bxor(bit32_rshift(e_lo, 14) + bit32_lshift(e_hi, 18), bit32_rshift(e_lo, 18) + bit32_lshift(e_hi, 14), bit32_lshift(e_lo, 23) + bit32_rshift(e_hi, 9)) % 4294967296 +
				(bit32_band(e_lo, f_lo) + bit32_band(-1 - e_lo, g_lo)) % 4294967296 +
				h_lo + K_lo[j] + W[jj]

			local z_lo = tmp1 % 4294967296
			local z_hi = bit32_bxor(bit32_rshift(e_hi, 14) + bit32_lshift(e_lo, 18), bit32_rshift(e_hi, 18) + bit32_lshift(e_lo, 14), bit32_lshift(e_hi, 23) + bit32_rshift(e_lo, 9)) +
				bit32_band(e_hi, f_hi) + bit32_band(-1 - e_hi, g_hi) +
				h_hi + K_hi[j] + W[jj - 1] +
				(tmp1 - z_lo) / 4294967296

			h_lo = g_lo
			h_hi = g_hi
			g_lo = f_lo
			g_hi = f_hi
			f_lo = e_lo
			f_hi = e_hi
			tmp1 = z_lo + d_lo
			e_lo = tmp1 % 4294967296
			e_hi = z_hi + d_hi + (tmp1 - e_lo) / 4294967296
			d_lo = c_lo
			d_hi = c_hi
			c_lo = b_lo
			c_hi = b_hi
			b_lo = a_lo
			b_hi = a_hi
			tmp1 = z_lo + (bit32_band(d_lo, c_lo) + bit32_band(b_lo, bit32_bxor(d_lo, c_lo))) % 4294967296 + bit32_bxor(bit32_rshift(b_lo, 28) + bit32_lshift(b_hi, 4), bit32_lshift(b_lo, 30) + bit32_rshift(b_hi, 2), bit32_lshift(b_lo, 25) + bit32_rshift(b_hi, 7)) % 4294967296
			a_lo = tmp1 % 4294967296
			a_hi = z_hi + (bit32_band(d_hi, c_hi) + bit32_band(b_hi, bit32_bxor(d_hi, c_hi))) + bit32_bxor(bit32_rshift(b_hi, 28) + bit32_lshift(b_lo, 4), bit32_lshift(b_hi, 30) + bit32_rshift(b_lo, 2), bit32_lshift(b_hi, 25) + bit32_rshift(b_lo, 7)) + (tmp1 - a_lo) / 4294967296
		end

		a_lo = h1_lo + a_lo
		h1_lo = a_lo % 4294967296
		h1_hi = (h1_hi + a_hi + (a_lo - h1_lo) / 4294967296) % 4294967296
		a_lo = h2_lo + b_lo
		h2_lo = a_lo % 4294967296
		h2_hi = (h2_hi + b_hi + (a_lo - h2_lo) / 4294967296) % 4294967296
		a_lo = h3_lo + c_lo
		h3_lo = a_lo % 4294967296
		h3_hi = (h3_hi + c_hi + (a_lo - h3_lo) / 4294967296) % 4294967296
		a_lo = h4_lo + d_lo
		h4_lo = a_lo % 4294967296
		h4_hi = (h4_hi + d_hi + (a_lo - h4_lo) / 4294967296) % 4294967296
		a_lo = h5_lo + e_lo
		h5_lo = a_lo % 4294967296
		h5_hi = (h5_hi + e_hi + (a_lo - h5_lo) / 4294967296) % 4294967296
		a_lo = h6_lo + f_lo
		h6_lo = a_lo % 4294967296
		h6_hi = (h6_hi + f_hi + (a_lo - h6_lo) / 4294967296) % 4294967296
		a_lo = h7_lo + g_lo
		h7_lo = a_lo % 4294967296
		h7_hi = (h7_hi + g_hi + (a_lo - h7_lo) / 4294967296) % 4294967296
		a_lo = h8_lo + h_lo
		h8_lo = a_lo % 4294967296
		h8_hi = (h8_hi + h_hi + (a_lo - h8_lo) / 4294967296) % 4294967296
	end

	H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
	H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
end

local function md5_feed_64(H, str, offs, size)
	-- offs >= 0, size >= 0, size is multiple of 64
	local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
	local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
	for pos = offs, offs + size - 1, 64 do
		for j = 1, 16 do
			pos = pos + 4
			local a, b, c, d = string.byte(str, pos - 3, pos)
			W[j] = ((d * 256 + c) * 256 + b) * 256 + a
		end

		local a, b, c, d = h1, h2, h3, h4
		local s = 25
		for j = 1, 16 do
			local F = bit32_rrotate(bit32_band(b, c) + bit32_band(-1 - b, d) + a + K[j] + W[j], s) + b
			s = md5_next_shift[s]
			a = d
			d = c
			c = b
			b = F
		end

		s = 27
		for j = 17, 32 do
			local F = bit32_rrotate(bit32_band(d, b) + bit32_band(-1 - d, c) + a + K[j] + W[(5 * j - 4) % 16 + 1], s) + b
			s = md5_next_shift[s]
			a = d
			d = c
			c = b
			b = F
		end

		s = 28
		for j = 33, 48 do
			local F = bit32_rrotate(bit32_bxor(bit32_bxor(b, c), d) + a + K[j] + W[(3 * j + 2) % 16 + 1], s) + b
			s = md5_next_shift[s]
			a = d
			d = c
			c = b
			b = F
		end

		s = 26
		for j = 49, 64 do
			local F = bit32_rrotate(bit32_bxor(c, bit32_bor(b, -1 - d)) + a + K[j] + W[(j * 7 - 7) % 16 + 1], s) + b
			s = md5_next_shift[s]
			a = d
			d = c
			c = b
			b = F
		end

		h1 = (a + h1) % 4294967296
		h2 = (b + h2) % 4294967296
		h3 = (c + h3) % 4294967296
		h4 = (d + h4) % 4294967296
	end

	H[1], H[2], H[3], H[4] = h1, h2, h3, h4
end

local function sha1_feed_64(H, str, offs, size)
	-- offs >= 0, size >= 0, size is multiple of 64
	local W = common_W
	local h1, h2, h3, h4, h5 = H[1], H[2], H[3], H[4], H[5]
	for pos = offs, offs + size - 1, 64 do
		for j = 1, 16 do
			pos = pos + 4
			local a, b, c, d = string.byte(str, pos - 3, pos)
			W[j] = ((a * 256 + b) * 256 + c) * 256 + d
		end

		for j = 17, 80 do
			W[j] = bit32_lrotate(bit32_bxor(W[j - 3], W[j - 8], W[j - 14], W[j - 16]), 1)
		end

		local a, b, c, d, e = h1, h2, h3, h4, h5
		for j = 1, 20 do
			local z = bit32_lrotate(a, 5) + bit32_band(b, c) + bit32_band(-1 - b, d) + 0x5A827999 + W[j] + e -- constant = math.floor(TWO_POW_30 * sqrt(2))
			e = d
			d = c
			c = bit32_rrotate(b, 2)
			b = a
			a = z
		end

		for j = 21, 40 do
			local z = bit32_lrotate(a, 5) + bit32_bxor(b, c, d) + 0x6ED9EBA1 + W[j] + e -- TWO_POW_30 * sqrt(3)
			e = d
			d = c
			c = bit32_rrotate(b, 2)
			b = a
			a = z
		end

		for j = 41, 60 do
			local z = bit32_lrotate(a, 5) + bit32_band(d, c) + bit32_band(b, bit32_bxor(d, c)) + 0x8F1BBCDC + W[j] + e -- TWO_POW_30 * sqrt(5)
			e = d
			d = c
			c = bit32_rrotate(b, 2)
			b = a
			a = z
		end

		for j = 61, 80 do
			local z = bit32_lrotate(a, 5) + bit32_bxor(b, c, d) + 0xCA62C1D6 + W[j] + e -- TWO_POW_30 * sqrt(10)
			e = d
			d = c
			c = bit32_rrotate(b, 2)
			b = a
			a = z
		end

		h1 = (a + h1) % 4294967296
		h2 = (b + h2) % 4294967296
		h3 = (c + h3) % 4294967296
		h4 = (d + h4) % 4294967296
		h5 = (e + h5) % 4294967296
	end

	H[1], H[2], H[3], H[4], H[5] = h1, h2, h3, h4, h5
end

local function keccak_feed(lanes_lo, lanes_hi, str, offs, size, block_size_in_bytes)
	-- This is an example of a Lua function having 79 local variables :-)
	-- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
	local RC_lo, RC_hi = sha3_RC_lo, sha3_RC_hi
	local qwords_qty = block_size_in_bytes / 8
	for pos = offs, offs + size - 1, block_size_in_bytes do
		for j = 1, qwords_qty do
			local a, b, c, d = string.byte(str, pos + 1, pos + 4)
			lanes_lo[j] = bit32_bxor(lanes_lo[j], ((d * 256 + c) * 256 + b) * 256 + a)
			pos = pos + 8
			a, b, c, d = string.byte(str, pos - 3, pos)
			lanes_hi[j] = bit32_bxor(lanes_hi[j], ((d * 256 + c) * 256 + b) * 256 + a)
		end

		local L01_lo, L01_hi, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi, L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi, L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi = lanes_lo[1], lanes_hi[1], lanes_lo[2], lanes_hi[2], lanes_lo[3], lanes_hi[3], lanes_lo[4], lanes_hi[4], lanes_lo[5], lanes_hi[5], lanes_lo[6], lanes_hi[6], lanes_lo[7], lanes_hi[7], lanes_lo[8], lanes_hi[8], lanes_lo[9], lanes_hi[9], lanes_lo[10], lanes_hi[10], lanes_lo[11], lanes_hi[11], lanes_lo[12], lanes_hi[12], lanes_lo[13], lanes_hi[13], lanes_lo[14], lanes_hi[14], lanes_lo[15], lanes_hi[15], lanes_lo[16], lanes_hi[16], lanes_lo[17], lanes_hi[17], lanes_lo[18], lanes_hi[18], lanes_lo[19], lanes_hi[19], lanes_lo[20], lanes_hi[20], lanes_lo[21], lanes_hi[21], lanes_lo[22], lanes_hi[22], lanes_lo[23], lanes_hi[23], lanes_lo[24], lanes_hi[24], lanes_lo[25], lanes_hi[25]

		for round_idx = 1, 24 do
			local C1_lo = bit32_bxor(L01_lo, L06_lo, L11_lo, L16_lo, L21_lo)
			local C1_hi = bit32_bxor(L01_hi, L06_hi, L11_hi, L16_hi, L21_hi)
			local C2_lo = bit32_bxor(L02_lo, L07_lo, L12_lo, L17_lo, L22_lo)
			local C2_hi = bit32_bxor(L02_hi, L07_hi, L12_hi, L17_hi, L22_hi)
			local C3_lo = bit32_bxor(L03_lo, L08_lo, L13_lo, L18_lo, L23_lo)
			local C3_hi = bit32_bxor(L03_hi, L08_hi, L13_hi, L18_hi, L23_hi)
			local C4_lo = bit32_bxor(L04_lo, L09_lo, L14_lo, L19_lo, L24_lo)
			local C4_hi = bit32_bxor(L04_hi, L09_hi, L14_hi, L19_hi, L24_hi)
			local C5_lo = bit32_bxor(L05_lo, L10_lo, L15_lo, L20_lo, L25_lo)
			local C5_hi = bit32_bxor(L05_hi, L10_hi, L15_hi, L20_hi, L25_hi)

			local D_lo = bit32_bxor(C1_lo, C3_lo * 2 + (C3_hi % TWO_POW_32 - C3_hi % TWO_POW_31) / TWO_POW_31)
			local D_hi = bit32_bxor(C1_hi, C3_hi * 2 + (C3_lo % TWO_POW_32 - C3_lo % TWO_POW_31) / TWO_POW_31)

			local T0_lo = bit32_bxor(D_lo, L02_lo)
			local T0_hi = bit32_bxor(D_hi, L02_hi)
			local T1_lo = bit32_bxor(D_lo, L07_lo)
			local T1_hi = bit32_bxor(D_hi, L07_hi)
			local T2_lo = bit32_bxor(D_lo, L12_lo)
			local T2_hi = bit32_bxor(D_hi, L12_hi)
			local T3_lo = bit32_bxor(D_lo, L17_lo)
			local T3_hi = bit32_bxor(D_hi, L17_hi)
			local T4_lo = bit32_bxor(D_lo, L22_lo)
			local T4_hi = bit32_bxor(D_hi, L22_hi)

			L02_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_20) / TWO_POW_20 + T1_hi * TWO_POW_12
			L02_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_20) / TWO_POW_20 + T1_lo * TWO_POW_12
			L07_lo = (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_19) / TWO_POW_19 + T3_hi * TWO_POW_13
			L07_hi = (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_19) / TWO_POW_19 + T3_lo * TWO_POW_13
			L12_lo = T0_lo * 2 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_31) / TWO_POW_31
			L12_hi = T0_hi * 2 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_31) / TWO_POW_31
			L17_lo = T2_lo * TWO_POW_10 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_22) / TWO_POW_22
			L17_hi = T2_hi * TWO_POW_10 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_22) / TWO_POW_22
			L22_lo = T4_lo * TWO_POW_2 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_30) / TWO_POW_30
			L22_hi = T4_hi * TWO_POW_2 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_30) / TWO_POW_30

			D_lo = bit32_bxor(C2_lo, C4_lo * 2 + (C4_hi % TWO_POW_32 - C4_hi % TWO_POW_31) / TWO_POW_31)
			D_hi = bit32_bxor(C2_hi, C4_hi * 2 + (C4_lo % TWO_POW_32 - C4_lo % TWO_POW_31) / TWO_POW_31)

			T0_lo = bit32_bxor(D_lo, L03_lo)
			T0_hi = bit32_bxor(D_hi, L03_hi)
			T1_lo = bit32_bxor(D_lo, L08_lo)
			T1_hi = bit32_bxor(D_hi, L08_hi)
			T2_lo = bit32_bxor(D_lo, L13_lo)
			T2_hi = bit32_bxor(D_hi, L13_hi)
			T3_lo = bit32_bxor(D_lo, L18_lo)
			T3_hi = bit32_bxor(D_hi, L18_hi)
			T4_lo = bit32_bxor(D_lo, L23_lo)
			T4_hi = bit32_bxor(D_hi, L23_hi)

			L03_lo = (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_21) / TWO_POW_21 + T2_hi * TWO_POW_11
			L03_hi = (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_21) / TWO_POW_21 + T2_lo * TWO_POW_11
			L08_lo = (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_3) / TWO_POW_3 + T4_hi * TWO_POW_29 % TWO_POW_32
			L08_hi = (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_3) / TWO_POW_3 + T4_lo * TWO_POW_29 % TWO_POW_32
			L13_lo = T1_lo * TWO_POW_6 + (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_26) / TWO_POW_26
			L13_hi = T1_hi * TWO_POW_6 + (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_26) / TWO_POW_26
			L18_lo = T3_lo * TWO_POW_15 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_17) / TWO_POW_17
			L18_hi = T3_hi * TWO_POW_15 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_17) / TWO_POW_17
			L23_lo = (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_2) / TWO_POW_2 + T0_hi * TWO_POW_30 % TWO_POW_32
			L23_hi = (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_2) / TWO_POW_2 + T0_lo * TWO_POW_30 % TWO_POW_32

			D_lo = bit32_bxor(C3_lo, C5_lo * 2 + (C5_hi % TWO_POW_32 - C5_hi % TWO_POW_31) / TWO_POW_31)
			D_hi = bit32_bxor(C3_hi, C5_hi * 2 + (C5_lo % TWO_POW_32 - C5_lo % TWO_POW_31) / TWO_POW_31)

			T0_lo = bit32_bxor(D_lo, L04_lo)
			T0_hi = bit32_bxor(D_hi, L04_hi)
			T1_lo = bit32_bxor(D_lo, L09_lo)
			T1_hi = bit32_bxor(D_hi, L09_hi)
			T2_lo = bit32_bxor(D_lo, L14_lo)
			T2_hi = bit32_bxor(D_hi, L14_hi)
			T3_lo = bit32_bxor(D_lo, L19_lo)
			T3_hi = bit32_bxor(D_hi, L19_hi)
			T4_lo = bit32_bxor(D_lo, L24_lo)
			T4_hi = bit32_bxor(D_hi, L24_hi)

			L04_lo = T3_lo * TWO_POW_21 % TWO_POW_32 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_11) / TWO_POW_11
			L04_hi = T3_hi * TWO_POW_21 % TWO_POW_32 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_11) / TWO_POW_11
			L09_lo = T0_lo * TWO_POW_28 % TWO_POW_32 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_4) / TWO_POW_4
			L09_hi = T0_hi * TWO_POW_28 % TWO_POW_32 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_4) / TWO_POW_4
			L14_lo = T2_lo * TWO_POW_25 % TWO_POW_32 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_7) / TWO_POW_7
			L14_hi = T2_hi * TWO_POW_25 % TWO_POW_32 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_7) / TWO_POW_7
			L19_lo = (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_8) / TWO_POW_8 + T4_hi * TWO_POW_24 % TWO_POW_32
			L19_hi = (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_8) / TWO_POW_8 + T4_lo * TWO_POW_24 % TWO_POW_32
			L24_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_9) / TWO_POW_9 + T1_hi * TWO_POW_23 % TWO_POW_32
			L24_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_9) / TWO_POW_9 + T1_lo * TWO_POW_23 % TWO_POW_32

			D_lo = bit32_bxor(C4_lo, C1_lo * 2 + (C1_hi % TWO_POW_32 - C1_hi % TWO_POW_31) / TWO_POW_31)
			D_hi = bit32_bxor(C4_hi, C1_hi * 2 + (C1_lo % TWO_POW_32 - C1_lo % TWO_POW_31) / TWO_POW_31)

			T0_lo = bit32_bxor(D_lo, L05_lo)
			T0_hi = bit32_bxor(D_hi, L05_hi)
			T1_lo = bit32_bxor(D_lo, L10_lo)
			T1_hi = bit32_bxor(D_hi, L10_hi)
			T2_lo = bit32_bxor(D_lo, L15_lo)
			T2_hi = bit32_bxor(D_hi, L15_hi)
			T3_lo = bit32_bxor(D_lo, L20_lo)
			T3_hi = bit32_bxor(D_hi, L20_hi)
			T4_lo = bit32_bxor(D_lo, L25_lo)
			T4_hi = bit32_bxor(D_hi, L25_hi)

			L05_lo = T4_lo * TWO_POW_14 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_18) / TWO_POW_18
			L05_hi = T4_hi * TWO_POW_14 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_18) / TWO_POW_18
			L10_lo = T1_lo * TWO_POW_20 % TWO_POW_32 + (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_12) / TWO_POW_12
			L10_hi = T1_hi * TWO_POW_20 % TWO_POW_32 + (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_12) / TWO_POW_12
			L15_lo = T3_lo * TWO_POW_8 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_24) / TWO_POW_24
			L15_hi = T3_hi * TWO_POW_8 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_24) / TWO_POW_24
			L20_lo = T0_lo * TWO_POW_27 % TWO_POW_32 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_5) / TWO_POW_5
			L20_hi = T0_hi * TWO_POW_27 % TWO_POW_32 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_5) / TWO_POW_5
			L25_lo = (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_25) / TWO_POW_25 + T2_hi * TWO_POW_7
			L25_hi = (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_25) / TWO_POW_25 + T2_lo * TWO_POW_7

			D_lo = bit32_bxor(C5_lo, C2_lo * 2 + (C2_hi % TWO_POW_32 - C2_hi % TWO_POW_31) / TWO_POW_31)
			D_hi = bit32_bxor(C5_hi, C2_hi * 2 + (C2_lo % TWO_POW_32 - C2_lo % TWO_POW_31) / TWO_POW_31)

			T1_lo = bit32_bxor(D_lo, L06_lo)
			T1_hi = bit32_bxor(D_hi, L06_hi)
			T2_lo = bit32_bxor(D_lo, L11_lo)
			T2_hi = bit32_bxor(D_hi, L11_hi)
			T3_lo = bit32_bxor(D_lo, L16_lo)
			T3_hi = bit32_bxor(D_hi, L16_hi)
			T4_lo = bit32_bxor(D_lo, L21_lo)
			T4_hi = bit32_bxor(D_hi, L21_hi)

			L06_lo = T2_lo * TWO_POW_3 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_29) / TWO_POW_29
			L06_hi = T2_hi * TWO_POW_3 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_29) / TWO_POW_29
			L11_lo = T4_lo * TWO_POW_18 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_14) / TWO_POW_14
			L11_hi = T4_hi * TWO_POW_18 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_14) / TWO_POW_14
			L16_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_28) / TWO_POW_28 + T1_hi * TWO_POW_4
			L16_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_28) / TWO_POW_28 + T1_lo * TWO_POW_4
			L21_lo = (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_23) / TWO_POW_23 + T3_hi * TWO_POW_9
			L21_hi = (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_23) / TWO_POW_23 + T3_lo * TWO_POW_9

			L01_lo = bit32_bxor(D_lo, L01_lo)
			L01_hi = bit32_bxor(D_hi, L01_hi)
			L01_lo, L02_lo, L03_lo, L04_lo, L05_lo = bit32_bxor(L01_lo, bit32_band(-1 - L02_lo, L03_lo)), bit32_bxor(L02_lo, bit32_band(-1 - L03_lo, L04_lo)), bit32_bxor(L03_lo, bit32_band(-1 - L04_lo, L05_lo)), bit32_bxor(L04_lo, bit32_band(-1 - L05_lo, L01_lo)), bit32_bxor(L05_lo, bit32_band(-1 - L01_lo, L02_lo))
			L01_hi, L02_hi, L03_hi, L04_hi, L05_hi = bit32_bxor(L01_hi, bit32_band(-1 - L02_hi, L03_hi)), bit32_bxor(L02_hi, bit32_band(-1 - L03_hi, L04_hi)), bit32_bxor(L03_hi, bit32_band(-1 - L04_hi, L05_hi)), bit32_bxor(L04_hi, bit32_band(-1 - L05_hi, L01_hi)), bit32_bxor(L05_hi, bit32_band(-1 - L01_hi, L02_hi))
			L06_lo, L07_lo, L08_lo, L09_lo, L10_lo = bit32_bxor(L09_lo, bit32_band(-1 - L10_lo, L06_lo)), bit32_bxor(L10_lo, bit32_band(-1 - L06_lo, L07_lo)), bit32_bxor(L06_lo, bit32_band(-1 - L07_lo, L08_lo)), bit32_bxor(L07_lo, bit32_band(-1 - L08_lo, L09_lo)), bit32_bxor(L08_lo, bit32_band(-1 - L09_lo, L10_lo))
			L06_hi, L07_hi, L08_hi, L09_hi, L10_hi = bit32_bxor(L09_hi, bit32_band(-1 - L10_hi, L06_hi)), bit32_bxor(L10_hi, bit32_band(-1 - L06_hi, L07_hi)), bit32_bxor(L06_hi, bit32_band(-1 - L07_hi, L08_hi)), bit32_bxor(L07_hi, bit32_band(-1 - L08_hi, L09_hi)), bit32_bxor(L08_hi, bit32_band(-1 - L09_hi, L10_hi))
			L11_lo, L12_lo, L13_lo, L14_lo, L15_lo = bit32_bxor(L12_lo, bit32_band(-1 - L13_lo, L14_lo)), bit32_bxor(L13_lo, bit32_band(-1 - L14_lo, L15_lo)), bit32_bxor(L14_lo, bit32_band(-1 - L15_lo, L11_lo)), bit32_bxor(L15_lo, bit32_band(-1 - L11_lo, L12_lo)), bit32_bxor(L11_lo, bit32_band(-1 - L12_lo, L13_lo))
			L11_hi, L12_hi, L13_hi, L14_hi, L15_hi = bit32_bxor(L12_hi, bit32_band(-1 - L13_hi, L14_hi)), bit32_bxor(L13_hi, bit32_band(-1 - L14_hi, L15_hi)), bit32_bxor(L14_hi, bit32_band(-1 - L15_hi, L11_hi)), bit32_bxor(L15_hi, bit32_band(-1 - L11_hi, L12_hi)), bit32_bxor(L11_hi, bit32_band(-1 - L12_hi, L13_hi))
			L16_lo, L17_lo, L18_lo, L19_lo, L20_lo = bit32_bxor(L20_lo, bit32_band(-1 - L16_lo, L17_lo)), bit32_bxor(L16_lo, bit32_band(-1 - L17_lo, L18_lo)), bit32_bxor(L17_lo, bit32_band(-1 - L18_lo, L19_lo)), bit32_bxor(L18_lo, bit32_band(-1 - L19_lo, L20_lo)), bit32_bxor(L19_lo, bit32_band(-1 - L20_lo, L16_lo))
			L16_hi, L17_hi, L18_hi, L19_hi, L20_hi = bit32_bxor(L20_hi, bit32_band(-1 - L16_hi, L17_hi)), bit32_bxor(L16_hi, bit32_band(-1 - L17_hi, L18_hi)), bit32_bxor(L17_hi, bit32_band(-1 - L18_hi, L19_hi)), bit32_bxor(L18_hi, bit32_band(-1 - L19_hi, L20_hi)), bit32_bxor(L19_hi, bit32_band(-1 - L20_hi, L16_hi))
			L21_lo, L22_lo, L23_lo, L24_lo, L25_lo = bit32_bxor(L23_lo, bit32_band(-1 - L24_lo, L25_lo)), bit32_bxor(L24_lo, bit32_band(-1 - L25_lo, L21_lo)), bit32_bxor(L25_lo, bit32_band(-1 - L21_lo, L22_lo)), bit32_bxor(L21_lo, bit32_band(-1 - L22_lo, L23_lo)), bit32_bxor(L22_lo, bit32_band(-1 - L23_lo, L24_lo))
			L21_hi, L22_hi, L23_hi, L24_hi, L25_hi = bit32_bxor(L23_hi, bit32_band(-1 - L24_hi, L25_hi)), bit32_bxor(L24_hi, bit32_band(-1 - L25_hi, L21_hi)), bit32_bxor(L25_hi, bit32_band(-1 - L21_hi, L22_hi)), bit32_bxor(L21_hi, bit32_band(-1 - L22_hi, L23_hi)), bit32_bxor(L22_hi, bit32_band(-1 - L23_hi, L24_hi))
			L01_lo = bit32_bxor(L01_lo, RC_lo[round_idx])
			L01_hi = L01_hi + RC_hi[round_idx] -- RC_hi[] is either 0 or 0x80000000, so we could use fast addition instead of slow XOR
		end

		lanes_lo[1] = L01_lo
		lanes_hi[1] = L01_hi
		lanes_lo[2] = L02_lo
		lanes_hi[2] = L02_hi
		lanes_lo[3] = L03_lo
		lanes_hi[3] = L03_hi
		lanes_lo[4] = L04_lo
		lanes_hi[4] = L04_hi
		lanes_lo[5] = L05_lo
		lanes_hi[5] = L05_hi
		lanes_lo[6] = L06_lo
		lanes_hi[6] = L06_hi
		lanes_lo[7] = L07_lo
		lanes_hi[7] = L07_hi
		lanes_lo[8] = L08_lo
		lanes_hi[8] = L08_hi
		lanes_lo[9] = L09_lo
		lanes_hi[9] = L09_hi
		lanes_lo[10] = L10_lo
		lanes_hi[10] = L10_hi
		lanes_lo[11] = L11_lo
		lanes_hi[11] = L11_hi
		lanes_lo[12] = L12_lo
		lanes_hi[12] = L12_hi
		lanes_lo[13] = L13_lo
		lanes_hi[13] = L13_hi
		lanes_lo[14] = L14_lo
		lanes_hi[14] = L14_hi
		lanes_lo[15] = L15_lo
		lanes_hi[15] = L15_hi
		lanes_lo[16] = L16_lo
		lanes_hi[16] = L16_hi
		lanes_lo[17] = L17_lo
		lanes_hi[17] = L17_hi
		lanes_lo[18] = L18_lo
		lanes_hi[18] = L18_hi
		lanes_lo[19] = L19_lo
		lanes_hi[19] = L19_hi
		lanes_lo[20] = L20_lo
		lanes_hi[20] = L20_hi
		lanes_lo[21] = L21_lo
		lanes_hi[21] = L21_hi
		lanes_lo[22] = L22_lo
		lanes_hi[22] = L22_hi
		lanes_lo[23] = L23_lo
		lanes_hi[23] = L23_hi
		lanes_lo[24] = L24_lo
		lanes_hi[24] = L24_hi
		lanes_lo[25] = L25_lo
		lanes_hi[25] = L25_hi
	end
end

--------------------------------------------------------------------------------
-- MAGIC NUMBERS CALCULATOR
--------------------------------------------------------------------------------
-- Q:
--	Is 53-bit "double" math enough to calculate square roots and cube roots of primes with 64 correct bits after decimal point?
-- A:
--	Yes, 53-bit "double" arithmetic is enough.
--	We could obtain first 40 bits by direct calculation of p^(1/3) and next 40 bits by one step of Newton's method.
do
	local function mul(src1, src2, factor, result_length)
		-- src1, src2 - long integers (arrays of digits in base TWO_POW_24)
		-- factor - small integer
		-- returns long integer result (src1 * src2 * factor) and its floating point approximation
		local result, carry, value, weight = table.create(result_length), 0, 0, 1
		for j = 1, result_length do
			for k = math.max(1, j + 1 - #src2), math.min(j, #src1) do
				carry = carry + factor * src1[k] * src2[j + 1 - k] -- "int32" is not enough for multiplication result, that's why "factor" must be of type "double"
			end

			local digit = carry % TWO_POW_24
			result[j] = math.floor(digit)
			carry = (carry - digit) / TWO_POW_24
			value = value + digit * weight
			weight = weight * TWO_POW_24
		end

		return result, value
	end

	local idx, step, p, one, sqrt_hi, sqrt_lo = 0, {4, 1, 2, -2, 2}, 4, {1}, sha2_H_hi, sha2_H_lo
	repeat
		p = p + step[p % 6]
		local d = 1
		repeat
			d = d + step[d % 6]
			if d * d > p then
				-- next prime number is found
				local root = p ^ (1 / 3)
				local R = root * TWO_POW_40
				R = mul(table.create(1, math.floor(R)), one, 1, 2)
				local _, delta = mul(R, mul(R, R, 1, 4), -1, 4)
				local hi = R[2] % 65536 * 65536 + math.floor(R[1] / 256)
				local lo = R[1] % 256 * 16777216 + math.floor(delta * (TWO_POW_NEG_56 / 3) * root / p)

				if idx < 16 then
					root = math.sqrt(p)
					R = root * TWO_POW_40
					R = mul(table.create(1, math.floor(R)), one, 1, 2)
					_, delta = mul(R, R, -1, 2)
					local hi = R[2] % 65536 * 65536 + math.floor(R[1] / 256)
					local lo = R[1] % 256 * 16777216 + math.floor(delta * TWO_POW_NEG_17 / root)
					local idx = idx % 8 + 1
					sha2_H_ext256[224][idx] = lo
					sqrt_hi[idx], sqrt_lo[idx] = hi, lo + hi * hi_factor
					if idx > 7 then
						sqrt_hi, sqrt_lo = sha2_H_ext512_hi[384], sha2_H_ext512_lo[384]
					end
				end

				idx = idx + 1
				sha2_K_hi[idx], sha2_K_lo[idx] = hi, lo % K_lo_modulo + hi * hi_factor
				break
			end
		until p % d == 0
	until idx > 79
end

-- Calculating IVs for SHA512/224 and SHA512/256
for width = 224, 256, 32 do
	local H_lo, H_hi = {}, nil
	if XOR64A5 then
		for j = 1, 8 do
			H_lo[j] = XOR64A5(sha2_H_lo[j])
		end
	else
		H_hi = {}
		for j = 1, 8 do
			H_lo[j] = bit32_bxor(sha2_H_lo[j], 0xA5A5A5A5) % 4294967296
			H_hi[j] = bit32_bxor(sha2_H_hi[j], 0xA5A5A5A5) % 4294967296
		end
	end

	sha512_feed_128(H_lo, H_hi, "SHA-512/" .. tostring(width) .. "\128" .. string.rep("\0", 115) .. "\88", 0, 128)
	sha2_H_ext512_lo[width] = H_lo
	sha2_H_ext512_hi[width] = H_hi
end

-- Constants for MD5
do
	for idx = 1, 64 do
		-- we can't use formula math.floor(abs(sin(idx))*TWO_POW_32) because its result may be beyond integer range on Lua built with 32-bit integers
		local hi, lo = math.modf(math.abs(math.sin(idx)) * TWO_POW_16)
		md5_K[idx] = hi * 65536 + math.floor(lo * TWO_POW_16)
	end
end

-- Constants for SHA3
do
	local sh_reg = 29
	local function next_bit()
		local r = sh_reg % 2
		sh_reg = bit32_bxor((sh_reg - r) / 2, 142 * r)
		return r
	end

	for idx = 1, 24 do
		local lo, m = 0, nil
		for _ = 1, 6 do
			m = m and m * m * 2 or 1
			lo = lo + next_bit() * m
		end

		local hi = next_bit() * m
		sha3_RC_hi[idx], sha3_RC_lo[idx] = hi, lo + hi * hi_factor_keccak
	end
end

--------------------------------------------------------------------------------
-- MAIN FUNCTIONS
--------------------------------------------------------------------------------
local function sha256ext(width, message)
	-- Create an instance (private objects for current calculation)
	local Array256 = sha2_H_ext256[width] -- # == 8
	local length, tail = 0, ""
	local H = table.create(8)
	H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = Array256[1], Array256[2], Array256[3], Array256[4], Array256[5], Array256[6], Array256[7], Array256[8]

	local function partial(message_part)
		if message_part then
			local partLength = #message_part
			if tail then
				length = length + partLength
				local offs = 0
				local tailLength = #tail
				if tail ~= "" and tailLength + partLength >= 64 then
					offs = 64 - tailLength
					sha256_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
					tail = ""
				end

				local size = partLength - offs
				local size_tail = size % 64
				sha256_feed_64(H, message_part, offs, size - size_tail)
				tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
				return partial
			else
				error("Adding more chunks is not allowed after receiving the result", 2)
			end
		else
			if tail then
				local final_blocks = table.create(10) --{tail, "\128", string.rep("\0", (-9 - length) % 64 + 1)}
				final_blocks[1] = tail
				final_blocks[2] = "\128"
				final_blocks[3] = string.rep("\0", (-9 - length) % 64 + 1)

				tail = nil
				-- Assuming user data length is shorter than (TWO_POW_53)-9 bytes
				-- Anyway, it looks very unrealistic that someone would spend more than a year of calculations to process TWO_POW_53 bytes of data by using this Lua script :-)
				-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
				length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move decimal point to the left
				for j = 4, 10 do
					length = length % 1 * 256
					final_blocks[j] = string.char(math.floor(length))
				end

				final_blocks = table.concat(final_blocks)
				sha256_feed_64(H, final_blocks, 0, #final_blocks)
				local max_reg = width / 32
				for j = 1, max_reg do
					H[j] = string.format("%08x", H[j] % 4294967296)
				end

				H = table.concat(H, "", 1, max_reg)
			end

			return H
		end
	end

	if message then
		-- Actually perform calculations and return the SHA256 digest of a message
		return partial(message)()
	else
		-- Return function for chunk-by-chunk loading
		-- User should feed every chunk of input data as single argument to this function and finally get SHA256 digest by invoking this function without an argument
		return partial
	end
end

local function sha512ext(width, message)

	-- Create an instance (private objects for current calculation)
	local length, tail, H_lo, H_hi = 0, "", table.pack(table.unpack(sha2_H_ext512_lo[width])), not HEX64 and table.pack(table.unpack(sha2_H_ext512_hi[width]))

	local function partial(message_part)
		if message_part then
			local partLength = #message_part
			if tail then
				length = length + partLength
				local offs = 0
				if tail ~= "" and #tail + partLength >= 128 then
					offs = 128 - #tail
					sha512_feed_128(H_lo, H_hi, tail .. string.sub(message_part, 1, offs), 0, 128)
					tail = ""
				end

				local size = partLength - offs
				local size_tail = size % 128
				sha512_feed_128(H_lo, H_hi, message_part, offs, size - size_tail)
				tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
				return partial
			else
				error("Adding more chunks is not allowed after receiving the result", 2)
			end
		else
			if tail then
				local final_blocks = table.create(3) --{tail, "\128", string.rep("\0", (-17-length) % 128 + 9)}
				final_blocks[1] = tail
				final_blocks[2] = "\128"
				final_blocks[3] = string.rep("\0", (-17 - length) % 128 + 9)

				tail = nil
				-- Assuming user data length is shorter than (TWO_POW_53)-17 bytes
				-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
				length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move floating point to the left
				for j = 4, 10 do
					length = length % 1 * 256
					final_blocks[j] = string.char(math.floor(length))
				end

				final_blocks = table.concat(final_blocks)
				sha512_feed_128(H_lo, H_hi, final_blocks, 0, #final_blocks)
				local max_reg = math.ceil(width / 64)

				if HEX64 then
					for j = 1, max_reg do
						H_lo[j] = HEX64(H_lo[j])
					end
				else
					for j = 1, max_reg do
						H_lo[j] = string.format("%08x", H_hi[j] % 4294967296) .. string.format("%08x", H_lo[j] % 4294967296)
					end

					H_hi = nil
				end

				H_lo = string.sub(table.concat(H_lo, "", 1, max_reg), 1, width / 4)
			end

			return H_lo
		end
	end

	if message then
		-- Actually perform calculations and return the SHA512 digest of a message
		return partial(message)()
	else
		-- Return function for chunk-by-chunk loading
		-- User should feed every chunk of input data as single argument to this function and finally get SHA512 digest by invoking this function without an argument
		return partial
	end
end

local function md5(message)

	-- Create an instance (private objects for current calculation)
	local H, length, tail = table.create(4), 0, ""
	H[1], H[2], H[3], H[4] = md5_sha1_H[1], md5_sha1_H[2], md5_sha1_H[3], md5_sha1_H[4]

	local function partial(message_part)
		if message_part then
			local partLength = #message_part
			if tail then
				length = length + partLength
				local offs = 0
				if tail ~= "" and #tail + partLength >= 64 then
					offs = 64 - #tail
					md5_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
					tail = ""
				end

				local size = partLength - offs
				local size_tail = size % 64
				md5_feed_64(H, message_part, offs, size - size_tail)
				tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
				return partial
			else
				error("Adding more chunks is not allowed after receiving the result", 2)
			end
		else
			if tail then
				local final_blocks = table.create(3) --{tail, "\128", string.rep("\0", (-9 - length) % 64)}
				final_blocks[1] = tail
				final_blocks[2] = "\128"
				final_blocks[3] = string.rep("\0", (-9 - length) % 64)
				tail = nil
				length = length * 8 -- convert "byte-counter" to "bit-counter"
				for j = 4, 11 do
					local low_byte = length % 256
					final_blocks[j] = string.char(low_byte)
					length = (length - low_byte) / 256
				end

				final_blocks = table.concat(final_blocks)
				md5_feed_64(H, final_blocks, 0, #final_blocks)
				for j = 1, 4 do
					H[j] = string.format("%08x", H[j] % 4294967296)
				end

				H = string.gsub(table.concat(H), "(..)(..)(..)(..)", "%4%3%2%1")
			end

			return H
		end
	end

	if message then
		-- Actually perform calculations and return the MD5 digest of a message
		return partial(message)()
	else
		-- Return function for chunk-by-chunk loading
		-- User should feed every chunk of input data as single argument to this function and finally get MD5 digest by invoking this function without an argument
		return partial
	end
end

local function sha1(message)
	-- Create an instance (private objects for current calculation)
	local H, length, tail = table.pack(table.unpack(md5_sha1_H)), 0, ""

	local function partial(message_part)
		if message_part then
			local partLength = #message_part
			if tail then
				length = length + partLength
				local offs = 0
				if tail ~= "" and #tail + partLength >= 64 then
					offs = 64 - #tail
					sha1_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
					tail = ""
				end

				local size = partLength - offs
				local size_tail = size % 64
				sha1_feed_64(H, message_part, offs, size - size_tail)
				tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
				return partial
			else
				error("Adding more chunks is not allowed after receiving the result", 2)
			end
		else
			if tail then
				local final_blocks = table.create(10) --{tail, "\128", string.rep("\0", (-9 - length) % 64 + 1)}
				final_blocks[1] = tail
				final_blocks[2] = "\128"
				final_blocks[3] = string.rep("\0", (-9 - length) % 64 + 1)
				tail = nil

				-- Assuming user data length is shorter than (TWO_POW_53)-9 bytes
				-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
				length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move decimal point to the left
				for j = 4, 10 do
					length = length % 1 * 256
					final_blocks[j] = string.char(math.floor(length))
				end

				final_blocks = table.concat(final_blocks)
				sha1_feed_64(H, final_blocks, 0, #final_blocks)
				for j = 1, 5 do
					H[j] = string.format("%08x", H[j] % 4294967296)
				end

				H = table.concat(H)
			end

			return H
		end
	end

	if message then
		-- Actually perform calculations and return the SHA-1 digest of a message
		return partial(message)()
	else
		-- Return function for chunk-by-chunk loading
		-- User should feed every chunk of input data as single argument to this function and finally get SHA-1 digest by invoking this function without an argument
		return partial
	end
end

local function keccak(block_size_in_bytes, digest_size_in_bytes, is_SHAKE, message)
	-- "block_size_in_bytes" is multiple of 8
	if type(digest_size_in_bytes) ~= "number" then
		-- arguments in SHAKE are swapped:
		--	NIST FIPS 202 defines SHAKE(message,num_bits)
		--	this module   defines SHAKE(num_bytes,message)
		-- it's easy to forget about this swap, hence the check
		error("Argument 'digest_size_in_bytes' must be a number", 2)
	end

	-- Create an instance (private objects for current calculation)
	local tail, lanes_lo, lanes_hi = "", table.create(25, 0), hi_factor_keccak == 0 and table.create(25, 0)
	local result

	--~	 pad the input N using the pad function, yielding a padded bit string P with a length divisible by r (such that n = len(P)/r is integer),
	--~	 break P into n consecutive r-bit pieces P0, ..., Pn-1 (last is zero-padded)
	--~	 initialize the state S to a string of b 0 bits.
	--~	 absorb the input into the state: For each block Pi,
	--~		 extend Pi at the end by a string of c 0 bits, yielding one of length b,
	--~		 XOR that with S and
	--~		 apply the block permutation f to the result, yielding a new state S
	--~	 initialize Z to be the empty string
	--~	 while the length of Z is less than d:
	--~		 append the first r bits of S to Z
	--~		 if Z is still less than d bits long, apply f to S, yielding a new state S.
	--~	 truncate Z to d bits
	local function partial(message_part)
		if message_part then
			local partLength = #message_part
			if tail then
				local offs = 0
				if tail ~= "" and #tail + partLength >= block_size_in_bytes then
					offs = block_size_in_bytes - #tail
					keccak_feed(lanes_lo, lanes_hi, tail .. string.sub(message_part, 1, offs), 0, block_size_in_bytes, block_size_in_bytes)
					tail = ""
				end

				local size = partLength - offs
				local size_tail = size % block_size_in_bytes
				keccak_feed(lanes_lo, lanes_hi, message_part, offs, size - size_tail, block_size_in_bytes)
				tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
				return partial
			else
				error("Adding more chunks is not allowed after receiving the result", 2)
			end
		else
			if tail then
				-- append the following bits to the message: for usual SHA3: 011(0*)1, for SHAKE: 11111(0*)1
				local gap_start = is_SHAKE and 31 or 6
				tail = tail .. (#tail + 1 == block_size_in_bytes and string.char(gap_start + 128) or string.char(gap_start) .. string.rep("\0", (-2 - #tail) % block_size_in_bytes) .. "\128")
				keccak_feed(lanes_lo, lanes_hi, tail, 0, #tail, block_size_in_bytes)
				tail = nil

				local lanes_used = 0
				local total_lanes = math.floor(block_size_in_bytes / 8)
				local qwords = {}

				local function get_next_qwords_of_digest(qwords_qty)
					-- returns not more than 'qwords_qty' qwords ('qwords_qty' might be non-integer)
					-- doesn't go across keccak-buffer boundary
					-- block_size_in_bytes is a multiple of 8, so, keccak-buffer contains integer number of qwords
					if lanes_used >= total_lanes then
						keccak_feed(lanes_lo, lanes_hi, "\0\0\0\0\0\0\0\0", 0, 8, 8)
						lanes_used = 0
					end

					qwords_qty = math.floor(math.min(qwords_qty, total_lanes - lanes_used))
					if hi_factor_keccak ~= 0 then
						for j = 1, qwords_qty do
							qwords[j] = HEX64(lanes_lo[lanes_used + j - 1 + lanes_index_base])
						end
					else
						for j = 1, qwords_qty do
							qwords[j] = string.format("%08x", lanes_hi[lanes_used + j] % 4294967296) .. string.format("%08x", lanes_lo[lanes_used + j] % 4294967296)
						end
					end

					lanes_used = lanes_used + qwords_qty
					return string.gsub(table.concat(qwords, "", 1, qwords_qty), "(..)(..)(..)(..)(..)(..)(..)(..)", "%8%7%6%5%4%3%2%1"), qwords_qty * 8
				end

				local parts = {} -- digest parts
				local last_part, last_part_size = "", 0

				local function get_next_part_of_digest(bytes_needed)
					-- returns 'bytes_needed' bytes, for arbitrary integer 'bytes_needed'
					bytes_needed = bytes_needed or 1
					if bytes_needed <= last_part_size then
						last_part_size = last_part_size - bytes_needed
						local part_size_in_nibbles = bytes_needed * 2
						local result = string.sub(last_part, 1, part_size_in_nibbles)
						last_part = string.sub(last_part, part_size_in_nibbles + 1)
						return result
					end

					local parts_qty = 0
					if last_part_size > 0 then
						parts_qty = 1
						parts[parts_qty] = last_part
						bytes_needed = bytes_needed - last_part_size
					end

					-- repeats until the length is enough
					while bytes_needed >= 8 do
						local next_part, next_part_size = get_next_qwords_of_digest(bytes_needed / 8)
						parts_qty = parts_qty + 1
						parts[parts_qty] = next_part
						bytes_needed = bytes_needed - next_part_size
					end

					if bytes_needed > 0 then
						last_part, last_part_size = get_next_qwords_of_digest(1)
						parts_qty = parts_qty + 1
						parts[parts_qty] = get_next_part_of_digest(bytes_needed)
					else
						last_part, last_part_size = "", 0
					end

					return table.concat(parts, "", 1, parts_qty)
				end

				if digest_size_in_bytes < 0 then
					result = get_next_part_of_digest
				else
					result = get_next_part_of_digest(digest_size_in_bytes)
				end

			end

			return result
		end
	end

	if message then
		-- Actually perform calculations and return the SHA3 digest of a message
		return partial(message)()
	else
		-- Return function for chunk-by-chunk loading
		-- User should feed every chunk of input data as single argument to this function and finally get SHA3 digest by invoking this function without an argument
		return partial
	end
end

local function HexToBinFunction(hh)
	return string.char(tonumber(hh, 16))
end

local function hex2bin(hex_string)
	return (string.gsub(hex_string, "%x%x", HexToBinFunction))
end

local base64_symbols = {
	["+"] = 62, ["-"] = 62, [62] = "+";
	["/"] = 63, ["_"] = 63, [63] = "/";
	["="] = -1, ["."] = -1, [-1] = "=";
}

local symbol_index = 0
for j, pair in ipairs{"AZ", "az", "09"} do
	for ascii = string.byte(pair), string.byte(pair, 2) do
		local ch = string.char(ascii)
		base64_symbols[ch] = symbol_index
		base64_symbols[symbol_index] = ch
		symbol_index = symbol_index + 1
	end
end

local function bin2base64(binary_string)
	local stringLength = #binary_string
	local result = table.create(math.ceil(stringLength / 3))
	local length = 0

	for pos = 1, #binary_string, 3 do
		local c1, c2, c3, c4 = string.byte(string.sub(binary_string, pos, pos + 2) .. '\0', 1, -1)
		length = length + 1
		result[length] =
			base64_symbols[math.floor(c1 / 4)] ..
			base64_symbols[c1 % 4 * 16 + math.floor(c2 / 16)] ..
			base64_symbols[c3 and c2 % 16 * 4 + math.floor(c3 / 64) or -1] ..
			base64_symbols[c4 and c3 % 64 or -1]
	end

	return table.concat(result)
end

local function base642bin(base64_string)
	local result, chars_qty = {}, 3
	for pos, ch in string.gmatch(string.gsub(base64_string, "%s+", ""), "()(.)") do
		local code = base64_symbols[ch]
		if code < 0 then
			chars_qty = chars_qty - 1
			code = 0
		end

		local idx = pos % 4
		if idx > 0 then
			result[-idx] = code
		else
			local c1 = result[-1] * 4 + math.floor(result[-2] / 16)
			local c2 = (result[-2] % 16) * 16 + math.floor(result[-3] / 4)
			local c3 = (result[-3] % 4) * 64 + code
			result[#result + 1] = string.sub(string.char(c1, c2, c3), 1, chars_qty)
		end
	end

	return table.concat(result)
end

local block_size_for_HMAC -- this table will be initialized at the end of the module
--local function pad_and_xor(str, result_length, byte_for_xor)
--	return string.gsub(str, ".", function(c)
--		return string.char(bit32_bxor(string.byte(c), byte_for_xor))
--	end) .. string.rep(string.char(byte_for_xor), result_length - #str)
--end

-- For the sake of speed of converting hexes to strings, there's a map of the conversions here
local BinaryStringMap = {}
for Index = 0, 255 do
	BinaryStringMap[string.format("%02x", Index)] = string.char(Index)
end

-- Update 02.14.20 - added AsBinary for easy GameAnalytics replacement.
local function hmac(hash_func, key, message, AsBinary)
	-- Create an instance (private objects for current calculation)
	local block_size = block_size_for_HMAC[hash_func]
	if not block_size then
		error("Unknown hash function", 2)
	end

	local KeyLength = #key
	if KeyLength > block_size then
		key = string.gsub(hash_func(key), "%x%x", HexToBinFunction)
		KeyLength = #key
	end

	local append = hash_func()(string.gsub(key, ".", function(c)
		return string.char(bit32_bxor(string.byte(c), 0x36))
	end) .. string.rep("6", block_size - KeyLength)) -- 6 = string.char(0x36)

	local result

	local function partial(message_part)
		if not message_part then
			result = result or hash_func(
				string.gsub(key, ".", function(c)
					return string.char(bit32_bxor(string.byte(c), 0x5c))
				end) .. string.rep("\\", block_size - KeyLength) -- \ = string.char(0x5c)
				.. (string.gsub(append(), "%x%x", HexToBinFunction))
			)

			return result
		elseif result then
			error("Adding more chunks is not allowed after receiving the result", 2)
		else
			append(message_part)
			return partial
		end
	end

	if message then
		-- Actually perform calculations and return the HMAC of a message
		local FinalMessage = partial(message)()
		return AsBinary and (string.gsub(FinalMessage, "%x%x", BinaryStringMap)) or FinalMessage
	else
		-- Return function for chunk-by-chunk loading of a message
		-- User should feed every chunk of the message as single argument to this function and finally get HMAC by invoking this function without an argument
		return partial
	end
end

local sha = {
	md5 = md5,
	sha1 = sha1,
	-- SHA2 hash functions:
	sha224 = function(message)
		return sha256ext(224, message)
	end;

	sha256 = function(message)
		return sha256ext(256, message)
	end;

	sha512_224 = function(message)
		return sha512ext(224, message)
	end;

	sha512_256 = function(message)
		return sha512ext(256, message)
	end;

	sha384 = function(message)
		return sha512ext(384, message)
	end;

	sha512 = function(message)
		return sha512ext(512, message)
	end;

	-- SHA3 hash functions:
	sha3_224 = function(message)
		return keccak((1600 - 2 * 224) / 8, 224 / 8, false, message)
	end;

	sha3_256 = function(message)
		return keccak((1600 - 2 * 256) / 8, 256 / 8, false, message)
	end;

	sha3_384 = function(message)
		return keccak((1600 - 2 * 384) / 8, 384 / 8, false, message)
	end;

	sha3_512 = function(message)
		return keccak((1600 - 2 * 512) / 8, 512 / 8, false, message)
	end;

	shake128 = function(message, digest_size_in_bytes)
		return keccak((1600 - 2 * 128) / 8, digest_size_in_bytes, true, message)
	end;

	shake256 = function(message, digest_size_in_bytes)
		return keccak((1600 - 2 * 256) / 8, digest_size_in_bytes, true, message)
	end;

	-- misc utilities:
	hmac = hmac; -- HMAC(hash_func, key, message) is applicable to any hash function from this module except SHAKE*
	hex_to_bin = hex2bin; -- converts hexadecimal representation to binary string
	base64_to_bin = base642bin; -- converts base64 representation to binary string
	bin_to_base64 = bin2base64; -- converts binary string to base64 representation
}

block_size_for_HMAC = {
	[sha.md5] = 64;
	[sha.sha1] = 64;
	[sha.sha224] = 64;
	[sha.sha256] = 64;
	[sha.sha512_224] = 128;
	[sha.sha512_256] = 128;
	[sha.sha384] = 128;
	[sha.sha512] = 128;
	[sha.sha3_224] = (1600 - 2 * 224) / 8;
	[sha.sha3_256] = (1600 - 2 * 256) / 8;
	[sha.sha3_384] = (1600 - 2 * 384) / 8;
	[sha.sha3_512] = (1600 - 2 * 512) / 8;
}

return sha
end)()
local prediction = (function()
--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
local module = {}
local eps = 1e-9
local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1

	local p, q, D

	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else -- if (D > 0)
		local sqrt_D = math.sqrt(D)

		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2

	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0

	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	cb_p = p * p * p
	D = q * q + cb_p

	if isZero(D) then
		if isZero(q) then -- one triple solution
			s0 = 0
			num = 1
		else -- one single and one double solution
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then -- Casus irreducibilis: three real solutions
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)

		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else -- one real solution
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)

		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local s0, s1, s2, s3

	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1

		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1

		do
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = #results
			s0, s1 = results[1], results[2]
		end

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		if (num == 0) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s0, s1 = results[1], results[2]
		end
		if (num == 1) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s1, s2 = results[1], results[2]
		end
		if (num == 2) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s2, s3 = results[1], results[2]
		end
	end

	sub = 0.25 * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	if (num > 3) then s3 = s3 - sub end

	return {s3, s2, s1, s0}
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
	local disp = targetPos - origin
	local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -.5 * gravity
	--attemped gravity calculation, may return to it in the future.
	if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
		local estTime = (disp.Magnitude / projectileSpeed)
		local origq = q
		local origj = j
		for i = 1, 100 do
			q -= (.5 * playerGravity) * estTime
			local velo = targetVelocity * 0.016
			local ray = workspace.Raycast(workspace, Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
			if ray then
				local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
				estTime -= math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
				targetPos = newTarget
				j = (targetPos - origin).Y
				q = 0
				break
			else
				break
			end
		end
	end

	local solutions = module.solveQuartic(
		l*l,
		-2*q*l,
		q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
		2*j*q + 2*h*p + 2*k*r,
		j*j + h*h + k*k
	)
	if solutions then
		local posRoots = table.create(2)
		for _, v in solutions do --filter out the negative roots
			if v > 0 then
				table.insert(posRoots, v)
			end
		end
		posRoots[1] = posRoots[1]
		if posRoots[1] then
			local t = posRoots[1]
			local d = (h + p*t)/t
			local e = (j + q*t - l*t*t)/t
			local f = (k + r*t)/t
			return origin + Vector3.new(d, e, f)
		end
	elseif gravity == 0 then
		local t = (disp.Magnitude / projectileSpeed)
		local d = (h + p*t)/t
		local e = (j + q*t - l*t*t)/t
		local f = (k + r*t)/t
		return origin + Vector3.new(d, e, f)
	end
end

return module
end)()
entitylib = (function()
local entitylib = {
	isAlive = false,
	character = {},
	List = {},
	Connections = {},
	PlayerConnections = {},
	EntityThreads = {},
	Running = false,
	Events = setmetatable({}, {
		__index = function(self, ind)
			self[ind] = {
				Connections = {},
				Connect = function(rself, func)
					table.insert(rself.Connections, func)
					return {
						Disconnect = function()
							local rind = table.find(rself.Connections, func)
							if rind then
								table.remove(rself.Connections, rind)
							end
						end
					}
				end,
				Fire = function(rself, ...)
					for _, v in rself.Connections do
						task.spawn(v, ...)
					end
				end,
				Destroy = function(rself)
					table.clear(rself.Connections)
					table.clear(rself)
				end
			}

			return self[ind]
		end
	})
}

local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local lplr = playersService.LocalPlayer
local gameCamera = workspace.CurrentCamera

local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCamera.ViewportSize / 2
	end
	return inputService.GetMouseLocation(inputService)
end

local function loopClean(tbl)
	for i, v in tbl do
		if type(v) == 'table' then
			loopClean(v)
		end
		tbl[i] = nil
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local checktick = tick() + timeout
	local returned
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned or checktick < tick() then break end
		task.wait()
	until false
	return returned
end

entitylib.targetCheck = function(ent)
	if ent.TeamCheck then
		return ent:TeamCheck()
	end
	if ent.NPC then return true end
	if not lplr.Team then return true end
	if not ent.Player.Team then return true end
	if ent.Player.Team ~= lplr.Team then return true end
	return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
end

entitylib.getUpdateConnections = function(ent)
	local hum = ent.Humanoid
	return {
		hum:GetPropertyChangedSignal('Health'),
		hum:GetPropertyChangedSignal('MaxHealth')
	}
end

entitylib.isVulnerable = function(ent)
	return ent.Health > 0 and not ent.Character.FindFirstChildWhichIsA(ent.Character, 'ForceField')
end

entitylib.getEntityColor = function(ent)
	ent = ent.Player
	return ent and tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
end

entitylib.IgnoreObject = RaycastParams.new()
entitylib.IgnoreObject.RespectCanCollide = true
entitylib.Wallcheck = function(origin, position, ignoreobject)
	if typeof(ignoreobject) ~= 'Instance' then
		local ignorelist = {gameCamera, lplr.Character}
		for _, v in entitylib.List do
			if v.Targetable then
				table.insert(ignorelist, v.Character)
			end
		end

		if typeof(ignoreobject) == 'table' then
			for _, v in ignoreobject do
				table.insert(ignorelist, v)
			end
		end

		ignoreobject = entitylib.IgnoreObject
		ignoreobject.FilterDescendantsInstances = ignorelist
	end
	return workspace.Raycast(workspace, origin, (position - origin), ignoreobject)
end

entitylib.EntityMouse = function(entitysettings)
	if entitylib.isAlive then
		local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
		for _, v in entitylib.List do
			if not entitysettings.Players and v.Player then continue end
			if not entitysettings.NPCs and v.NPC then continue end
			if not v.Targetable then continue end
			local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v[entitysettings.Part].Position)
			if not vis then continue end
			local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(v) then
				table.insert(sortingTable, {
					Entity = v,
					Magnitude = v.Target and -1 or mag
				})
			end
		end

		table.sort(sortingTable, entitysettings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		for _, v in sortingTable do
			if entitysettings.Wallcheck then
				if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
			end
			table.clear(entitysettings)
			table.clear(sortingTable)
			return v.Entity
		end
		table.clear(sortingTable)
	end
	table.clear(entitysettings)
end

entitylib.EntityPosition = function(entitysettings)
	if entitylib.isAlive then
		local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
		for _, v in entitylib.List do
			if not entitysettings.Players and v.Player then continue end
			if not entitysettings.NPCs and v.NPC then continue end
			if not v.Targetable then continue end
			local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(v) then
				table.insert(sortingTable, {
					Entity = v,
					Magnitude = v.Target and -1 or mag
				})
			end
		end

		table.sort(sortingTable, entitysettings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		for _, v in sortingTable do
			if entitysettings.Wallcheck then
				if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
			end
			table.clear(entitysettings)
			table.clear(sortingTable)
			return v.Entity
		end
		table.clear(sortingTable)
	end
	table.clear(entitysettings)
end

entitylib.AllPosition = function(entitysettings)
	local returned = {}
	if entitylib.isAlive then
		local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
		for _, v in entitylib.List do
			if not entitysettings.Players and v.Player then continue end
			if not entitysettings.NPCs and v.NPC then continue end
			if not v.Targetable then continue end
			local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(v) then
				table.insert(sortingTable, {Entity = v, Magnitude = v.Target and -1 or mag})
			end
		end

		table.sort(sortingTable, entitysettings.Sort or function(a, b)
			return a.Magnitude < b.Magnitude
		end)

		for _, v in sortingTable do
			if entitysettings.Wallcheck then
				if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
			end
			table.insert(returned, v.Entity)
			if #returned >= (entitysettings.Limit or math.huge) then break end
		end
		table.clear(sortingTable)
	end
	table.clear(entitysettings)
	return returned
end

entitylib.getEntity = function(char)
	for i, v in entitylib.List do
		if v.Player == char or v.Character == char then
			return v, i
		end
	end
end

entitylib.addEntity = function(char, plr, teamfunc, spawntime)
	if not char then return end
	entitylib.EntityThreads[char] = task.spawn(function()
		local hum = waitForChildOfType(char, 'Humanoid', 10)
		local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
		local head = char:WaitForChild('Head', 10) or humrootpart

		if hum and humrootpart then
			local entity = {
				Connections = {},
				Character = char,
				Health = hum.Health,
				Head = head,
				Humanoid = hum,
				HumanoidRootPart = humrootpart,
				HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
				MaxHealth = hum.MaxHealth,
				NPC = plr == nil,
				Player = plr,
				RootPart = humrootpart,
				SpawnTime = spawntime or 0,
				TeamCheck = teamfunc
			}

			if plr == lplr then
				entitylib.character = entity
				entitylib.isAlive = true
				entitylib.Events.LocalAdded:Fire(entity)
			else
				entity.Targetable = entitylib.targetCheck(entity)

				for _, v in entitylib.getUpdateConnections(entity) do
					table.insert(entity.Connections, v:Connect(function()
						entity.Health = hum.Health
						entity.MaxHealth = hum.MaxHealth
						entitylib.Events.EntityUpdated:Fire(entity)
					end))
				end

				table.insert(entitylib.List, entity)
				entitylib.Events.EntityAdded:Fire(entity)
			end
			--[[table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
				if (part == humrootpart or part == hum or part == head) then
					local found = char:FindFirstChild(part.Name)
					if found then
						if part == humrootpart then
							entity.HumanoidRootPart = found
							entity.RootPart = found
							humrootpart = found
							return
						elseif part == head then
							entity.Head = found
							head = found
							return
						end
					end
					entitylib.removeEntity(char, plr == lplr)
				end
			end))]]
		end
		entitylib.EntityThreads[char] = nil
	end)
end

entitylib.removeEntity = function(char, localcheck)
	if localcheck then
		if entitylib.isAlive then
			entitylib.isAlive = false
			for _, v in entitylib.character.Connections do
				v:Disconnect()
			end
			table.clear(entitylib.character.Connections)
			entitylib.Events.LocalRemoved:Fire(entitylib.character)
			--table.clear(entitylib.character)
		end
		return
	end

	if char then
		if entitylib.EntityThreads[char] then
			task.cancel(entitylib.EntityThreads[char])
			entitylib.EntityThreads[char] = nil
		end

		local entity, ind = entitylib.getEntity(char)
		if ind then
			for _, v in entity.Connections do
				v:Disconnect()
			end
			table.clear(entity.Connections)
			table.remove(entitylib.List, ind)
			entitylib.Events.EntityRemoved:Fire(entity)
		end
	end
end

entitylib.refreshEntity = function(char, plr, spawntime)
	entitylib.removeEntity(char)
	entitylib.addEntity(char, plr, nil, spawntime)
end

entitylib.addPlayer = function(plr)
	if plr.Character then
		entitylib.refreshEntity(plr.Character, plr)
	end
	entitylib.PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(char)
			entitylib.refreshEntity(char, plr, os.clock() + 0.4)
		end),
		plr.CharacterRemoving:Connect(function(char)
			entitylib.removeEntity(char, plr == lplr)
		end),
		plr:GetPropertyChangedSignal('Team'):Connect(function()
			if plr == lplr then
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end
			else
				entitylib.refreshEntity(plr.Character, plr)
			end
		end)
	}
end

entitylib.removePlayer = function(plr)
	if entitylib.PlayerConnections[plr] then
		for _, v in entitylib.PlayerConnections[plr] do
			v:Disconnect()
		end
		table.clear(entitylib.PlayerConnections[plr])
		entitylib.PlayerConnections[plr] = nil
	end
	entitylib.removeEntity(plr)
end

entitylib.start = function()
	if entitylib.Running then
		entitylib.stop()
	end
	table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
		entitylib.addPlayer(v)
	end))
	table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
		entitylib.removePlayer(v)
	end))
	for _, v in playersService:GetPlayers() do
		entitylib.addPlayer(v)
	end
	table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
	entitylib.Running = true
end

entitylib.stop = function()
	for _, v in entitylib.Connections do
		v:Disconnect()
	end
	for _, v in entitylib.PlayerConnections do
		for _, v2 in v do
			v2:Disconnect()
		end
		table.clear(v)
	end
	entitylib.removeEntity(nil, true)
	local cloned = table.clone(entitylib.List)
	for _, v in cloned do
		entitylib.removeEntity(v.Character)
	end
	for _, v in entitylib.EntityThreads do
		task.cancel(v)
	end
	table.clear(entitylib.PlayerConnections)
	table.clear(entitylib.EntityThreads)
	table.clear(entitylib.Connections)
	table.clear(cloned)
	entitylib.Running = false
end

entitylib.kill = function()
	if entitylib.Running then
		entitylib.stop()
	end
	for _, v in entitylib.Events do
		v:Destroy()
	end
	entitylib.IgnoreObject:Destroy()
	loopClean(entitylib)
end

entitylib.refresh = function()
	local cloned = table.clone(entitylib.List)
	for _, v in cloned do
		entitylib.refreshEntity(v.Character, v.Player)
	end
	table.clear(cloned)
end

entitylib.start()

return entitylib
end)()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	tagcallback = {},
	data = {WhitelistedUsers = {}},

	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		return 0, true
	end

	function whitelist:isingame()
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = table.clone(self.customtags[plr.Name] or {}), ''
		for _, v in self.tagcallback do
			v(plr, plrtag, rich)
		end

		if not text then
			return plrtag
		end

		for _, v in plrtag do
			newtag = newtag..(rich and v.color and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end

		return newtag
	end

	function whitelist:process(msg, plr)
		return false
	end

	whitelist.commands = {}

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)

entitylib.start()
local AntiFall
local Method
local Mode
local Material
local Color
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local part

AntiFall = vape.Categories.Blatant:CreateModule({
	Name = 'AntiFall',
	Function = function(callback)
		if callback then
			if Method.Value == 'Part' then
				local debounce = tick()
				part = Instance.new('Part')
				part.Size = Vector3.new(10000, 1, 10000)
				part.Transparency = 1 - Color.Opacity
				part.Material = Enum.Material[Material.Value]
				part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				part.CanCollide = Mode.Value == 'Collide'
				part.Anchored = true
				part.CanQuery = false
				part.Parent = workspace

				AntiFall:Clean(part)
				AntiFall:Clean(part.Touched:Connect(function(touchedpart)
					if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
						local root = entitylib.character.RootPart
						debounce = tick() + 0.1
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
						elseif Mode.Value == 'Impulse' then
							root:ApplyImpulse(Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass)
						end
					end
				end))

				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
						rayCheck.CollisionGroup = root.CollisionGroup
						local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
						if ray then
							part.Position = ray.Position - Vector3.new(0, 15, 0)
						end
					end

					task.wait(0.1)
				until not AntiFall.Enabled
			else
				local lastpos
				AntiFall:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position or lastpos
						if (root.Position.Y + (root.Velocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
							lastpos = lastpos or Vector3.new(root.Position.X, (workspace.FallenPartsDestroyHeight + 20), root.Position.Z)
							root.CFrame += (lastpos - root.Position)
							root.Velocity *= Vector3.new(1, 0, 1)
						end
					end
				end))
			end
		end
	end,
	Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
})
Method = AntiFall:CreateDropdown({
	Name = 'Method',
	List = {'Part', 'Classic'},
	Function = function(val)
		if Mode.Object then
			Mode.Object.Visible = val == 'Part'
			Material.Object.Visible = val == 'Part'
			Color.Object.Visible = val == 'Part'
		end
		if AntiFall.Enabled then
			AntiFall:Toggle()
			AntiFall:Toggle()
		end
	end,
	Tooltip = 'Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane'
})
Mode = AntiFall:CreateDropdown({
	Name = 'Move Mode',
	List = {'Impulse', 'Velocity', 'Collide'},
	Darker = true,
	Function = function(val)
		if part then
			part.CanCollide = val == 'Collide'
		end
	end,
	Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
})
local materials = {'ForceField'}
for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'ForceField' then
		table.insert(materials, v.Name)
	end
end
Material = AntiFall:CreateDropdown({
	Name = 'Material',
	List = materials,
	Darker = true,
	Function = function(val)
		if part then
			part.Material = Enum.Material[val]
		end
	end
})
Color = AntiFall:CreateColorSlider({
	Name = 'Color',
	DefaultOpacity = 0.5,
	Darker = true,
	Function = function(h, s, v, o)
		if part then
			part.Color = Color3.fromHSV(h, s, v)
			part.Transparency = 1 - o
		end
	end
})
local Desync
local hook

Desync = vape.Categories.Blatant:CreateModule({
	Name = 'Desync',
	Function = function(callback)
		if callback then
			if not rakNetCheck('Desync') then
				Desync:Toggle()
				return
			end

			hook = function(packet)
				if packet.AsArray[1] == 0x1b then
					local data = packet.AsBuffer
					buffer.writeu32(data, 1, 0xFFFFFFFF)
					packet:SetData(data)
				end
			end

			raknet.add_send_hook(hook)
		elseif hook then
			raknet.remove_send_hook(hook)
			hook = nil
		end
	end,
	Tooltip = 'Prevent the server from replicating your current position to other players.'
})
local Fly
local LongJump
run(function()
	local Options = {TPTiming = tick()}
	local Mode
	local FloatMode
	local State
	local MoveMethod
	local Keys
	local VerticalValue
	local BounceLength
	local BounceDelay
	local FloatTPGround
	local FloatTPAir
	local CustomProperties
	local WallCheck
	local PlatformStanding
	local Platform, YLevel, OldYLevel
	local w, s, a, d, up, down = 0, 0, 0, 0, 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	Options.rayCheck = rayCheck

	local Functions
	Functions = {
		Velocity = function()
			entitylib.character.RootPart.Velocity = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
		end,
		Impulse = function(options, moveDirection)
			local root = entitylib.character.RootPart
			local diff = (Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0) - root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if diff.Magnitude > 2 then
				root:ApplyImpulse(diff * root.AssemblyMass)
			end
		end,
		CFrame = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if WallCheck.Enabled then
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = root.CollisionGroup
				local ray = workspace:Raycast(root.Position, Vector3.new(0, YLevel - root.Position.Y, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			end
			root.Velocity *= Vector3.new(1, 0, 1)
			root.CFrame += Vector3.new(0, YLevel - root.Position.Y, 0)
		end,
		Bounce = function()
			Functions.Velocity()
			entitylib.character.RootPart.Velocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
		end,
		Floor = function()
			Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
		end,
		TP = function(dt)
			Functions.CFrame(dt)
			if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
				OldYLevel = OldYLevel or YLevel
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
				local ray = workspace:Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -1000, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			else
				if OldYLevel then
					YLevel = OldYLevel
					OldYLevel = nil
				end
			end
		end,
		Jump = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if root.Position.Y < YLevel then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	}

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if Platform then
				Platform.Parent = callback and gameCamera or nil
			end

			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.RotVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end

						if State.Value ~= 'None' then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end

						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection, dt)
						Functions[FloatMode.Value](dt)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							local divided = Keys.Value:split('/')
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[1]] then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[2]] then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end

				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive then
					if PlatformStanding.Enabled then
						entitylib.character.Humanoid.PlatformStand = false
					end

					if Options.WalkSpeed then
						entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
					end
				end

				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Mode = Fly:CreateDropdown({
		Name = 'Speed Mode',
		List = SpeedMethodList,
		Function = function(val)
			WallCheck.Object.Visible = FloatMode.Value == 'CFrame' or FloatMode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	FloatMode = Fly:CreateDropdown({
		Name = 'Float Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Bounce', 'Floor', 'Jump', 'TP'},
		Function = function(val)
			WallCheck.Object.Visible = Mode.Value == 'CFrame' or Mode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			BounceLength.Object.Visible = val == 'Bounce'
			BounceDelay.Object.Visible = val == 'Bounce'
			VerticalValue.Object.Visible = val ~= 'Floor'
			FloatTPGround.Object.Visible = val == 'TP'
			FloatTPAir.Object.Visible = val == 'TP'

			if Platform then
				Platform:Destroy()
				Platform = nil
			end

			if val == 'Floor' then
				Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = Fly.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Teleports you to the ground within intervals\nFloor - Spawns a part under you\nJump - Presses space after going below a certain Y Level\nBounce - Vertical bouncing motion'
	})
	local states = {'None'}
	for _, v in Enum.HumanoidStateType:GetEnumItems() do
		if v.Name ~= 'Dead' and v.Name ~= 'None' then
			table.insert(states, v.Name)
		end
	end
	State = Fly:CreateDropdown({
		Name = 'Humanoid State',
		List = states
	})
	MoveMethod = Fly:CreateDropdown({
		Name = 'Move Mode',
		List = {'MoveDirection', 'Direct'},
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q', 'ButtonA/ButtonL2'},
		Tooltip = 'The key combination for going up & down'
	})
	Options.Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Options.TPFrequency = Fly:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseLength = Fly:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseDelay = Fly:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	BounceLength = Fly:CreateSlider({
		Name = 'Bounce Length',
		Min = 0,
		Max = 30,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BounceDelay = Fly:CreateSlider({
		Name = 'Bounce Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPGround = Fly:CreateSlider({
		Name = 'Ground',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.1,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPAir = Fly:CreateSlider({
		Name = 'Air',
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false
	})
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:CreateToggle({
		Name = 'PlatformStand',
		Function = function(callback)
			if Fly.Enabled then
				entitylib.character.Humanoid.PlatformStand = callback
			end
		end,
		Tooltip = 'Forces the character to look infront of the camera'
	})
	CustomProperties = Fly:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)
local HighJump
local Mode
local Value
local AutoDisable

local function jump()
	local state = entitylib.isAlive and entitylib.character.Humanoid:GetState() or nil

	if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
		local root = entitylib.character.RootPart

		if Mode.Value == 'Velocity' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
		elseif Mode.Value == 'Impulse' then
			entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.delay(0, function()
				root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
			end)
		else
			local yLevel = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)

			repeat
				root.CFrame += Vector3.new(0, yLevel * 0.016, 0)
				yLevel = yLevel - (workspace.Gravity * 0.016)

				if Mode.Value == 'CFrame' then
					task.wait()
				end
			until yLevel <= 0
		end
	end
end

HighJump = vape.Categories.Blatant:CreateModule({
	Name = 'HighJump',
	Function = function(callback)
		if callback then
			if AutoDisable.Enabled then
				jump()
				HighJump:Toggle()
			else
				HighJump:Clean(runService.RenderStepped:Connect(function()
					if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
						jump()
					end
				end))
			end
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Lets you jump higher'
})
Mode = HighJump:CreateDropdown({
	Name = 'Mode',
	List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
	Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
})
Value = HighJump:CreateSlider({
	Name = 'Velocity',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoDisable = HighJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true
})
local HitBoxes
local Targets
local TargetPart
local Expand
local modified = {}

HitBoxes = vape.Categories.Blatant:CreateModule({
	Name = 'HitBoxes',
	Function = function(callback)
		if callback then
			repeat
				for _, v in entitylib.List do
					if v.Targetable then
						if not Targets.Players.Enabled and v.Player then continue end
						if not Targets.NPCs.Enabled and v.NPC then continue end
						local part = v[TargetPart.Value]
						if not modified[part] then
							modified[part] = part.Size
						end
						part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
					end
				end

				task.wait()
			until not HitBoxes.Enabled
		else
			for i, v in modified do
				i.Size = v
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Expands entities hitboxes'
})
Targets = HitBoxes:CreateTargets({Players = true})
TargetPart = HitBoxes:CreateDropdown({
	Name = 'Part',
	List = {'RootPart', 'Head'}
})
Expand = HitBoxes:CreateSlider({
	Name = 'Expand amount',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
local Invisible
local oldcf
local animtrack
local proper = true

local function animationTrickery()
	if entitylib.isAlive then
		local isR15 = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15
		local anim = Instance.new('Animation')
		anim.AnimationId = 'rbxassetid://'..(isR15 and '18537363391' or '215384594')
		animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
		animtrack.Priority = Enum.AnimationPriority.Action4
		animtrack:Play(0, 0.001, 0)
		anim:Destroy()

		task.delay(0, function()
			animtrack.TimePosition = isR15 and 0.77 or 0.38
		end)
	end
end

Invisible = vape.Categories.Blatant:CreateModule({
	Name = 'Invisible',
	Function = function(callback)
		if callback then
			animationTrickery()

			oldcf = nil
			local bindKey = httpService:GenerateGUID(true)
			runService:BindToRenderStep(bindKey, 0, function()
				if entitylib.isAlive and oldcf then
					entitylib.character.RootPart.CFrame = oldcf
					animtrack:AdjustWeight(0.001)
				end
			end)

			Invisible:Clean(function()
				runService:UnbindFromRenderStep(bindKey)
			end)

			Invisible:Clean(runService.Heartbeat:Connect(function(dt)
				if entitylib.isAlive then
					local isR15 = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15
					local root = entitylib.character.RootPart
					local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
					oldcf = root.CFrame

					root.CFrame = cf * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
					animtrack:AdjustWeight(100)
				end
			end))

			Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				local animator = char.Humanoid:WaitForChild('Animator', 1)
				if animator and Invisible.Enabled then
					oldroot = nil
					Invisible:Toggle()
					Invisible:Toggle()
				end
			end))
		else
			if animtrack then
				animtrack:Stop()
				animtrack:Destroy()
			end

			if entitylib.isAlive and oldcf then
				entitylib.character.RootPart.CFrame = oldcf
			end
		end
	end,
	Tooltip = 'Turns you invisible.'
})
local Jesus
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

Jesus = vape.Categories.Blatant:CreateModule({
	Name = 'Jesus',
	Function = function(callback)
		if callback then
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			params.FilterDescendantsInstances = {terrain}
			local Platform = Instance.new('Part')
			Platform.CanQuery = false
			Platform.Anchored = true
			Platform.Size = Vector3.one
			Platform.Transparency = 1
			Platform.Parent = gameCamera

			Jesus:Clean(Platform)
			Jesus:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local ray = workspace:Raycast(root.Position, Vector3.new(0, -((root.Size.Y / 2) + entitylib.character.HipHeight + math.abs(root.AssemblyLinearVelocity.Y * 0.032)), 0), params)

					if ray and ray.Material == Enum.Material.Water then
						Platform.CFrame = CFrame.new(ray.Position)
					else
						Platform.CFrame = CFrame.new(10000, 10000, 10000)
					end
				end
			end))
		end
	end,
	Tooltip = 'Allow you to stand on terrain water'
})
local Killaura
local Targets
local CPS
local SwingRange
local AttackRange
local AngleSlider
local Max
local Mouse
local Lunge
local BoxSwingColor
local BoxAttackColor
local ParticleTexture
local ParticleColor1
local ParticleColor2
local ParticleSize
local Face
local Overlay = OverlapParams.new()
Overlay.FilterType = Enum.RaycastFilterType.Include
local Particles, Boxes, AttackDelay = {}, {}, tick()

local function getAttackData()
	if Mouse.Enabled then
		if not inputService:IsMouseButtonPressed(0) then return false end
	end

	local tool = getTool()
	return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
end

Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		if callback then
			repeat
				local interest, tool = getAttackData()
				local attacked = {}
				if interest then
					local plrs = entitylib.AllPosition({
						Range = SwingRange.Value,
						Wallcheck = Targets.Walls.Enabled or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = Max.Value
					})

					if #plrs > 0 then
						local selfpos = entitylib.character.RootPart.Position
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

						for _, v in plrs do
							local delta = (v.RootPart.Position - selfpos)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle > (math.rad(AngleSlider.Value) / 2) then continue end

							table.insert(attacked, {
								Entity = v,
								Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
							})
							targetinfo.Targets[v] = tick() + 1

							if AttackDelay < tick() then
								AttackDelay = tick() + (1 / CPS.GetRandomValue())
								tool:Activate()
							end

							if Lunge.Enabled and tool.GripUp.X == 0 then break end
							if delta.Magnitude > AttackRange.Value then continue end

							Overlay.FilterDescendantsInstances = {v.Character}
							for _, part in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
								firetouchinterest(interest.Parent, part, 1)
								firetouchinterest(interest.Parent, part, 0)
							end
						end
					end
				end

				for i, v in Boxes do
					v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
					if v.Adornee then
						v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
						v.Transparency = 1 - attacked[i].Check.Opacity
					end
				end

				for i, v in Particles do
					v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
					v.Parent = attacked[i] and gameCamera or nil
				end

				if Face.Enabled and attacked[1] then
					local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
					entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
				end

				task.wait()
			until not Killaura.Enabled
		else
			for _, v in Boxes do
				v.Adornee = nil
			end

			for _, v in Particles do
				v.Parent = nil
			end
		end
	end,
	Tooltip = 'Attack players around you\nwithout aiming at them.'
})
Targets = Killaura:CreateTargets({Players = true})
CPS = Killaura:CreateTwoSlider({
	Name = 'Attacks per Second',
	Min = 1,
	Max = 20,
	DefaultMin = 12,
	DefaultMax = 12
})
SwingRange = Killaura:CreateSlider({
	Name = 'Swing range',
	Min = 1,
	Max = 30,
	Default = 13,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AttackRange = Killaura:CreateSlider({
	Name = 'Attack range',
	Min = 1,
	Max = 30,
	Default = 13,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = Killaura:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 90
})
Max = Killaura:CreateSlider({
	Name = 'Max targets',
	Min = 1,
	Max = 10,
	Default = 10
})
Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
Lunge = Killaura:CreateToggle({Name = 'Sword lunge only'})
Killaura:CreateToggle({
	Name = 'Show target',
	Function = function(callback)
		BoxSwingColor.Object.Visible = callback
		BoxAttackColor.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.new(3, 5, 3)
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
				Boxes[i] = box
			end
		else
			for _, v in Boxes do
				v:Destroy()
			end
			table.clear(Boxes)
		end
	end
})
BoxSwingColor = Killaura:CreateColorSlider({
	Name = 'Target Color',
	Darker = true,
	DefaultHue = 0.6,
	DefaultOpacity = 0.5,
	Visible = false
})
BoxAttackColor = Killaura:CreateColorSlider({
	Name = 'Attack Color',
	Darker = true,
	DefaultOpacity = 0.5,
	Visible = false
})
Killaura:CreateToggle({
	Name = 'Target particles',
	Function = function(callback)
		ParticleTexture.Object.Visible = callback
		ParticleColor1.Object.Visible = callback
		ParticleColor2.Object.Visible = callback
		ParticleSize.Object.Visible = callback
		if callback then
			for i = 1, 10 do
				local part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 2)
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
				part.CanQuery = false
				part.Parent = Killaura.Enabled and gameCamera or nil
				local particles = Instance.new('ParticleEmitter')
				particles.Brightness = 1.5
				particles.Size = NumberSequence.new(ParticleSize.Value)
				particles.Shape = Enum.ParticleEmitterShape.Sphere
				particles.Texture = ParticleTexture.Value
				particles.Transparency = NumberSequence.new(0)
				particles.Lifetime = NumberRange.new(0.4)
				particles.Speed = NumberRange.new(16)
				particles.Rate = 128
				particles.Drag = 16
				particles.ShapePartial = 1
				particles.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
				particles.Parent = part
				Particles[i] = part
			end
		else
			for _, v in Particles do
				v:Destroy()
			end
			table.clear(Particles)
		end
	end
})
ParticleTexture = Killaura:CreateTextBox({
	Name = 'Texture',
	Default = 'rbxassetid://14736249347',
	Function = function()
		for _, v in Particles do
			v.ParticleEmitter.Texture = ParticleTexture.Value
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor1 = Killaura:CreateColorSlider({
	Name = 'Color Begin',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
			})
		end
	end,
	Darker = true,
	Visible = false
})
ParticleColor2 = Killaura:CreateColorSlider({
	Name = 'Color End',
	Function = function(hue, sat, val)
		for _, v in Particles do
			v.ParticleEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
			})
		end
	end,
	Darker = true,
	Visible = false
})
ParticleSize = Killaura:CreateSlider({
	Name = 'Size',
	Min = 0,
	Max = 1,
	Default = 0.2,
	Decimal = 100,
	Function = function(val)
		for _, v in Particles do
			v.ParticleEmitter.Size = NumberSequence.new(val)
		end
	end,
	Darker = true,
	Visible = false
})
Face = Killaura:CreateToggle({Name = 'Face target'})
local Mode
local Value
local AutoDisable

LongJump = vape.Categories.Blatant:CreateModule({
	Name = 'LongJump',
	Function = function(callback)
		if callback then
			local exempt = tick() + 0.1
			LongJump:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
						if exempt < tick() and AutoDisable.Enabled then
							if LongJump.Enabled then
								LongJump:Toggle()
							end
						else
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end

					local root = entitylib.character.RootPart
					local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
					if Mode.Value == 'Velocity' then
						root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					elseif Mode.Value == 'Impulse' then
						local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
						if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
							root:ApplyImpulse(diff * root.AssemblyMass)
						end
					else
						root.CFrame += dir * dt
					end
				end
			end))
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Lets you jump farther'
})
Mode = LongJump:CreateDropdown({
	Name = 'Mode',
	List = {'Velocity', 'Impulse', 'CFrame'},
	Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root'
})
Value = LongJump:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoDisable = LongJump:CreateToggle({
	Name = 'Auto Disable',
	Default = true
})
local MouseTP
local Mode
local MovementMode
local Length
local Delay
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true

local function getWaypointInMouse()
	local obj, dist, location = nil, math.huge, inputService:GetMouseLocation()

	for _, v in WaypointFolder:GetChildren() do
		local position, vis = gameCamera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
		if not vis then continue end

		local mag = (location - Vector2.new(position.x, position.y)).Magnitude
		if mag < dist then
			obj, dist = v, mag
		end
	end

	return obj
end

MouseTP = vape.Categories.Blatant:CreateModule({
	Name = 'MouseTP',
	Function = function(callback)
		if callback then
			local position
			if Mode.Value == 'Mouse' then
				local ray = cloneref(lplr:GetMouse()).UnitRay
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
				position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
			elseif Mode.Value == 'Waypoint' then
				local waypoint = getWaypointInMouse()
				position = waypoint and waypoint.StudsOffsetWorldSpace
			else
				local ent = entitylib.EntityMouse({
					Range = math.huge,
					Part = 'RootPart',
					Players = true
				})
				position = ent and ent.RootPart.Position
			end

			if not position then
				notif('MouseTP', 'No position found.', 5)
				MouseTP:Toggle()
				return
			end

			if MovementMode.Value ~= 'Lerp' then
				MouseTP:Toggle()
				if entitylib.isAlive then
					if MovementMode.Value == 'Motor' then
						motorMove(entitylib.character.RootPart, CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
					else
						entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
					end
				end
			else
				MouseTP:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						entitylib.character.RootPart.Velocity = Vector3.zero
					end
				end))

				repeat
					if entitylib.isAlive then
						local direction = CFrame.lookAt(entitylib.character.RootPart.Position, position).LookVector * math.min((entitylib.character.RootPart.Position - position).Magnitude, Length.Value)
						entitylib.character.RootPart.CFrame += direction
						if (entitylib.character.RootPart.Position - position).Magnitude < 3 and MouseTP.Enabled then
							MouseTP:Toggle()
						end
					elseif MouseTP.Enabled then
						MouseTP:Toggle()
						notif('MouseTP', 'Character missing', 5, 'warning')
					end

					task.wait(Delay.Value)
				until not MouseTP.Enabled
			end
		end
	end,
	Tooltip = 'Teleports to a selected position.'
})
Mode = MouseTP:CreateDropdown({
	Name = 'Mode',
	List = {'Mouse', 'Player', 'Waypoint'}
})
MovementMode = MouseTP:CreateDropdown({
	Name = 'Movement',
	List = {'CFrame', 'Motor', 'Lerp'},
	Function = function(val)
		Length.Object.Visible = val == 'Lerp'
		Delay.Object.Visible = val == 'Lerp'
	end
})
Length = MouseTP:CreateSlider({
	Name = 'Length',
	Min = 0,
	Max = 150,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
Delay = MouseTP:CreateSlider({
	Name = 'Delay',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
local Mode
local StudLimit = {Object = {}}
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local overlapCheck = OverlapParams.new()
overlapCheck.MaxParts = 9e9
local modified, fflag = {}
local teleported

local function grabClosestNormal(ray)
	local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top

	for _, normal in Enum.NormalId:GetEnumItems() do
		local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
		if dot > mag then
			mag, closest = dot, normal
		end
	end

	return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
end

local Functions = {
	Part = function()
		local chars = {gameCamera, lplr.Character}
		for _, v in entitylib.List do
			table.insert(chars, v.Character)
		end
		overlapCheck.FilterDescendantsInstances = chars

		local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(7, entitylib.character.HipHeight, 7), overlapCheck)
		for _, part in parts do
			if part.CanCollide and (not Spider.Enabled or SpiderShift) then
				modified[part] = true
				part.CanCollide = false
			end
		end

		for part in modified do
			if not table.find(parts, part) then
				modified[part] = nil
				part.CanCollide = true
			end
		end
	end,
	Character = function()
		for _, part in lplr.Character:GetDescendants() do
			if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
				modified[part] = true
				part.CanCollide = Spider.Enabled and not SpiderShift
			end
		end
	end,
	CFrame = function()
		local chars = {gameCamera, lplr.Character}
		for _, v in entitylib.List do
			table.insert(chars, v.Character)
		end
		rayCheck.FilterDescendantsInstances = chars
		overlapCheck.FilterDescendantsInstances = chars

		local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
		if ray and (not Spider.Enabled or SpiderShift) then
			local phaseDirection = grabClosestNormal(ray)
			if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
				local root = entitylib.character.RootPart
				local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))

				if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
					if Mode.Value == 'Motor' then
						motorMove(root, dest)
					else
						root.CFrame = dest
					end
				end
			end
		end
	end,
	FFlag = function()
		if teleported then return end
		setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
		fflag = true
	end
}
Functions.Motor = Functions.CFrame

Phase = vape.Categories.Blatant:CreateModule({
	Name = 'Phase',
	Function = function(callback)
		if callback then
			Phase:Clean(runService.Stepped:Connect(function()
				if entitylib.isAlive then
					Functions[Mode.Value]()
				end
			end))

			if Mode.Value == 'FFlag' then
				Phase:Clean(lplr.OnTeleport:Connect(function()
					teleported = true
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end))
			end
		else
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for part in modified do
				part.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end
	end,
	Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
})
Mode = Phase:CreateDropdown({
	Name = 'Mode',
	List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
	Function = function(val)
		StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
		if fflag then
			setfflag('AssemblyExtentsExpansionStudHundredth', '30')
		end
		for part in modified do
			part.CanCollide = true
		end
		table.clear(modified)
		fflag = nil
	end,
	Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
})
StudLimit = Phase:CreateSlider({
	Name = 'Wall Size',
	Min = 1,
	Max = 20,
	Default = 5,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Darker = true,
	Visible = false
})
local Speed
local Mode
local Options
local AutoJump
local AutoJumpCustom
local AutoJumpValue
local w, s, a, d = 0, 0, 0, 0

Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		frictionTable.Speed = callback and CustomProperties.Enabled or nil
		updateVelocity()
		if callback then
			Speed:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive and not Fly.Enabled and not LongJump.Enabled then
					local state = entitylib.character.Humanoid:GetState()
					if state == Enum.HumanoidStateType.Climbing then return end

					local movevec = TargetStrafeVector or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection
					SpeedMethods[Mode.Value](Options, movevec, dt)
					if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
						if AutoJumpCustom.Enabled then
							local velocity = entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)
							entitylib.character.RootPart.Velocity = Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
						else
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end
			end))

			w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
			for _, v in {'InputBegan', 'InputEnded'} do
				Speed:Clean(inputService[v]:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.W then
							w = v == 'InputBegan' and -1 or 0
						elseif input.KeyCode == Enum.KeyCode.S then
							s = v == 'InputBegan' and 1 or 0
						elseif input.KeyCode == Enum.KeyCode.A then
							a = v == 'InputBegan' and -1 or 0
						elseif input.KeyCode == Enum.KeyCode.D then
							d = v == 'InputBegan' and 1 or 0
						end
					end
				end))
			end
		else
			if Options.WalkSpeed and entitylib.isAlive then
				entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
			end
			Options.WalkSpeed = nil
		end
	end,
	ExtraText = function()
		return Mode.Value
	end,
	Tooltip = 'Increases your movement with various methods.'
})
Mode = Speed:CreateDropdown({
	Name = 'Mode',
	List = SpeedMethodList,
	Function = function(val)
		Options.WallCheck.Object.Visible = val == 'CFrame' or val == 'TP'
		Options.TPFrequency.Object.Visible = val == 'TP'
		Options.PulseLength.Object.Visible = val == 'Pulse'
		Options.PulseDelay.Object.Visible = val == 'Pulse'
		if Speed.Enabled then
			Speed:Toggle()
			Speed:Toggle()
		end
	end,
	Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
})
Options = {
	MoveMethod = Speed:CreateDropdown({
		Name = 'Move Mode',
		List = {'MoveDirection', 'Direct'},
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
	}),
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	}),
	TPFrequency = Speed:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	}),
	PulseLength = Speed:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	}),
	PulseDelay = Speed:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	}),
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false
	}),
	TPTiming = tick(),
	rayCheck = RaycastParams.new()
}
Options.rayCheck.RespectCanCollide = true
CustomProperties = Speed:CreateToggle({
	Name = 'Custom Properties',
	Function = function()
		if Speed.Enabled then
			Speed:Toggle()
			Speed:Toggle()
		end
	end,
	Default = true
})
AutoJump = Speed:CreateToggle({
	Name = 'AutoJump',
	Function = function(callback)
		AutoJumpCustom.Object.Visible = callback
	end
})
AutoJumpCustom = Speed:CreateToggle({
	Name = 'Custom Jump',
	Function = function(callback)
		AutoJumpValue.Object.Visible = callback
	end,
	Tooltip = 'Allows you to adjust the jump power',
	Darker = true,
	Visible = false
})
AutoJumpValue = Speed:CreateSlider({
	Name = 'Jump Power',
	Min = 1,
	Max = 50,
	Default = 30,
	Darker = true,
	Visible = false
})
local Mode
local Value
local State
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local Active, Truss

Spider = vape.Categories.Blatant:CreateModule({
	Name = 'Spider',
	Function = function(callback)
		if callback then
			if Truss then
				Truss.Parent = gameCamera
			end

			Spider:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local chars = {gameCamera, lplr.Character, Truss}
					for _, v in entitylib.List do
						table.insert(chars, v.Character)
					end

					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
					rayCheck.FilterDescendantsInstances = chars
					rayCheck.CollisionGroup = root.CollisionGroup

					if Mode.Value ~= 'Part' then
						local vec = entitylib.character.Humanoid.MoveDirection * 2.5
						local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
						if Active and not ray then
							root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
						end

						Active = ray
						if Active and ray.Normal.Y == 0 then
							if not Phase.Enabled or not SpiderShift then
								if State.Enabled then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
								end

								root.Velocity *= Vector3.new(1, 0, 1)
								if Mode.Value == 'CFrame' then
									root.CFrame += Vector3.new(0, Value.Value * dt, 0)
								elseif Mode.Value == 'Impulse' then
									root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
								else
									root.Velocity += Vector3.new(0, Value.Value, 0)
								end
							end
						end
					else
						local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
						if ray and (not Phase.Enabled or not SpiderShift) then
							Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
						else
							Truss.Position = Vector3.zero
						end
					end
				end
			end))
		else
			if Truss then
				Truss.Parent = nil
			end
			SpiderShift = false
		end
	end,
	Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
})
Mode = Spider:CreateDropdown({
	Name = 'Mode',
	List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
	Function = function(val)
		Value.Object.Visible = val ~= 'Part'
		State.Object.Visible = val ~= 'Part'
		if Truss then
			Truss:Destroy()
			Truss = nil
		end
		if val == 'Part' then
			Truss = Instance.new('TrussPart')
			Truss.Size = Vector3.new(2, 2, 2)
			Truss.Transparency = 1
			Truss.Anchored = true
			Truss.Parent = Spider.Enabled and gameCamera or nil
		end
	end,
	Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
})
Value = Spider:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 100,
	Default = 30,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
State = Spider:CreateToggle({
	Name = 'Climb State',
	Darker = true
})
local SpinBot
local Mode
local XToggle
local YToggle
local ZToggle
local Value
local AngularVelocity

SpinBot = vape.Categories.Blatant:CreateModule({
	Name = 'SpinBot',
	Function = function(callback)
		if callback then
			SpinBot:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive then
					if Mode.Value == 'RotVelocity' then
						local originalRotVelocity = entitylib.character.RootPart.RotVelocity
						entitylib.character.Humanoid.AutoRotate = false
						entitylib.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or originalRotVelocity.X, YToggle.Enabled and Value.Value or originalRotVelocity.Y, ZToggle.Enabled and Value.Value or originalRotVelocity.Z)
					elseif Mode.Value == 'CFrame' then
						local val = math.rad((tick() * (20 * Value.Value)) % 360)
						local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
						entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and val or x, YToggle.Enabled and val or y, ZToggle.Enabled and val or z)
					elseif AngularVelocity then
						AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
						AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
						AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
					end
				end
			end))
		else
			if entitylib.isAlive and Mode.Value == 'RotVelocity' then
				entitylib.character.Humanoid.AutoRotate = true
			end

			if AngularVelocity then
				AngularVelocity.Parent = nil
			end
		end
	end,
	Tooltip = 'Makes your character spin around in circles (does not work in first person)'
})
Mode = SpinBot:CreateDropdown({
	Name = 'Mode',
	List = {'CFrame', 'RotVelocity', 'BodyMover'},
	Function = function(val)
		if AngularVelocity then
			AngularVelocity:Destroy()
			AngularVelocity = nil
		end
		AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
	end
})
Value = SpinBot:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 100,
	Default = 40
})
XToggle = SpinBot:CreateToggle({Name = 'Spin X'})
YToggle = SpinBot:CreateToggle({
	Name = 'Spin Y',
	Default = true
})
ZToggle = SpinBot:CreateToggle({Name = 'Spin Z'})
local Swim
local terrain = cloneref(workspace:FindFirstChildWhichIsA('Terrain'))
local lastpos = Region3.new(Vector3.zero, Vector3.zero)

Swim = vape.Categories.Blatant:CreateModule({
	Name = 'Swim',
	Function = function(callback)
		if callback then
			Swim:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local moving = entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
					local rootvelo = root.Velocity
					local space = inputService:IsKeyDown(Enum.KeyCode.Space)

					if terrain then
						local factor = (moving or space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
						local pos = root.Position - Vector3.new(0, 1, 0)
						local newpos = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
						terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
						terrain:FillRegion(newpos, 4, Enum.Material.Water)
						lastpos = newpos
					end
				end
			end))
		else
			if terrain and lastpos then
				terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
			end
		end
	end,
	Tooltip = 'Lets you swim midair'
})
local TargetStrafe
local Targets
local SearchRange
local StrafeRange
local YFactor
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local module, old

TargetStrafe = vape.Categories.Blatant:CreateModule({
	Name = 'TargetStrafe',
	Function = function(callback)
		if callback then
			if not module then
				local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
				if not suc then
					module = {}
				end
			end

			old = module.moveFunction
			local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
			module.moveFunction = function(self, vec, face)
				local wallcheck = Targets.Walls.Enabled
				local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
					Range = SearchRange.Value,
					Wallcheck = wallcheck,
					Part = 'RootPart',
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled
				})

				if ent then
					local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
					rayCheck.CollisionGroup = root.CollisionGroup

					if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
						local factor, localPosition = 0, root.Position
						if ent ~= oldent then
							ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
						end

						local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
						local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
						local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
						local startRay, endRay = entityPos, newPos

						if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
							startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
						end

						local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
						if (localPosition - newPos).Magnitude < 3 or ray then
							factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
							if ray then
								newPos = ray.Position + (ray.Normal * 1.5)
								factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
							end
						end

						if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
							newPos = entityPos
							factor = 40
						end

						ang += factor % 360
						vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
						vec = vec == vec and vec or Vector3.zero
						TargetStrafeVector = vec
					else
						ent = nil
					end
				end

				TargetStrafeVector = ent and vec or nil
				oldent = ent

				return old(self, vec, face)
			end
		else
			if module and old then
				module.moveFunction = old
			end
			TargetStrafeVector = nil
		end
	end,
	Tooltip = 'Automatically strafes around the opponent'
})
Targets = TargetStrafe:CreateTargets({
	Players = true,
	Walls = true
})
SearchRange = TargetStrafe:CreateSlider({
	Name = 'Search Range',
	Min = 1,
	Max = 30,
	Default = 24,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
StrafeRange = TargetStrafe:CreateSlider({
	Name = 'Strafe Range',
	Min = 1,
	Max = 30,
	Default = 18,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
YFactor = TargetStrafe:CreateSlider({
	Name = 'Y Factor',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
local Timer
local Value

Timer = vape.Categories.Blatant:CreateModule({
	Name = 'Timer',
	Function = function(callback)
		if callback then
			setfflag('SimEnableStepPhysics', 'True')
			setfflag('SimEnableStepPhysicsSelective', 'True')

			Timer:Clean(runService.RenderStepped:Connect(function(dt)
				if Value.Value > 1 then
					runService:Pause()
					workspace:StepPhysics(dt * (Value.Value - 1), {entitylib.character.RootPart})
					runService:Run()
				end
			end))
		end
	end,
	Tooltip = 'Change the game speed.'
})
Value = Timer:CreateSlider({
	Name = 'Value',
	Min = 1,
	Max = 3,
	Decimal = 10
})
local AimAssist
local Targets
local Part
local FOV
local Speed
local CircleColor
local CircleTransparency
local CircleFilled
local CircleObject
local RightClick
local ShowTarget
local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)

local function wrapAngle(num)
	num = num % math.pi
	num -= num >= (math.pi / 2) and math.pi or 0
	num += num < -(math.pi / 2) and math.pi or 0
	return num
end

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback
		end

		if callback then
			local ent
			local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
			AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
				if CircleObject then
					CircleObject.Position = inputService:GetMouseLocation()
				end

				if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
					ent = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = Part.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = gameCamera.CFrame.Position
					})

					if ent then
						local facing = gameCamera.CFrame.LookVector
						local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
						new = new == new and new or Vector3.zero

						if ShowTarget.Enabled then
							targetinfo.Targets[ent] = tick() + 1
						end

						if new ~= Vector3.zero then
							local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
							local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
							local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)

							angle *= math.min(Speed.Value * dt, 1)
							mousemoverel(angle.X, angle.Y)
						end
					end
				end
			end))

			if RightClick.Enabled then
				AimAssist:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						ent = nil
						rightClicked = true
					end
				end))

				AimAssist:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						rightClicked = false
					end
				end))
			end
		end
	end,
	Tooltip = 'Smoothly aims to closest valid target'
})
Targets = AimAssist:CreateTargets({Players = true})
Part = AimAssist:CreateDropdown({
	Name = 'Part',
	List = {'RootPart', 'Head'}
})
FOV = AimAssist:CreateSlider({
	Name = 'FOV',
	Min = 0,
	Max = 1000,
	Default = 100,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end
})
Speed = AimAssist:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 30,
	Default = 15
})
AimAssist:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = FOV.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = AimAssist.Enabled
		else
			pcall(function()
				CircleObject.Visible = false
				CircleObject:Remove()
			end)
		end
		CircleColor.Object.Visible = callback
		CircleTransparency.Object.Visible = callback
		CircleFilled.Object.Visible = callback
	end
})
CircleColor = AimAssist:CreateColorSlider({
	Name = 'Circle Color',
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Darker = true,
	Visible = false
})
CircleTransparency = AimAssist:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Default = 0.5,
	Function = function(val)
		if CircleObject then
			CircleObject.Transparency = 1 - val
		end
	end,
	Darker = true,
	Visible = false
})
CircleFilled = AimAssist:CreateToggle({
	Name = 'Circle Filled',
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end,
	Darker = true,
	Visible = false
})
RightClick = AimAssist:CreateToggle({
	Name = 'Require right click',
	Function = function()
		if AimAssist.Enabled then
			AimAssist:Toggle()
			AimAssist:Toggle()
		end
	end
})
ShowTarget = AimAssist:CreateToggle({
	Name = 'Show target info'
})
local AutoClicker
local Mode
local CPS

AutoClicker = vape.Categories.Combat:CreateModule({
	Name = 'AutoClicker',
	Function = function(callback)
		if callback then
			repeat
				if Mode.Value == 'Tool' then
					local tool = getTool()
					if tool and inputService:IsMouseButtonPressed(0) then
						tool:Activate()
					end
				else
					if mouse1click and (isrbxactive or iswindowactive)() then
						if not vape.gui.ScaledGui.ClickGui.Visible then
							(Mode.Value == 'Click' and mouse1click or mouse2click)()
						end
					end
				end

				task.wait(1 / CPS.GetRandomValue())
			until not AutoClicker.Enabled
		end
	end,
	Tooltip = 'Automatically clicks for you'
})
Mode = AutoClicker:CreateDropdown({
	Name = 'Mode',
	List = {'Tool', 'Click', 'RightClick'},
	Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
})
CPS = AutoClicker:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 20,
	DefaultMin = 8,
	DefaultMax = 12
})
local Reach
local Targets
local Mode
local Value
local Chance
local Overlay = OverlapParams.new()
Overlay.FilterType = Enum.RaycastFilterType.Include
local modified = {}

Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if callback then
			repeat
				local tool = getTool()
				tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
				if tool then
					if Mode.Value == 'TouchInterest' then
						local entites = {}
						for _, v in entitylib.List do
							if v.Targetable then
								if not Targets.Players.Enabled and v.Player then continue end
								if not Targets.NPCs.Enabled and v.NPC then continue end
								table.insert(entites, v.Character)
							end
						end

						Overlay.FilterDescendantsInstances = entites
						local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)

						for _, v in parts do
							if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
								task.wait(0.2)
								break
							end

							firetouchinterest(tool.Parent, v, 1)
							firetouchinterest(tool.Parent, v, 0)
						end
					else
						if not modified[tool.Parent] then
							modified[tool.Parent] = tool.Parent.Size
						end

						tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
						tool.Parent.Massless = true
					end
				end

				task.wait()
			until not Reach.Enabled
		else
			for i, v in modified do
				i.Size = v
				i.Massless = false
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Extends tool attack reach'
})
Targets = Reach:CreateTargets({Players = true})
Mode = Reach:CreateDropdown({
	Name = 'Mode',
	List = {'TouchInterest', 'Resize'},
	Function = function(val)
		Chance.Object.Visible = val == 'TouchInterest'
	end,
	Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
})
Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
Chance = Reach:CreateSlider({
	Name = 'Chance',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
local mouseClicked
run(function()
	local SilentAim
	local Target
	local Mode
	local Method
	local MethodRay
	local IgnoredScripts
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local AutoFireShootDelay
	local AutoFireMode
	local AutoFirePosition
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Projectile
	local ProjectileSpeed
	local ProjectileGravity
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()

						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end

					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end

					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)
local TriggerBot
local Targets
local ShootDelay
local Distance
local rayCheck, delayCheck = RaycastParams.new(), tick()

local function getTriggerBotTarget()
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}

	local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
	if ray and ray.Instance then
		for _, v in entitylib.List do
			if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
				if ray.Instance:IsDescendantOf(v.Character) then
					return entitylib.isVulnerable(v) and v
				end
			end
		end
	end
end

TriggerBot = vape.Categories.Combat:CreateModule({
	Name = 'TriggerBot',
	Function = function(callback)
		if callback then
			repeat
				if mouse1click and (isrbxactive or iswindowactive)() then
					if getTriggerBotTarget() and canClick() then
						if delayCheck < tick() then
							if mouseClicked then
								mouse1release()
								delayCheck = tick() + ShootDelay.Value
							else
								mouse1press()
							end
							mouseClicked = not mouseClicked
						end
					else
						if mouseClicked then
							mouse1release()
						end
						mouseClicked = false
					end
				end

				task.wait()
			until not TriggerBot.Enabled
		else
			if mouse1click and (isrbxactive or iswindowactive)() then
				if mouseClicked then
					mouse1release()
				end
			end
			mouseClicked = false
		end
	end,
	Tooltip = 'Shoots people that enter your crosshair'
})
Targets = TriggerBot:CreateTargets({
	Players = true,
	NPCs = true
})
ShootDelay = TriggerBot:CreateSlider({
	Name = 'Next Shot Delay',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
	Tooltip = 'The delay set after shooting a target'
})
Distance = TriggerBot:CreateSlider({
	Name = 'Distance',
	Min = 0,
	Max = 1000,
	Default = 1000,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
local Atmosphere
local Toggles = {}
local newobjects, oldobjects = {}, {}
local apidump = {
	Sky = {
		SkyboxUp = 'Text',
		SkyboxDn = 'Text',
		SkyboxLf = 'Text',
		SkyboxRt = 'Text',
		SkyboxFt = 'Text',
		SkyboxBk = 'Text',
		SunTextureId = 'Text',
		SunAngularSize = 'Number',
		MoonTextureId = 'Text',
		MoonAngularSize = 'Number',
		StarCount = 'Number'
	},
	Atmosphere = {
		Color = 'Color',
		Decay = 'Color',
		Density = 'Number',
		Offset = 'Number',
		Glare = 'Number',
		Haze = 'Number'
	},
	BloomEffect = {
		Intensity = 'Number',
		Size = 'Number',
		Threshold = 'Number'
	},
	DepthOfFieldEffect = {
		FarIntensity = 'Number',
		FocusDistance = 'Number',
		InFocusRadius = 'Number',
		NearIntensity = 'Number'
	},
	SunRaysEffect = {
		Intensity = 'Number',
		Spread = 'Number'
	},
	ColorCorrectionEffect = {
		TintColor = 'Color',
		Saturation = 'Number',
		Contrast = 'Number',
		Brightness = 'Number'
	}
}

local function removeObject(v)
	if not table.find(newobjects, v) then
		local toggle = Toggles[v.ClassName]
		if toggle and toggle.Toggle.Enabled then
			if v.Parent then
				table.insert(oldobjects, v)
				v.Parent = game
			end
		end
	end
end

Atmosphere = vape.Legit:CreateModule({
	Name = 'Atmosphere',
	Function = function(callback)
		if callback then
			for _, v in lightingService:GetChildren() do
				removeObject(v)
			end

			Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
				task.defer(removeObject, v)
			end))

			for i, v in Toggles do
				if v.Toggle.Enabled then
					local obj = Instance.new(i)
					for i2, v2 in v.Objects do
						if v2.Type == 'ColorSlider' then
							obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
						else
							obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
						end
					end
					obj.Parent = lightingService
					table.insert(newobjects, obj)
				end
			end
		else
			for _, v in newobjects do
				v:Destroy()
			end

			for _, v in oldobjects do
				v.Parent = lightingService
			end

			table.clear(newobjects)
			table.clear(oldobjects)
		end
	end,
	Tooltip = 'Custom lighting objects'
})
for i, v in apidump do
	Toggles[i] = {Objects = {}}
	Toggles[i].Toggle = Atmosphere:CreateToggle({
		Name = i,
		Function = function(callback)
			if Atmosphere.Enabled then
				Atmosphere:Toggle()
				Atmosphere:Toggle()
			end

			for _, toggle in Toggles[i].Objects do
				toggle.Object.Visible = callback
			end
		end
	})

	for i2, v2 in v do
		if v2 == 'Text' or v2 == 'Number' then
			Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
				Name = i2,
				Function = function(enter)
					if Atmosphere.Enabled and enter then
						Atmosphere:Toggle()
						Atmosphere:Toggle()
					end
				end,
				Darker = true,
				Default = v2 == 'Number' and '0' or nil,
				Visible = false
			})
		elseif v2 == 'Color' then
			Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
				Name = i2,
				Function = function()
					if Atmosphere.Enabled then
						Atmosphere:Toggle()
						Atmosphere:Toggle()
					end
				end,
				Darker = true,
				Visible = false
			})
		end
	end
end
local Breadcrumbs
local Texture
local Lifetime
local Thickness
local FadeIn
local FadeOut
local trail, point, point2

Breadcrumbs = vape.Legit:CreateModule({
	Name = 'Breadcrumbs',
	Function = function(callback)
		if callback then
			point = Instance.new('Attachment')
			point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
			point2 = Instance.new('Attachment')
			point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
			trail = Instance.new('Trail')
			trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			trail.TextureMode = Enum.TextureMode.Static
			trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			trail.Lifetime = Lifetime.Value
			trail.Attachment0 = point
			trail.Attachment1 = point2
			trail.FaceCamera = true

			Breadcrumbs:Clean(trail)
			Breadcrumbs:Clean(point)
			Breadcrumbs:Clean(point2)
			Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
				point.Parent = ent.HumanoidRootPart
				point2.Parent = ent.HumanoidRootPart
				trail.Parent = gameCamera
			end))

			if entitylib.isAlive then
				point.Parent = entitylib.character.RootPart
				point2.Parent = entitylib.character.RootPart
				trail.Parent = gameCamera
			end
		else
			trail = nil
			point = nil
			point2 = nil
		end
	end,
	Tooltip = 'Shows a trail behind your character'
})
Texture = Breadcrumbs:CreateTextBox({
	Name = 'Texture',
	Placeholder = 'Texture Id',
	Function = function(enter)
		if enter and trail then
			trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
		end
	end
})
FadeIn = Breadcrumbs:CreateColorSlider({
	Name = 'Fade In',
	Function = function(hue, sat, val)
		if trail then
			trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
		end
	end
})
FadeOut = Breadcrumbs:CreateColorSlider({
	Name = 'Fade Out',
	Function = function(hue, sat, val)
		if trail then
			trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
		end
	end
})
Lifetime = Breadcrumbs:CreateSlider({
	Name = 'Lifetime',
	Min = 1,
	Max = 5,
	Default = 3,
	Decimal = 10,
	Function = function(val)
		if trail then
			trail.Lifetime = val
		end
	end,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
Thickness = Breadcrumbs:CreateSlider({
	Name = 'Thickness',
	Min = 0,
	Max = 2,
	Default = 0.1,
	Decimal = 100,
	Function = function(val)
		if point then
			point.Position = Vector3.new(0, val - 2.7, 0)
		end
		if point2 then
			point2.Position = Vector3.new(0, -val - 2.7, 0)
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
local Cape
local Texture
local part, motor

local function createMotor(char)
	if motor then
		motor:Destroy()
	end

	part.Parent = gameCamera
	motor = Instance.new('Motor6D')
	motor.MaxVelocity = 0.08
	motor.Part0 = part
	motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
	motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
	motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
	motor.Parent = part
end

Cape = vape.Legit:CreateModule({
	Name = 'Cape',
	Function = function(callback)
		if callback then
			part = Instance.new('Part')
			part.Size = Vector3.new(2, 4, 0.1)
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			part.Transparency = 0
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new()
			part.CastShadow = false
			part.Parent = gameCamera
			local capesurface = Instance.new('SurfaceGui')
			capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			capesurface.Adornee = part
			capesurface.Parent = part

			if Texture.Value:find('.webm') then
				local decal = Instance.new('VideoFrame')
				decal.Video = getcustomasset(Texture.Value)
				decal.Size = UDim2.fromScale(1, 1)
				decal.BackgroundTransparency = 1
				decal.Looped = true
				decal.Parent = capesurface
				decal:Play()
			else
				local decal = Instance.new('ImageLabel')
				decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
				decal.Size = UDim2.fromScale(1, 1)
				decal.BackgroundTransparency = 1
				decal.Parent = capesurface
			end

			Cape:Clean(part)
			Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
			if entitylib.isAlive then
				createMotor(entitylib.character)
			end

			repeat
				if motor and entitylib.isAlive then
					local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
					motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
				end
				capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
				part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
				task.wait()
			until not Cape.Enabled
		else
			part = nil
			motor = nil
		end
	end,
	Tooltip = 'Add\'s a cape to your character'
})
Texture = Cape:CreateTextBox({
	Name = 'Texture'
})
local ChinaHat
local Material
local Color
local hat

ChinaHat = vape.Legit:CreateModule({
	Name = 'China Hat',
	Function = function(callback)
		if callback then
			if vape.ThreadFix then
				setthreadidentity(8)
			end

			hat = Instance.new('MeshPart')
			hat.Size = Vector3.new(3, 0.7, 3)
			hat.Name = 'ChinaHat'
			hat.Material = Enum.Material[Material.Value]
			hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			hat.CanCollide = false
			hat.CanQuery = false
			hat.Massless = true
			hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
			hat.Transparency = 1 - Color.Opacity
			hat.Parent = gameCamera
			hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
			local weld = Instance.new('WeldConstraint')
			weld.Part0 = hat
			weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
			weld.Parent = hat

			ChinaHat:Clean(hat)
			ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				if weld then
					weld:Destroy()
				end
				hat.Parent = gameCamera
				hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
				hat.Velocity = Vector3.zero
				weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = char.Head
				weld.Parent = hat
			end))

			repeat
				hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
				task.wait()
			until not ChinaHat.Enabled
		else
			hat = nil
		end
	end,
	Tooltip = 'Puts a china hat on your character (ty mastadawn)'
})
local materials = {'ForceField'}
for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'ForceField' then
		table.insert(materials, v.Name)
	end
end
Material = ChinaHat:CreateDropdown({
	Name = 'Material',
	List = materials,
	Function = function(val)
		if hat then
			hat.Material = Enum.Material[val]
		end
	end
})
Color = ChinaHat:CreateColorSlider({
	Name = 'Hat Color',
	DefaultOpacity = 0.7,
	Function = function(hue, sat, val, opacity)
		if hat then
			hat.Color = Color3.fromHSV(hue, sat, val)
			hat.Transparency = 1 - opacity
		end
	end
})
local Clock
local TwentyFourHour
local label

Clock = vape.Legit:CreateModule({
	Name = 'Clock',
	Function = function(callback)
		if callback then
			repeat
				label.Text = DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
				task.wait(1)
			until not Clock.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current local time'
})
Clock:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
Clock:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
TwentyFourHour = Clock:CreateToggle({
	Name = '24 Hour Clock'
})
label = Instance.new('TextLabel')
label.Size = UDim2.new(0, 100, 0, 41)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = '0:00 PM'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = Clock.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
local Disguise
local Mode
local IDBox
local desc

local function itemAdded(v, manual)
	if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
		repeat
			task.wait()
			v.Parent = game
		until v.Parent == game

		v:ClearAllChildren()
		v:Destroy()
	end
end

local function characterAdded(char)
	if Mode.Value == 'Character' then
		task.wait(0.1)
		char.Character.Archivable = true

		local clone = char.Character:Clone()
		repeat
			if pcall(function()
				desc = playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
			end) and desc then break end
			task.wait(1)
		until not Disguise.Enabled

		if not Disguise.Enabled then
			clone:ClearAllChildren()
			clone:Destroy()
			clone = nil
			if desc then
				desc:Destroy()
				desc = nil
			end
			return
		end

		clone.Parent = game

		local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
			HeightScale = 1,
			SetEmotes = function() end,
			SetEquippedEmotes = function() end
		}
		originalDesc.JumpAnimation = desc.JumpAnimation
		desc.HeightScale = originalDesc.HeightScale

		for _, v in clone:GetChildren() do
			if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
				v:ClearAllChildren()
				v:Destroy()
			end
		end

		clone.Humanoid:ApplyDescriptionClientServer(desc)
		for _, v in char.Character:GetChildren() do
			itemAdded(v)
		end
		Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))

		for _, v in clone:WaitForChild('Animate'):GetChildren() do
			if not char.Character:FindFirstChild('Animate') then return end
			local real = char.Character.Animate:FindFirstChild(v.Name)
			if v and real then
				local anim = v:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
				local realanim = real:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
				if realanim then
					realanim.AnimationId = anim.AnimationId
				end
			end
		end

		for _, v in clone:GetChildren() do
			v:SetAttribute('Disguise', true)
			if v:IsA('Accessory') then
				for _, v2 in v:GetDescendants() do
					if v2:IsA('Weld') and v2.Part1 then
						v2.Part1 = char.Character[v2.Part1.Name]
					end
				end
				v.Parent = char.Character
			elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
				v.Parent = char.Character
			elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
				char.Head.MeshId = v.MeshId
			end
		end

		local localface = char.Character:FindFirstChild('face', true)
		local cloneface = clone:FindFirstChild('face', true)
		if localface and cloneface then
			itemAdded(localface, true)
			cloneface.Parent = char.Head
		end
		originalDesc:SetEmotes(desc:GetEmotes())
		originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
		clone:ClearAllChildren()
		clone:Destroy()
		clone = nil

		if desc then
			desc:Destroy()
			desc = nil
		end
	else
		local data
		repeat
			if pcall(function()
				data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
			end) then break end
			task.wait(1)
		until not Disguise.Enabled

		if not Disguise.Enabled then
			if data then
				table.clear(data)
				data = nil
			end
			return
		end

		if data.BundleType == 'AvatarAnimations' then
			local animate = char.Character:FindFirstChild('Animate')
			if not animate then return end

			for _, v in desc.Items do
				local animtype = v.Name:split(' ')[2]:lower()
				if animtype ~= 'animation' then
					local suc, res = pcall(function()
						return game:GetObjects('rbxassetid://'..v.Id)
					end)

					if suc then
						animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId = res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
					end
				end
			end
		else
			notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
		end
	end
end

Disguise = vape.Legit:CreateModule({
	Name = 'Disguise',
	Function = function(callback)
		if callback then
			Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
			if entitylib.isAlive then
				characterAdded(entitylib.character)
			end
		end
	end,
	Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
})
Mode = Disguise:CreateDropdown({
	Name = 'Mode',
	List = {'Character', 'Animation'},
	Function = function()
		if Disguise.Enabled then
			Disguise:Toggle()
			Disguise:Toggle()
		end
	end
})
IDBox = Disguise:CreateTextBox({
	Name = 'Disguise',
	Placeholder = 'Disguise User Id',
	Function = function()
		if Disguise.Enabled then
			Disguise:Toggle()
			Disguise:Toggle()
		end
	end
})
local FOV
local Value
local oldfov

FOV = vape.Legit:CreateModule({
	Name = 'FOV',
	Function = function(callback)
		if callback then
			oldfov = gameCamera.FieldOfView
			repeat
				gameCamera.FieldOfView = Value.Value
				task.wait()
			until not FOV.Enabled
		else
			gameCamera.FieldOfView = oldfov
		end
	end,
	Tooltip = 'Adjusts camera vision'
})
Value = FOV:CreateSlider({
	Name = 'FOV',
	Min = 30,
	Max = 120
})
--[[
	Grabbing an accurate count of the current framerate
	Source: https://devforum.roblox.com/t/get-client-FPS-trough-a-script/282631
]]
local FPS
local label

FPS = vape.Legit:CreateModule({
	Name = 'FPS',
	Function = function(callback)
		if callback then
			local frames = {}
			local startClock = os.clock()
			local updateTick = tick()

			FPS:Clean(runService.Heartbeat:Connect(function()
				local updateClock = os.clock()
				for i = #frames, 1, -1 do
					frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
				end

				frames[1] = updateClock
				if updateTick < tick() then
					updateTick = tick() + 1
					label.Text = math.floor(os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock))..' FPS'
				end
			end))
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current framerate'
})
FPS:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
FPS:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
label = Instance.new('TextLabel')
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = 'inf FPS'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = FPS.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
local Keystrokes
local Style
local Color
local keys, holder = {}

local function createKeystroke(keybutton, pos, pos2, text)
	if keys[keybutton] then
		keys[keybutton].Key:Destroy()
		keys[keybutton] = nil
	end

	local key = Instance.new('Frame')
	key.Size = keybutton == Enum.KeyCode.Space and UDim2.new(0, 110, 0, 24) or UDim2.new(0, 34, 0, 36)
	key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	key.BackgroundTransparency = 1 - Color.Opacity
	key.Position = pos
	key.Name = keybutton.Name
	key.Parent = holder
	local keytext = Instance.new('TextLabel')
	keytext.BackgroundTransparency = 1
	keytext.Size = UDim2.fromScale(1, 1)
	keytext.Font = Enum.Font.Gotham
	keytext.Text = text or keybutton.Name
	keytext.TextXAlignment = Enum.TextXAlignment.Left
	keytext.TextYAlignment = Enum.TextYAlignment.Top
	keytext.Position = pos2
	keytext.TextSize = keybutton == Enum.KeyCode.Space and 18 or 15
	keytext.TextColor3 = Color3.new(1, 1, 1)
	keytext.Parent = key
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = key

	keys[keybutton] = {Key = key}
end

local function updateKey(inputType)
	local key = keys[inputType.KeyCode]
	if key then
		if key.Tween then
			key.Tween:Cancel()
		end

		if key.Tween2 then
			key.Tween2:Cancel()
		end

		local pressed = inputType.UserInputState == Enum.UserInputState.Begin
		key.Pressed = pressed
		key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
			BackgroundColor3 = pressed and Color3.new(1, 1, 1) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
			BackgroundTransparency = pressed and 0 or 1 - Color.Opacity
		})
		key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
			TextColor3 = pressed and Color3.new() or Color3.new(1, 1, 1)
		})
		key.Tween:Play()
		key.Tween2:Play()
	end
end

Keystrokes = vape.Legit:CreateModule({
	Name = 'Keystrokes',
	Function = function(callback)
		if callback then
			createKeystroke(Enum.KeyCode.W, UDim2.new(0, 38, 0, 0), UDim2.new(0, 6, 0, 5), Style.Value == 'Arrow' and '↑' or nil)
			createKeystroke(Enum.KeyCode.S, UDim2.new(0, 38, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '↓' or nil)
			createKeystroke(Enum.KeyCode.A, UDim2.new(0, 0, 0, 42), UDim2.new(0, 7, 0, 5), Style.Value == 'Arrow' and '←' or nil)
			createKeystroke(Enum.KeyCode.D, UDim2.new(0, 76, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '→' or nil)

			Keystrokes:Clean(inputService.InputBegan:Connect(updateKey))
			Keystrokes:Clean(inputService.InputEnded:Connect(updateKey))
		end
	end,
	Size = UDim2.fromOffset(110, 176),
	Tooltip = 'Shows movement keys onscreen'
})
holder = Instance.new('Frame')
holder.Size = UDim2.fromScale(1, 1)
holder.BackgroundTransparency = 1
holder.Parent = Keystrokes.Children
Style = Keystrokes:CreateDropdown({
	Name = 'Key Style',
	List = {'Keyboard', 'Arrow'},
	Function = function()
		if Keystrokes.Enabled then
			Keystrokes:Toggle()
			Keystrokes:Toggle()
		end
	end
})
Color = Keystrokes:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in keys do
			if not v.Pressed then
				v.Key.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Key.BackgroundTransparency = 1 - opacity
			end
		end
	end
})
Keystrokes:CreateToggle({
	Name = 'Show Spacebar',
	Function = function(callback)
		Keystrokes.Children.Size = UDim2.fromOffset(110, callback and 107 or 78)

		if callback then
			createKeystroke(Enum.KeyCode.Space, UDim2.new(0, 0, 0, 83), UDim2.new(0, 25, 0, -10), '______')
		else
			keys[Enum.KeyCode.Space].Key:Destroy()
			keys[Enum.KeyCode.Space] = nil
		end
	end,
	Default = true
})
local Memory
local label

Memory = vape.Legit:CreateModule({
	Name = 'Memory',
	Function = function(callback)
		if callback then
			repeat
				label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Memory:GetValue()))..' MB'
				task.wait(1)
			until not Memory.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the memory currently used by roblox'
})
Memory:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
Memory:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
label = Instance.new('TextLabel')
label.Size = UDim2.new(0, 100, 0, 41)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = '0 MB'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = Memory.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
local Ping
local label

Ping = vape.Legit:CreateModule({
	Name = 'Ping',
	Function = function(callback)
		if callback then
			repeat
				label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Ping:GetValue()))..' ms'
				task.wait(1)
			until not Ping.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'Shows the current connection speed to the roblox server'
})
Ping:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
Ping:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
label = Instance.new('TextLabel')
label.Size = UDim2.new(0, 100, 0, 41)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = '0 ms'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = Ping.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
local SongBeats
local List
local FOV
local FOVValue = {}
local Volume
local alreadypicked = {}
local beattick = tick()
local oldfov, songobj, songbpm, songtween

local function choosesong()
	local list = List.ListEnabled
	if #alreadypicked >= #list then
		table.clear(alreadypicked)
	end

	if #list <= 0 then
		notif('SongBeats', 'no songs', 10)
		SongBeats:Toggle()
		return
	end

	local chosensong = list[math.random(1, #list)]
	if #list > 1 and table.find(alreadypicked, chosensong) then
		repeat
			task.wait()
			chosensong = list[math.random(1, #list)]
		until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
	end
	if not SongBeats.Enabled then return end

	local split = chosensong:split('/')
	if not isfile(split[1]) then
		notif('SongBeats', 'Missing song ('..split[1]..')', 10)
		SongBeats:Toggle()
		return
	end

	songobj.SoundId = assetfunction(split[1])
	repeat
		task.wait()
	until songobj.IsLoaded or not SongBeats.Enabled

	if SongBeats.Enabled then
		beattick = tick() + (tonumber(split[3]) or 0)
		songbpm = 60 / (tonumber(split[2]) or 50)
		songobj:Play()
	end
end

SongBeats = vape.Legit:CreateModule({
	Name = 'Song Beats',
	Function = function(callback)
		if callback then
			songobj = Instance.new('Sound')
			songobj.Volume = Volume.Value / 100
			songobj.Parent = workspace
			oldfov = gameCamera.FieldOfView

			repeat
				if not songobj.Playing then
					choosesong()
				end

				if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
					beattick = tick() + songbpm
					gameCamera.FieldOfView = oldfov - FOVValue.Value
					songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
						FieldOfView = oldfov
					})
					songtween:Play()
				end

				task.wait()
			until not SongBeats.Enabled
		else
			if songobj then
				songobj:Destroy()
			end

			if songtween then
				songtween:Cancel()
			end

			if oldfov then
				gameCamera.FieldOfView = oldfov
			end

			table.clear(alreadypicked)
		end
	end,
	Tooltip = 'Built in mp3 player'
})
List = SongBeats:CreateTextList({
	Name = 'Songs',
	Placeholder = 'filepath/bpm/start'
})
FOV = SongBeats:CreateToggle({
	Name = 'Beat FOV',
	Function = function(callback)
		if FOVValue.Object then
			FOVValue.Object.Visible = callback
		end

		if SongBeats.Enabled then
			SongBeats:Toggle()
			SongBeats:Toggle()
		end
	end,
	Default = true
})
FOVValue = SongBeats:CreateSlider({
	Name = 'Adjustment',
	Min = 1,
	Max = 30,
	Default = 5,
	Darker = true
})
Volume = SongBeats:CreateSlider({
	Name = 'Volume',
	Function = function(val)
		if songobj then
			songobj.Volume = val / 100
		end
	end,
	Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
local Speedmeter
local label

Speedmeter = vape.Legit:CreateModule({
	Name = 'Speedmeter',
	Function = function(callback)
		if callback then
			repeat
				local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
				local dt = task.wait(0.2)
				local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
				label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
			until not Speedmeter.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41),
	Tooltip = 'A label showing the average velocity in studs'
})
Speedmeter:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
Speedmeter:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
label = Instance.new('TextLabel')
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = '0 sps'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = Speedmeter.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
local TimeChanger
local Value
local old

TimeChanger = vape.Legit:CreateModule({
	Name = 'Time Changer',
	Function = function(callback)
		if callback then
			old = lightingService.TimeOfDay
			lightingService.TimeOfDay = Value.Value..':00:00'
		else
			lightingService.TimeOfDay = old
			old = nil
		end
	end,
	Tooltip = 'Change the time of the current world'
})
Value = TimeChanger:CreateSlider({
	Name = 'Time',
	Min = 0,
	Max = 24,
	Default = 12,
	Function = function(val)
		if TimeChanger.Enabled then 
			lightingService.TimeOfDay = val..':00:00'
		end
	end
})

local MurderMystery
local murderer, sheriff, oldtargetable, oldgetcolor

local function itemAdded(v, plr)
	if v:IsA('Tool') then
		local check = v:FindFirstChild('IsGun') and 'sheriff' or v:FindFirstChild('KnifeServer') and 'murderer' or nil
		check = check or v.Name:lower():find('knife') and 'murderer' or v.Name:lower():find('gun') and 'sheriff' or nil

		if check == 'murderer' and plr ~= murderer then
			murderer = plr
			if plr.Character then
				entitylib.refresh()
			end
		elseif check == 'sheriff' and plr ~= sheriff then
			sheriff = plr
			if plr.Character then
				entitylib.refresh()
			end
		end
	end
end

local function playerAdded(plr)
	MurderMystery:Clean(plr.DescendantAdded:Connect(function(v)
		itemAdded(v, plr)
	end))

	local pack = plr:FindFirstChildWhichIsA('Backpack')
	if pack then
		for _, v in pack:GetChildren() do
			itemAdded(v, plr)
		end
	end

	if plr.Character then
		for _, v in plr.Character:GetChildren() do
			itemAdded(v, plr)
		end
	end
end

MurderMystery = vape.Categories.Minigames:CreateModule({
	Name = 'MurderMystery',
	Function = function(callback)
		if callback then
			oldtargetable, oldgetcolor = entitylib.targetCheck, entitylib.getEntityColor

			entitylib.getEntityColor = function(ent)
				ent = ent.Player
				if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
				if isFriend(ent, true) then
					return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
				end
				return murderer == ent and Color3.new(1, 0.3, 0.3) or sheriff == ent and Color3.new(0, 0.5, 1) or nil
			end

			entitylib.targetCheck = function(ent)
				if ent.Player and isFriend(ent.Player) then return false end
				if murderer == lplr then return true end
				return murderer == ent.Player or sheriff == ent.Player
			end

			for _, v in playersService:GetPlayers() do
				playerAdded(v)
			end

			MurderMystery:Clean(playersService.PlayerAdded:Connect(playerAdded))
			entitylib.refresh()
		else
			entitylib.getEntityColor = oldgetcolor
			entitylib.targetCheck = oldtargetable
			entitylib.refresh()
		end
	end,
	Tooltip = 'Automatic murder mystery teaming based on equipped roblox tools.'
})
local Arrows
local Targets
local Color
local Teammates
local Distance
local DistanceLimit
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then return end
	if not Targets.NPCs.Enabled and ent.NPC then return end
	if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) and (not ent.Friend) then return end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local arrow = Instance.new('ImageLabel')
	arrow.Size = UDim2.fromOffset(256, 256)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.BorderSizePixel = 0
	arrow.Visible = false
	arrow.Image = getcustomasset('fadeware/assets/new/arrowmodule.png')
	arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	arrow.Parent = Folder
	Reference[ent] = arrow
end

local function Removed(ent)
	local v = Reference[ent]
	if v then
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		Reference[ent] = nil
		v:Destroy()
	end
end

local function ColorFunc(hue, sat, val)
	local color = Color3.fromHSV(hue, sat, val)
	for ent, EntityArrow in Reference do
		EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
	end
end

local function Loop()
	for ent, arrow in Reference do
		if Distance.Enabled then
			local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
			if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
				arrow.Visible = false
				continue
			end
		end

		local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
		arrow.Visible = not rootVis
		if rootVis then continue end

		local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
		arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
	end
end

Arrows = vape.Categories.Render:CreateModule({
	Name = 'Arrows',
	Function = function(callback)
		if callback then
			Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			for _, v in entitylib.List do
				if Reference[v] then Removed(v) end
				Added(v)
			end
			Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then Removed(ent) end
				Added(ent)
			end))
			Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				ColorFunc(Color.Hue, Color.Sat, Color.Value)
			end))
			Arrows:Clean(runService.RenderStepped:Connect(Loop))
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
})
Targets = Arrows:CreateTargets({
	Players = true,
	Function = function()
		if Arrows.Enabled then
			Arrows:Toggle()
			Arrows:Toggle()
		end
	end
})
Color = Arrows:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if Arrows.Enabled then
			ColorFunc(hue, sat, val)
		end
	end,
})
Teammates = Arrows:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Arrows.Enabled then
			Arrows:Toggle()
			Arrows:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
Distance = Arrows:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = Arrows:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
local Chams
local Targets
local Mode
local FillColor
local OutlineColor
local FillTransparency
local OutlineTransparency
local Teammates
local Walls
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then return end
	if not Targets.NPCs.Enabled and ent.NPC then return end
	if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	if Mode.Value == 'Highlight' then
		local cham = Instance.new('Highlight')
		cham.Adornee = ent.Character
		cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
		cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
		cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
		cham.FillTransparency = FillTransparency.Value
		cham.OutlineTransparency = OutlineTransparency.Value
		cham.Parent = Folder
		Reference[ent] = cham
	else
		local chams = {}
		for _, v in ent.Character:GetChildren() do
			if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
				local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
				if v.Name == 'Head' then
					box.Radius = 0.75
				else
					box.Size = v.Size
				end
				box.AlwaysOnTop = Walls.Enabled
				box.Adornee = v
				box.ZIndex = 0
				box.Transparency = FillTransparency.Value
				box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				box.Parent = Folder
				table.insert(chams, box)
			end
		end
		Reference[ent] = chams
	end
end

local function Removed(ent)
	if Reference[ent] then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		if type(Reference[ent]) == 'table' then
			for _, v in Reference[ent] do
				v:Destroy()
			end
			table.clear(Reference[ent])
		else
			Reference[ent]:Destroy()
		end
		Reference[ent] = nil
	end
end

Chams = vape.Categories.Render:CreateModule({
	Name = 'Chams',
	Function = function(callback)
		if callback then
			Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				for i, v in Reference do
					local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					if type(v) == 'table' then
						for _, v2 in v do v2.Color3 = color end
					else
						v.FillColor = color
					end
				end
			end))

			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Render players through walls'
})
Targets = Chams:CreateTargets({
	Players = true,
	Function = function()
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end
	})
Mode = Chams:CreateDropdown({
	Name = 'Mode',
	List = {'Highlight', 'BoxHandles'},
	Function = function(val)
		OutlineColor.Object.Visible = val == 'Highlight'
		OutlineTransparency.Object.Visible = val == 'Highlight'
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end
})
FillColor = Chams:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for i, v in Reference do
			local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
			if type(v) == 'table' then
				for _, v2 in v do v2.Color3 = color end
			else
				v.FillColor = color
			end
		end
	end
})
OutlineColor = Chams:CreateColorSlider({
	Name = 'Outline Color',
	DefaultSat = 0,
	Function = function(hue, sat, val)
		for i, v in Reference do
			if type(v) ~= 'table' then
				v.OutlineColor = Color3.fromHSV(hue, sat, val)
			end
		end
	end,
	Darker = true
})
FillTransparency = Chams:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, v in Reference do
			if type(v) == 'table' then
				for _, v2 in v do v2.Transparency = val end
			else
				v.FillTransparency = val
			end
		end
	end,
	Decimal = 10
})
OutlineTransparency = Chams:CreateSlider({
	Name = 'Outline Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, v in Reference do
			if type(v) ~= 'table' then
				v.OutlineTransparency = val
			end
		end
	end,
	Decimal = 10,
	Darker = true
})
Walls = Chams:CreateToggle({
	Name = 'Render Walls',
	Function = function(callback)
		for _, v in Reference do
			if type(v) == 'table' then
				for _, v2 in v do
					v2.AlwaysOnTop = callback
				end
			else
				v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
			end
		end
	end,
	Default = true
})
Teammates = Chams:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Chams.Enabled then
			Chams:Toggle()
			Chams:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
local ESP
local Targets
local Color
local Method
local BoundingBox
local Filled
local HealthBar
local Name
local DisplayName
local Background
local Teammates
local Distance
local DistanceLimit
local Reference = {}
local methodused

local function ESPWorldToViewport(pos)
	local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
	return Vector2.new(newpos.X, newpos.Y)
end

local ESPAdded = {
	Drawing2D = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Main = Drawing.new('Square')
		EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
		EntityESP.Main.ZIndex = 2
		EntityESP.Main.Filled = false
		EntityESP.Main.Thickness = 1
		EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

		if BoundingBox.Enabled then
			EntityESP.Border = Drawing.new('Square')
			EntityESP.Border.Transparency = 0.35
			EntityESP.Border.ZIndex = 1
			EntityESP.Border.Thickness = 1
			EntityESP.Border.Filled = false
			EntityESP.Border.Color = Color3.new()
			EntityESP.Border2 = Drawing.new('Square')
			EntityESP.Border2.Transparency = 0.35
			EntityESP.Border2.ZIndex = 1
			EntityESP.Border2.Thickness = 1
			EntityESP.Border2.Filled = Filled.Enabled
			EntityESP.Border2.Color = Color3.new()
		end

		if HealthBar.Enabled then
			EntityESP.HealthLine = Drawing.new('Line')
			EntityESP.HealthLine.Thickness = 1
			EntityESP.HealthLine.ZIndex = 2
			EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			EntityESP.HealthBorder = Drawing.new('Line')
			EntityESP.HealthBorder.Thickness = 3
			EntityESP.HealthBorder.Transparency = 0.35
			EntityESP.HealthBorder.ZIndex = 1
			EntityESP.HealthBorder.Color = Color3.new()
		end
		
		if Name.Enabled then
			if Background.Enabled then
				EntityESP.TextBKG = Drawing.new('Square')
				EntityESP.TextBKG.Transparency = 0.35
				EntityESP.TextBKG.ZIndex = 0
				EntityESP.TextBKG.Thickness = 1
				EntityESP.TextBKG.Filled = true
				EntityESP.TextBKG.Color = Color3.new()
			end
			EntityESP.Drop = Drawing.new('Text')
			EntityESP.Drop.Color = Color3.new()
			EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
			EntityESP.Drop.ZIndex = 1
			EntityESP.Drop.Center = true
			EntityESP.Drop.Size = 20
			EntityESP.Text = Drawing.new('Text')
			EntityESP.Text.Text = EntityESP.Drop.Text
			EntityESP.Text.ZIndex = 2
			EntityESP.Text.Color = EntityESP.Main.Color
			EntityESP.Text.Center = true
			EntityESP.Text.Size = 20
		end
		Reference[ent] = EntityESP
	end,
	Drawing3D = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Line1 = Drawing.new('Line')
		EntityESP.Line2 = Drawing.new('Line')
		EntityESP.Line3 = Drawing.new('Line')
		EntityESP.Line4 = Drawing.new('Line')
		EntityESP.Line5 = Drawing.new('Line')
		EntityESP.Line6 = Drawing.new('Line')
		EntityESP.Line7 = Drawing.new('Line')
		EntityESP.Line8 = Drawing.new('Line')
		EntityESP.Line9 = Drawing.new('Line')
		EntityESP.Line10 = Drawing.new('Line')
		EntityESP.Line11 = Drawing.new('Line')
		EntityESP.Line12 = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 1
			v.Color = color
		end

		Reference[ent] = EntityESP
	end,
	DrawingSkeleton = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local EntityESP = {}
		EntityESP.Head = Drawing.new('Line')
		EntityESP.HeadFacing = Drawing.new('Line')
		EntityESP.Torso = Drawing.new('Line')
		EntityESP.UpperTorso = Drawing.new('Line')
		EntityESP.LowerTorso = Drawing.new('Line')
		EntityESP.LeftArm = Drawing.new('Line')
		EntityESP.RightArm = Drawing.new('Line')
		EntityESP.LeftLeg = Drawing.new('Line')
		EntityESP.RightLeg = Drawing.new('Line')

		local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		for _, v in EntityESP do
			v.Thickness = 2
			v.Color = color
		end

		Reference[ent] = EntityESP
	end
}

local ESPRemoved = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			for _, v in EntityESP do
				pcall(function()
					v.Visible = false
					v:Remove()
				end)
			end
		end
	end
}
ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D

local ESPUpdated = {
	Drawing2D = function(ent)
		local EntityESP = Reference[ent]
		if EntityESP then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			
			if EntityESP.HealthLine then
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			end

			if EntityESP.Text then
				EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.Text = EntityESP.Text.Text
			end
		end
	end
}

local ColorFunc = {
	Drawing2D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Main.Color = entitylib.getEntityColor(i) or color
			if v.Text then
				v.Text.Color = v.Main.Color
			end
		end
	end,
	Drawing3D = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			local playercolor = entitylib.getEntityColor(i) or color
			for _, v2 in v do
				v2.Color = playercolor
			end
		end
	end
}
ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D

local ESPLoop = {
	Drawing2D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end

			local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(2, ent.HipHeight, 0)).p)
			local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p)
			local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
			local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
			EntityESP.Main.Position = Vector2.new(posx, posy) // 1
			EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
			if EntityESP.Border then
				EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
				EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
				EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
				EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
			end

			if EntityESP.HealthLine then
				local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
				EntityESP.HealthLine.Visible = ent.Health > 0
				EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
				EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
				EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
				EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
			end

			if EntityESP.Text then
				EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
				EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
				if EntityESP.TextBKG then
					EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
					EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
				end
			end
		end
	end,
	Drawing3D = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end

			local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
			local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
			local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
			local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
			local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
			local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
			local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
			local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
			EntityESP.Line1.From = point1
			EntityESP.Line1.To = point2
			EntityESP.Line2.From = point3
			EntityESP.Line2.To = point4
			EntityESP.Line3.From = point5
			EntityESP.Line3.To = point6
			EntityESP.Line4.From = point7
			EntityESP.Line4.To = point8
			EntityESP.Line5.From = point1
			EntityESP.Line5.To = point3
			EntityESP.Line6.From = point1
			EntityESP.Line6.To = point5
			EntityESP.Line7.From = point5
			EntityESP.Line7.To = point7
			EntityESP.Line8.From = point7
			EntityESP.Line8.To = point3
			EntityESP.Line9.From = point2
			EntityESP.Line9.To = point4
			EntityESP.Line10.From = point2
			EntityESP.Line10.To = point6
			EntityESP.Line11.From = point6
			EntityESP.Line11.To = point8
			EntityESP.Line12.From = point8
			EntityESP.Line12.To = point4
		end
	end,
	DrawingSkeleton = function()
		for ent, EntityESP in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					for _, obj in EntityESP do
						obj.Visible = false
					end
					continue
				end
			end

			local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
			for _, obj in EntityESP do
				obj.Visible = rootVis
			end
			if not rootVis then continue end
			
			local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
			pcall(function()
				local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
				local head = ESPWorldToViewport((ent.Head.CFrame).p)
				local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
				local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
				local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
				local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
				local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
				local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
				local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
				local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
				local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
				local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
				local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
				EntityESP.Head.From = toptorso
				EntityESP.Head.To = head
				EntityESP.HeadFacing.From = head
				EntityESP.HeadFacing.To = headfront
				EntityESP.UpperTorso.From = toplefttorso
				EntityESP.UpperTorso.To = toprighttorso
				EntityESP.Torso.From = toptorso
				EntityESP.Torso.To = bottomtorso
				EntityESP.LowerTorso.From = bottomlefttorso
				EntityESP.LowerTorso.To = bottomrighttorso
				EntityESP.LeftArm.From = toplefttorso
				EntityESP.LeftArm.To = leftarm
				EntityESP.RightArm.From = toprighttorso
				EntityESP.RightArm.To = rightarm
				EntityESP.LeftLeg.From = bottomlefttorso
				EntityESP.LeftLeg.To = leftleg
				EntityESP.RightLeg.From = bottomrighttorso
				EntityESP.RightLeg.To = rightleg
			end)
		end
	end
}

ESP = vape.Categories.Render:CreateModule({
	Name = 'ESP',
	Function = function(callback)
		if callback then
			methodused = 'Drawing'..Method.Value
			if ESPRemoved[methodused] then
				ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
			end
			if ESPAdded[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						ESPRemoved[methodused](v)
					end
					ESPAdded[methodused](v)
				end
				ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						ESPRemoved[methodused](ent)
					end
					ESPAdded[methodused](ent)
				end))
			end
			if ESPUpdated[methodused] then
				ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
				for _, v in entitylib.List do
					ESPUpdated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if ESPLoop[methodused] then
				ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
			end
		else
			if ESPRemoved[methodused] then
				for i in Reference do
					ESPRemoved[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
})
Targets = ESP:CreateTargets({
	Players = true,
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end
})
Method = ESP:CreateDropdown({
	Name = 'Mode',
	List = {'2D', '3D', 'Skeleton'},
	Function = function(val)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		BoundingBox.Object.Visible = (val == '2D')
		Filled.Object.Visible = (val == '2D')
		HealthBar.Object.Visible = (val == '2D')
		Name.Object.Visible = (val == '2D')
		DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
		Background.Object.Visible = Name.Object.Visible and Name.Enabled
	end,
})
Color = ESP:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if ESP.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end
})
BoundingBox = ESP:CreateToggle({
	Name = 'Bounding Box',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true
})
Filled = ESP:CreateToggle({
	Name = 'Filled',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
HealthBar = ESP:CreateToggle({
	Name = 'Health Bar',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
Name = ESP:CreateToggle({
	Name = 'Name',
	Function = function(callback)
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
		DisplayName.Object.Visible = callback
		Background.Object.Visible = callback
	end,
	Darker = true
})
DisplayName = ESP:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Darker = true
})
Background = ESP:CreateToggle({
	Name = 'Show Background',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Darker = true
})
Teammates = ESP:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if ESP.Enabled then
			ESP:Toggle()
			ESP:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
Distance = ESP:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = ESP:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
local Fullbright
local Mode
local oldsettings = {}
local flag

local function ChangeLighting(prop)
	if flag then
		return
	end

	flag = true
	lightingService.Ambient = Color3.new(1, 1, 1)
	lightingService.OutdoorAmbient = Color3.new(1, 1, 1)
	lightingService.Brightness = 3
	runService.RenderStepped:Wait()
	flag = false
end

Fullbright = vape.Categories.Render:CreateModule({
	Name = 'Fullbright',
	Function = function(callback)
		if callback then
			if Mode.Value == 'Lighting' then
				for _, v in {'Ambient', 'OutdoorAmbient', 'Brightness'} do
					oldsettings[v] = lightingService[v]
				end

				Fullbright:Clean(lightingService.Changed:Connect(ChangeLighting))
				task.spawn(ChangeLighting)
			else
				local inst = Instance.new('PointLight')
				inst.Range = 1000
				Fullbright:Clean(inst)

				repeat
					inst.Parent = entitylib.isAlive and entitylib.character.RootPart or nil
					task.wait(0.1)
				until not Fullbright.Enabled
			end
		else
			flag = false
			for i, v in oldsettings do
				lightingService[i] = v
			end
			table.clear(oldsettings)
		end
	end,
	Tooltip = 'Increase the lighting of the world around you.'
})
Mode = Fullbright:CreateDropdown({
	Name = 'Mode',
	List = {'Lighting', 'PointLight'},
	Function = function()
		if Fullbright.Enabled then
			Fullbright:Toggle()
			Fullbright:Toggle()
		end
	end
})
local GamingChair = {Enabled = false}
local Color
local wheelpositions = {
	Vector3.new(-0.8, -0.6, -0.18),
	Vector3.new(0.1, -0.6, -0.88),
	Vector3.new(0, -0.6, 0.7)
}
local chairhighlight
local currenttween
local movingsound
local flyingsound
local chairanim
local chair

GamingChair = vape.Categories.Render:CreateModule({
	Name = 'GamingChair',
	Function = function(callback)
		if callback then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			chair = Instance.new('MeshPart')
			chair.Color = Color3.fromRGB(21, 21, 21)
			chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
			chair.CanCollide = false
			chair.Massless = true
			chair.MeshId = 'rbxassetid://12972961089'
			chair.Material = Enum.Material.SmoothPlastic
			chair.Parent = workspace
			movingsound = Instance.new('Sound')
			--movingsound.SoundId = downloadVapeAsset('vape/assets/ChairRolling.mp3')
			movingsound.Volume = 0.4
			movingsound.Looped = true
			movingsound.Parent = workspace
			flyingsound = Instance.new('Sound')
			--flyingsound.SoundId = downloadVapeAsset('vape/assets/ChairFlying.mp3')
			flyingsound.Volume = 0.4
			flyingsound.Looped = true
			flyingsound.Parent = workspace
			local chairweld = Instance.new('WeldConstraint')
			chairweld.Part0 = chair
			chairweld.Parent = chair
			if entitylib.isAlive then
				chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
				chairweld.Part1 = entitylib.character.RootPart
			end
			chairhighlight = Instance.new('Highlight')
			chairhighlight.FillTransparency = 1
			chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
			chairhighlight.OutlineTransparency = 0.2
			chairhighlight.Parent = chair
			local chairarms = Instance.new('MeshPart')
			chairarms.Color = chair.Color
			chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
			chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
			chairarms.MeshId = 'rbxassetid://12972673898'
			chairarms.CanCollide = false
			chairarms.Parent = chair
			local chairarmsweld = Instance.new('WeldConstraint')
			chairarmsweld.Part0 = chairarms
			chairarmsweld.Part1 = chair
			chairarmsweld.Parent = chair
			local chairlegs = Instance.new('MeshPart')
			chairlegs.Color = chair.Color
			chairlegs.Name = 'Legs'
			chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
			chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
			chairlegs.MeshId = 'rbxassetid://13003181606'
			chairlegs.CanCollide = false
			chairlegs.Parent = chair
			local chairfan = Instance.new('MeshPart')
			chairfan.Color = chair.Color
			chairfan.Name = 'Fan'
			chairfan.Size = Vector3.zero
			chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
			chairfan.MeshId = 'rbxassetid://13004977292'
			chairfan.CanCollide = false
			chairfan.Parent = chair
			local trails = {}
			for _, v in wheelpositions do
				local attachment = Instance.new('Attachment')
				attachment.Position = v
				attachment.Parent = chairlegs
				local attachment2 = Instance.new('Attachment')
				attachment2.Position = v + Vector3.new(0, 0, 0.18)
				attachment2.Parent = chairlegs
				local trail = Instance.new('Trail')
				trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
				trail.TextureMode = Enum.TextureMode.Static
				trail.Transparency = NumberSequence.new(0.5)
				trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
				trail.Attachment0 = attachment
				trail.Attachment1 = attachment2
				trail.Lifetime = 20
				trail.MaxLength = 60
				trail.MinLength = 0.1
				trail.Parent = chairlegs
				table.insert(trails, trail)
			end
			GamingChair:Clean(chair)
			GamingChair:Clean(movingsound)
			GamingChair:Clean(flyingsound)
			chairanim = {Stop = function() end}
			local oldmoving = false
			local oldflying = false
			repeat
				if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
					if not chairanim.IsPlaying then
						local temp2 = Instance.new('Animation')
						temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and 'http://www.roblox.com/asset/?id=2506281703' or 'http://www.roblox.com/asset/?id=178130996'
						chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
						chairanim.Priority = Enum.AnimationPriority.Movement
						chairanim.Looped = true
						chairanim:Play()
					end
					chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
					chairweld.Part1 = entitylib.character.RootPart
					chairlegs.Velocity = Vector3.zero
					chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
					chairfan.Velocity = Vector3.zero
					chairfan.CFrame = chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
					local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
					local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or vape.Modules.InfiniteFly and vape.Modules.InfiniteFly.Enabled
					if movingsound.TimePosition > 1.9 then
						movingsound.TimePosition = 0.2
					end
					movingsound.PlaybackSpeed = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude / 16
					for _, v in trails do
						v.Enabled = not flying and moving
						v.Color = ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
					end
					if moving ~= oldmoving then
						if movingsound.IsPlaying then
							if not moving then
								movingsound:Stop()
							end
						else
							if not flying and moving then
								movingsound:Play()
							end
						end
						oldmoving = moving
					end
					if flying ~= oldflying then
						if flying then
							if movingsound.IsPlaying then
								movingsound:Stop()
							end
							if not flyingsound.IsPlaying then
								flyingsound:Play()
							end
							if currenttween then
								currenttween:Cancel()
							end
							tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
								Size = Vector3.zero
							})
							tween.Completed:Connect(function(state)
								if state == Enum.PlaybackState.Completed then
									chairfan.Transparency = 0
									chairlegs.Transparency = 1
									tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
										Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
									})
									tween:Play()
								end
							end)
							tween:Play()
						else
							if flyingsound.IsPlaying then
								flyingsound:Stop()
							end
							if not movingsound.IsPlaying and moving then
								movingsound:Play()
							end
							if currenttween then currenttween:Cancel() end
							tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
								Size = Vector3.zero
							})
							tween.Completed:Connect(function(state)
								if state == Enum.PlaybackState.Completed then
									chairfan.Transparency = 1
									chairlegs.Transparency = 0
									tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
										Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
									})
									tween:Play()
								end
							end)
							tween:Play()
						end
						oldflying = flying
					end
				else
					chair.Anchored = true
					chairlegs.Anchored = true
					chairfan.Anchored = true
					repeat task.wait() until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
					chair.Anchored = false
					chairlegs.Anchored = false
					chairfan.Anchored = false
					chairanim:Stop()
				end
				task.wait()
			until not GamingChair.Enabled
		else
			if chairanim then
				chairanim:Stop()
			end
		end
	end,
	Tooltip = 'Sit in the best gaming chair known to mankind.'
})
Color = GamingChair:CreateColorSlider({
	Name = 'Color',
	Function = function(h, s, v)
		if chairhighlight then
			chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
		end
	end
})
local Health

Health = vape.Categories.Render:CreateModule({
	Name = 'Health',
	Function = function(callback)
		if callback then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(100, 20)
			label.Position = UDim2.new(0.5, 6, 0.5, 30)
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.BackgroundTransparency = 1
			label.Text = '100 ❤️'
			label.TextSize = 18
			label.Font = Enum.Font.Arial
			label.Parent = vape.gui
			Health:Clean(label)
			
			repeat
				label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
				task.wait()
			until not Health.Enabled
		end
	end,
	Tooltip = 'Displays your health in the center of your screen.'
})
local NameTags
local Targets
local Color
local Background
local Stroke
local DisplayName
local Health
local Distance
local DrawingToggle
local Scale
local FontOption
local Teammates
local DistanceCheck
local DistanceLimit
local Strings, Sizes, Reference = {}, {}, {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui
local methodused

local Added = {
	Normal = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

		if Health.Enabled then
			local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
		end

		if Distance.Enabled then
			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
		end

		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.FontFace = FontOption.Value
		local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Background.Value
		nametag.TextStrokeTransparency = Stroke.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = Strings[ent]
		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end,
	Drawing = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

		local nametag = {}
		nametag.BG = Drawing.new('Square')
		nametag.BG.Filled = true
		nametag.BG.Transparency = 1 - Background.Value
		nametag.BG.Color = Color3.new()
		nametag.BG.ZIndex = 1
		nametag.Text = Drawing.new('Text')
		nametag.Text.Size = 15 * Scale.Value
		nametag.Text.Font = 0
		nametag.Text.ZIndex = 2
		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

		if Health.Enabled then
			Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
		end

		if Distance.Enabled then
			Strings[ent] = '[%s] '..Strings[ent]
		end

		nametag.Text.Text = Strings[ent]
		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
		Reference[ent] = nametag
	end
}

local Removed = {
	Normal = function(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			v:Destroy()
		end
	end,
	Drawing = function(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			for _, obj in v do
				pcall(function()
					obj.Visible = false
					obj:Remove()
				end)
			end
		end
	end
}

local Updated = {
	Normal = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

			if Health.Enabled then
				local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(color.R * 255))..','..tostring(math.floor(color.G * 255))..','..tostring(math.floor(color.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end

			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
		end
	end,
	Drawing = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
				nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
			else
				nametag.Text.Text = Strings[ent]
			end

			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	end
}

local ColorFunc = {
	Normal = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.TextColor3 = entitylib.getEntityColor(i) or color
		end
	end,
	Drawing = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Text.Color = entitylib.getEntityColor(i) or color
		end
	end
}

local Loop = {
	Normal = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
				if Sizes[ent] ~= mag then
					nametag.Text = string.format(Strings[ent], mag)
					local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
		end
	end,
	Drawing = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Text.Visible = false
					nametag.BG.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Text.Visible = headVis
			nametag.BG.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
				if Sizes[ent] ~= mag then
					nametag.Text.Text = string.format(Strings[ent], mag)
					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
		end
	end
}

NameTags = vape.Categories.Render:CreateModule({
	Name = 'NameTags',
	Function = function(callback)
		if callback then
			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
			if Removed[methodused] then
				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
			end
			if Added[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						Removed[methodused](v)
					end
					Added[methodused](v)
				end
				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed[methodused](ent)
					end
					Added[methodused](ent)
				end))
			end
			if Updated[methodused] then
				NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
				for _, v in entitylib.List do
					Updated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if Loop[methodused] then
				NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
			end
		else
			if Removed[methodused] then
				for i in Reference do
					Removed[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Renders nametags on entities through walls.'
})
Targets = NameTags:CreateTargets({
	Players = true,
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
FontOption = NameTags:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
Color = NameTags:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if NameTags.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end
})
Scale = NameTags:CreateSlider({
	Name = 'Scale',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10
})
Background = NameTags:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10
})
Stroke = NameTags:CreateSlider({
	Name = 'Stroke Transparency',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 1,
	Min = 0,
	Max = 1,
	Decimal = 10
})
Health = NameTags:CreateToggle({
	Name = 'Health',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
Distance = NameTags:CreateToggle({
	Name = 'Distance',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
DisplayName = NameTags:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true
})
Teammates = NameTags:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
DrawingToggle = NameTags:CreateToggle({
	Name = 'Drawing',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
DistanceCheck = NameTags:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = NameTags:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
local PlayerModel
local Scale
local Local
local Mesh
local Texture
local Rots = {}
local models = {}

local function addMesh(ent)
	if vape.ThreadFix then 
		setthreadidentity(8)
	end
	local root = ent.RootPart
	local part = Instance.new('Part')
	part.Size = Vector3.new(3, 3, 3)
	part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = workspace
	local meshd = Instance.new('SpecialMesh')
	meshd.MeshId = Mesh.Value
	meshd.TextureId = Texture.Value
	meshd.Scale = Vector3.one * Scale.Value
	meshd.Parent = part
	local weld = Instance.new('WeldConstraint')
	weld.Part0 = part
	weld.Part1 = root
	weld.Parent = part
	models[root] = part
end

local function removeMesh(ent)
	if models[ent.RootPart] then 
		models[ent.RootPart]:Destroy()
		models[ent.RootPart] = nil
	end
end

PlayerModel = vape.Categories.Render:CreateModule({
	Name = 'PlayerModel',
	Function = function(callback)
		if callback then 
			if Local.Enabled then 
				PlayerModel:Clean(entitylib.Events.LocalAdded:Connect(addMesh))
				PlayerModel:Clean(entitylib.Events.LocalRemoved:Connect(removeMesh))
				if entitylib.isAlive then 
					task.spawn(addMesh, entitylib.character)
				end
			end
			PlayerModel:Clean(entitylib.Events.EntityAdded:Connect(addMesh))
			PlayerModel:Clean(entitylib.Events.EntityRemoved:Connect(removeMesh))
			for _, ent in entitylib.List do 
				task.spawn(addMesh, ent)
			end
		else
			for _, part in models do 
				part:Destroy()
			end
			table.clear(models)
		end
	end,
	Tooltip = 'Change the player models to a Mesh'
})
Scale = PlayerModel:CreateSlider({
	Name = 'Scale',
	Min = 0,
	Max = 2,
	Default = 1,
	Decimal = 100,
	Function = function(val)
		for _, part in models do 
			part.Mesh.Scale = Vector3.one * val
		end
	end
})
for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do 
	table.insert(Rots, PlayerModel:CreateSlider({
		Name = name,
		Min = 0,
		Max = 360,
		Function = function(val)
			for root, part in models do 
				part.WeldConstraint.Enabled = false
				part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				part.WeldConstraint.Enabled = true
			end
		end
	}))
end
Local = PlayerModel:CreateToggle({
	Name = 'Local',
	Function = function()
		if PlayerModel.Enabled then 
			PlayerModel:Toggle()
			PlayerModel:Toggle()
		end
	end
})
Mesh = PlayerModel:CreateTextBox({
	Name = 'Mesh',
	Placeholder = 'mesh id',
	Function = function()
		for _, part in models do 
			part.Mesh.MeshId = Mesh.Value
		end
	end
})
Texture = PlayerModel:CreateTextBox({
	Name = 'Texture',
	Placeholder = 'texture id',
	Function = function()
		for _, part in models do 
			part.Mesh.TextureId = Texture.Value
		end
	end
})

local Radar
local Targets
local DotStyle
local PlayerColor
local Clamp
local Reference = {}
local bkg

local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then return end
	if not Targets.NPCs.Enabled and ent.NPC then return end
	if (not ent.Targetable) and (not ent.Friend) then return end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local dot = Instance.new('Frame')
	dot.Size = UDim2.fromOffset(4, 4)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
	dot.Parent = bkg
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
	corner.Parent = dot
	local stroke = Instance.new('UIStroke')
	stroke.Color = Color3.new()
	stroke.Thickness = 1
	stroke.Transparency = 0.8
	stroke.Parent = dot
	Reference[ent] = dot
end

local function Removed(ent)
	local v = Reference[ent]
	if v then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		Reference[ent] = nil
		v:Destroy()
	end
end

Radar = vape:CreateOverlay({
	Name = 'Radar',
	Icon = getcustomasset('fadeware/assets/new/radaricon.png'),
	Size = UDim2.fromOffset(14, 14),
	Position = UDim2.fromOffset(12, 13),
	Function = function(callback)
		if callback then
			Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
			Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				for ent, dot in Reference do
					dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
				end
			end))
			Radar:Clean(runService.RenderStepped:Connect(function()
				for ent, dot in Reference do
					if entitylib.isAlive then
						local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
						dot.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
					end
				end
			end))
		else
			for ent in Reference do
				Removed(ent)
			end
		end
	end
})
Targets = Radar:CreateTargets({
	Players = true,
	Function = function()
		if Radar.Button.Enabled then
			Radar.Button:Toggle()
			Radar.Button:Toggle()
		end
	end
})
DotStyle = Radar:CreateDropdown({
	Name = 'Dot Style',
	List = {'Circles', 'Squares'},
	Function = function(val)
		for _, dot in Reference do
			dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
		end
	end
})
PlayerColor = Radar:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		for ent, dot in Reference do
			dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
		end
	end
})
bkg = Instance.new('Frame')
bkg.Size = UDim2.fromOffset(216, 216)
bkg.Position = UDim2.fromOffset(2, 2)
bkg.BackgroundColor3 = Color3.new()
bkg.BackgroundTransparency = 0.5
bkg.ClipsDescendants = true
bkg.Parent = Radar.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = bkg
local stroke = Instance.new('UIStroke')
stroke.Thickness = 2
stroke.Color = Color3.new()
stroke.Transparency = 0.4
stroke.Parent = bkg
local line1 = Instance.new('Frame')
line1.Size = UDim2.new(0, 2, 1, 0)
line1.Position = UDim2.fromScale(0.5, 0.5)
line1.AnchorPoint = Vector2.new(0.5, 0.5)
line1.ZIndex = 0
line1.BackgroundColor3 = Color3.new(1, 1, 1)
line1.BackgroundTransparency = 0.5
line1.BorderSizePixel = 0
line1.Parent = bkg
local line2 = line1:Clone()
line2.Size = UDim2.new(1, 0, 0, 2)
line2.Parent = bkg
local bar = Instance.new('Frame')
bar.Size = UDim2.new(1, -6, 0, 4)
bar.Position = UDim2.fromOffset(3, 0)
bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
bar.Parent = bkg
local barcorner = Instance.new('UICorner')
barcorner.CornerRadius = UDim.new(0, 8)
barcorner.Parent = bar
Radar:CreateColorSlider({
	Name = 'Bar Color',
	Function = function(hue, sat, val)
		bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
	end
})
Radar:CreateToggle({
	Name = 'Show Background',
	Default = true,
	Function = function(callback)
		bkg.BackgroundTransparency = callback and 0.5 or 1
		bar.BackgroundTransparency = callback and 0 or 1
		stroke.Transparency = callback and 0.4 or 1
	end
})
Radar:CreateToggle({
	Name = 'Show Cross',
	Default = true,
	Function = function(callback)
		line1.BackgroundTransparency = callback and 0.5 or 1
		line2.BackgroundTransparency = callback and 0.5 or 1
	end
})
Clamp = Radar:CreateToggle({
	Name = 'Clamp Radar',
	Default = true
})
local Search
local List
local Color
local FillTransparency
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local function Add(v)
	if not table.find(List.ListEnabled, v.Name) then return end
	if v:IsA('BasePart') or v:IsA('Model') then
		local size = v:IsA('Model') and v:GetExtentsSize() or v.Size
		local box = Instance.new('BoxHandleAdornment')
		box.AlwaysOnTop = true
		box.Adornee = v
		box.Size = size.Magnitude > 0.4 and size or Vector3.one
		box.ZIndex = 0
		box.Transparency = FillTransparency.Value
		box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		box.Parent = Folder
		Reference[v] = box
	end
end

Search = vape.Categories.Render:CreateModule({
	Name = 'Search',
	Function = function(callback)
		if callback then
			Search:Clean(workspace.DescendantAdded:Connect(Add))
			Search:Clean(workspace.DescendantRemoving:Connect(function(v)
				if Reference[v] then
					Reference[v]:Destroy()
					Reference[v] = nil
				end
			end))

			for _, v in workspace:GetDescendants() do
				Add(v)
			end
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'Draws box around selected parts\nAdd parts in Search frame'
})
List = Search:CreateTextList({
	Name = 'Parts',
	Function = function()
		if Search.Enabled then
			Search:Toggle()
			Search:Toggle()
		end
	end
})
Color = Search:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for _, v in Reference do
			v.Color3 = Color3.fromHSV(hue, sat, val)
		end
	end
})
FillTransparency = Search:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Function = function(val)
		for _, v in Reference do
			v.Transparency = val
		end
	end,
	Decimal = 10
})
local SessionInfo
local FontOption
local Hide
local TextSize
local BorderColor
local Title
local TitleOffset = {}
local Custom
local CustomBox
local infoholder
local infolabel
local infostroke

SessionInfo = vape:CreateOverlay({
	Name = 'Session Info',
	Icon = getcustomasset('fadeware/assets/new/textguiicon.png'),
	Size = UDim2.fromOffset(16, 12),
	Position = UDim2.fromOffset(12, 14),
	Function = function(callback)
		if callback then
			local teleportedServers
			SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
				if not teleportedServers then
					teleportedServers = true
					queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
				end
			end))

			if shared.vapesessioninfo then
				for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
					if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
						vape.Libraries.sessioninfo.Objects[i].Value = v.Value
					end
				end
			end

			repeat
				if vape.Libraries.sessioninfo then
					local stuff = {''}
					if Title.Enabled then
						stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
					end

					for i, v in vape.Libraries.sessioninfo.Objects do
						stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
					end

					if #Hide.ListEnabled > 0 then
						local key, val
						repeat
							local oldkey = key
							key, val = next(stuff, key)
							if val == false then
								table.remove(stuff, key)
								key = oldkey
							end
						until not key
					end

					if Custom.Enabled then
						table.insert(stuff, CustomBox.Value)
					end

					if not Title.Enabled then
						table.remove(stuff, 1)
					end
					infolabel.Text = table.concat(stuff, '\n')
					infolabel.FontFace = FontOption.Value
					infolabel.TextSize = TextSize.Value
					local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
					infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
				end

				task.wait(1)
			until not SessionInfo.Button or not SessionInfo.Button.Enabled
		end
	end
})
FontOption = SessionInfo:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial'
})
Hide = SessionInfo:CreateTextList({
	Name = 'Blacklist',
	Tooltip = 'Name of entry to hide.',
	Icon = getcustomasset('fadeware/assets/new/blockedicon.png'),
	Tab = getcustomasset('fadeware/assets/new/blockedtab.png'),
	TabSize = UDim2.fromOffset(21, 16),
	Color = Color3.fromRGB(250, 50, 56)
})
SessionInfo:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		infoholder.BackgroundTransparency = 1 - opacity
	end
})
BorderColor = SessionInfo:CreateColorSlider({
	Name = 'Border Color',
	Function = function(hue, sat, val, opacity)
		infostroke.Color = Color3.fromHSV(hue, sat, val)
		infostroke.Transparency = 1 - opacity
	end,
	Darker = true,
	Visible = false
})
TextSize = SessionInfo:CreateSlider({
	Name = 'Text Size',
	Min = 1,
	Max = 30,
	Default = 16
})
Title = SessionInfo:CreateToggle({
	Name = 'Title',
	Function = function(callback)
		if TitleOffset.Object then
			TitleOffset.Object.Visible = callback
		end
	end,
	Default = true
})
TitleOffset = SessionInfo:CreateToggle({
	Name = 'Offset',
	Default = true,
	Darker = true
})
SessionInfo:CreateToggle({
	Name = 'Border',
	Function = function(callback)
		infostroke.Enabled = callback
		BorderColor.Object.Visible = callback
	end
})
Custom = SessionInfo:CreateToggle({
	Name = 'Add custom text',
	Function = function(enabled)
		CustomBox.Object.Visible = enabled
	end
})
CustomBox = SessionInfo:CreateTextBox({
	Name = 'Custom text',
	Darker = true,
	Visible = false
})
infoholder = Instance.new('Frame')
infoholder.BackgroundColor3 = Color3.new()
infoholder.BackgroundTransparency = 0.5
infoholder.Parent = SessionInfo.Children
vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
	infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
	infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
end))
local sessioninfocorner = Instance.new('UICorner')
sessioninfocorner.CornerRadius = UDim.new(0, 5)
sessioninfocorner.Parent = infoholder
infolabel = Instance.new('TextLabel')
infolabel.Size = UDim2.new(1, -16, 1, -16)
infolabel.Position = UDim2.fromOffset(8, 8)
infolabel.BackgroundTransparency = 1
infolabel.TextXAlignment = Enum.TextXAlignment.Left
infolabel.TextYAlignment = Enum.TextYAlignment.Top
infolabel.TextSize = 16
infolabel.TextColor3 = Color3.new(1, 1, 1)
infolabel.TextStrokeColor3 = Color3.new()
infolabel.TextStrokeTransparency = 0.8
infolabel.Font = Enum.Font.Arial
infolabel.RichText = true
infolabel.Parent = infoholder
infostroke = Instance.new('UIStroke')
infostroke.Enabled = false
infostroke.Color = Color3.fromHSV(0.44, 1, 1)
infostroke.Parent = infoholder
addBlur(infoholder)
vape.Libraries.sessioninfo = {
	Objects = {},
	AddItem = function(self, name, startvalue, func, saved)
		func, saved = func or function(val) return val end, saved == nil or saved
		self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
		return {
			Increment = function(_, val)
				self.Objects[name].Value += (val or 1)
			end,
			Get = function()
				return self.Objects[name].Value
			end
		}
	end
}
vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
	return os.date('!%X', math.floor(os.clock() - value))
end)
local Tracers
local Targets
local Color
local Transparency
local StartPosition
local EndPosition
local Teammates
local DistanceColor
local Distance
local DistanceLimit
local Behind
local Reference = {}

local function Added(ent)
	if not Targets.Players.Enabled and ent.Player then return end
	if not Targets.NPCs.Enabled and ent.NPC then return end
	if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local EntityTracer = Drawing.new('Line')
	EntityTracer.Thickness = 1
	EntityTracer.Transparency = 1 - Transparency.Value
	EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	Reference[ent] = EntityTracer
end

local function Removed(ent)
	local v = Reference[ent]
	if v then
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		Reference[ent] = nil
		pcall(function()
			v.Visible = false
			v:Remove()
		end)
	end
end

local function ColorFunc(hue, sat, val)
	if DistanceColor.Enabled then return end
	local tracerColor = Color3.fromHSV(hue, sat, val)
	for ent, EntityTracer in Reference do
		EntityTracer.Color = entitylib.getEntityColor(ent) or tracerColor
	end
end

local function Loop()
	local screenSize = vape.gui.AbsoluteSize
	local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation() or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))

	for ent, EntityTracer in Reference do
		local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
		if Distance.Enabled and distance then
			if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
				EntityTracer.Visible = false
				continue
			end
		end

		local pos = ent[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
		local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
		if not rootVis and Behind.Enabled then
			local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
			tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
			rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
			rootVis = true
		end

		local endVector = Vector2.new(rootPos.X, rootPos.Y)
		EntityTracer.Visible = rootVis
		EntityTracer.From = startVector
		EntityTracer.To = endVector
		if DistanceColor.Enabled and distance then
			EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
		end
	end
end

Tracers = vape.Categories.Render:CreateModule({
	Name = 'Tracers',
	Function = function(callback)
		if callback then
			Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
			for _, v in entitylib.List do
				if Reference[v] then
					Removed(v)
				end
				Added(v)
			end
			Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
				if Reference[ent] then
					Removed(ent)
				end
				Added(ent)
			end))
			Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
				ColorFunc(Color.Hue, Color.Sat, Color.Value)
			end))
			Tracers:Clean(runService.RenderStepped:Connect(Loop))
		else
			for i in Reference do
				Removed(i)
			end
		end
	end,
	Tooltip = 'Renders tracers on players.'
})
Targets = Tracers:CreateTargets({
	Players = true,
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end
})
StartPosition = Tracers:CreateDropdown({
	Name = 'Start Position',
	List = {'Middle', 'Bottom', 'Mouse'},
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end
})
EndPosition = Tracers:CreateDropdown({
	Name = 'End Position',
	List = {'Head', 'Torso'},
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end
})
Color = Tracers:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if Tracers.Enabled then
			ColorFunc(hue, sat, val)
		end
	end
})
Transparency = Tracers:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Function = function(val)
		for _, tracer in Reference do
			tracer.Transparency = 1 - val
		end
	end,
	Decimal = 10
})
DistanceColor = Tracers:CreateToggle({
	Name = 'Color by distance',
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end
})
Distance = Tracers:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = Tracers:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
Behind = Tracers:CreateToggle({
	Name = 'Behind',
	Default = true
})
Teammates = Tracers:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if Tracers.Enabled then
			Tracers:Toggle()
			Tracers:Toggle()
		end
	end,
	Default = true,
	Tooltip = 'Hides teammates & non targetable entities'
})
local Waypoints
local FontOption
local List
local Color
local Scale
local Background
WaypointFolder = Instance.new('Folder')
WaypointFolder.Parent = vape.gui

Waypoints = vape.Categories.Render:CreateModule({
	Name = 'Waypoints',
	Function = function(callback)
		if callback then
			for _, v in List.ListEnabled do
				local split = v:split('/')
				local tagSize = getfontsize(removeTags(split[2]), 14 * Scale.Value, FontOption.Value, Vector2.new(100000, 100000))
				local billboard = Instance.new('BillboardGui')
				billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
				billboard.StudsOffsetWorldSpace = Vector3.new(unpack(split[1]:split(',')))
				billboard.AlwaysOnTop = true
				billboard.Parent = WaypointFolder
				local tag = Instance.new('TextLabel')
				tag.BackgroundColor3 = Color3.new()
				tag.BorderSizePixel = 0
				tag.Visible = true
				tag.RichText = true
				tag.FontFace = FontOption.Value
				tag.TextSize = 14 * Scale.Value
				tag.BackgroundTransparency = Background.Value
				tag.Size = billboard.Size
				tag.Text = split[2]
				tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tag.Parent = billboard
			end
		else
			WaypointFolder:ClearAllChildren()
		end
	end,
	Tooltip = 'Mark certain spots with a visual indicator'
})
FontOption = Waypoints:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
})
List = Waypoints:CreateTextList({
	Name = 'Points',
	Placeholder = 'x, y, z/name',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end
})
Waypoints:CreateButton({
	Name = 'Add current position',
	Function = function()
		if entitylib.isAlive then
			local pos = entitylib.character.RootPart.Position // 1
			List:ChangeValue(pos.X..','..pos.Y..','..pos.Z..'/Waypoint '..(#List.List + 1))
		end
	end
})
Color = Waypoints:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		for _, v in WaypointFolder:GetChildren() do
			v.TextLabel.TextColor3 = Color3.fromHSV(hue, sat, val)
		end
	end
})
Scale = Waypoints:CreateSlider({
	Name = 'Scale',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10
})
Background = Waypoints:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if Waypoints.Enabled then
			Waypoints:Toggle()
			Waypoints:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10
})

local AnimationPlayer
local IDBox
local Priority
local Speed
local anim, animobject

local function playAnimation(char)
	local animcheck = anim
	if animcheck then
		anim = nil
		animcheck:Stop()
	end

	local suc, res = pcall(function()
		anim = char.Humanoid.Animator:LoadAnimation(animobject)
	end)

	if suc then
		local currentanim = anim
		anim.Priority = Enum.AnimationPriority[Priority.Value]
		anim:Play()
		anim:AdjustSpeed(Speed.Value)
		AnimationPlayer:Clean(anim.Stopped:Connect(function()
			if currentanim == anim then
				anim:Play()
			end
		end))
	else
		notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
	end
end

AnimationPlayer = vape.Categories.Utility:CreateModule({
	Name = 'AnimationPlayer',
	Function = function(callback)
		if callback then
			animobject = Instance.new('Animation')
			local suc, id = pcall(function()
				return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
			end)
			animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)

			if entitylib.isAlive then
				playAnimation(entitylib.character)
			end
			AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
			AnimationPlayer:Clean(animobject)
		else
			if anim then
				anim:Stop()
			end
		end
	end,
	Tooltip = 'Plays a specific animation of your choosing at a certain speed'
})
IDBox = AnimationPlayer:CreateTextBox({
	Name = 'Animation',
	Placeholder = 'anim (num only)',
	Function = function(enter)
		if enter and AnimationPlayer.Enabled then
			AnimationPlayer:Toggle()
			AnimationPlayer:Toggle()
		end
	end
})
local prio = {'Action4'}
for _, v in Enum.AnimationPriority:GetEnumItems() do
	if v.Name ~= 'Action4' then
		table.insert(prio, v.Name)
	end
end
Priority = AnimationPlayer:CreateDropdown({
	Name = 'Priority',
	List = prio,
	Function = function(val)
		if anim then
			anim.Priority = Enum.AnimationPriority[val]
		end
	end
})
Speed = AnimationPlayer:CreateSlider({
	Name = 'Speed',
	Function = function(val)
		if anim then
			anim:AdjustSpeed(val)
		end
	end,
	Min = 0.1,
	Max = 2,
	Decimal = 10
})
local AntiRagdoll

AntiRagdoll = vape.Categories.Utility:CreateModule({
	Name = 'AntiRagdoll',
	Function = function(callback)
		if entitylib.isAlive then
			entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
		end

		if callback then
			AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			end))
		end
	end,
	Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
})
local AutoRejoin
local Sort

AutoRejoin = vape.Categories.Utility:CreateModule({
	Name = 'AutoRejoin',
	Function = function(callback)
		if callback then
			local check
			AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
				if (not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
					check = true
					serverHop(nil, Sort.Value)
				end
			end))
		end
	end,
	Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked'
})
Sort = AutoRejoin:CreateDropdown({
	Name = 'Sort',
	List = {'Descending', 'Ascending'},
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
})
local Blink
local Type
local AutoSend
local AutoSendLength
local oldphys, oldsend

Blink = vape.Categories.Utility:CreateModule({
	Name = 'Blink',
	Function = function(callback)
		if callback then
			local teleported
			Blink:Clean(lplr.OnTeleport:Connect(function()
				setfflag('PhysicsSenderMaxBandwidthBps', '38760')
				setfflag('DataSenderRate', '60')
				teleported = true
			end))

			repeat
				local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
				if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
					physicsrate, senderrate = '38760', '60'
				end

				if physicsrate ~= oldphys or senderrate ~= oldsend then
					setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
					setfflag('DataSenderRate', senderrate)
					oldphys, oldsend = physicsrate, senderrate
				end

				task.wait(0.03)
			until (not Blink.Enabled and not teleported)
		else
			if setfflag then
				setfflag('PhysicsSenderMaxBandwidthBps', '38760')
				setfflag('DataSenderRate', '60')
			end
			oldphys, oldsend = nil, nil
		end
	end,
	Tooltip = 'Chokes packets until disabled.'
})
Type = Blink:CreateDropdown({
	Name = 'Type',
	List = {'Movement Only', 'All'},
	Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement'
})
AutoSend = Blink:CreateToggle({
	Name = 'Auto send',
	Function = function(callback)
		AutoSendLength.Object.Visible = callback
	end,
	Tooltip = 'Automatically send packets in intervals'
})
AutoSendLength = Blink:CreateSlider({
	Name = 'Send threshold',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
local ChatSpammer
local Lines
local Mode
local Delay
local Hide
local oldchat

ChatSpammer = vape.Categories.Utility:CreateModule({
	Name = 'ChatSpammer',
	Function = function(callback)
		if callback then
			if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
					ChatSpammer:Clean(coreGui.ExperienceChat:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(msg)
						if msg.Name:sub(1, 2) == '0-' and msg.ContentText == 'You must wait before sending another message.' then
							msg.Visible = false
						end
					end))
				end
			elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
				if Hide.Enabled then
					oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
						if data.Message:find('ChatFloodDetector') then return end
						return oldchat(data, ...)
					end)
				end
			else
				notif('ChatSpammer', 'unsupported chat', 5, 'warning')
				ChatSpammer:Toggle()
				return
			end
			
			local ind = 1
			repeat
				local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top')
				if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
					message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
					ind = (ind % #Lines.ListEnabled) + 1
				end

				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
				end

				task.wait(Delay.Value)
			until not ChatSpammer.Enabled
		else
			if oldchat then
				hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
			end
		end
	end,
	Tooltip = 'Automatically types in chat'
})
Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
Mode = ChatSpammer:CreateDropdown({
	Name = 'Mode',
	List = {'Random', 'Order'}
})
Delay = ChatSpammer:CreateSlider({
	Name = 'Delay',
	Min = 0.1,
	Max = 10,
	Default = 1,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
Hide = ChatSpammer:CreateToggle({
	Name = 'Hide Flood Message',
	Default = true,
	Function = function()
		if ChatSpammer.Enabled then
			ChatSpammer:Toggle()
			ChatSpammer:Toggle()
		end
	end
})
local Disabler

local function characterAdded(char)
	for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
		hookfunction(v.Function, function() end)
	end

	for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
		hookfunction(v.Function, function() end)
	end
end

Disabler = vape.Categories.Utility:CreateModule({
	Name = 'Disabler',
	Function = function(callback)
		if callback then
			Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
			if entitylib.isAlive then
				characterAdded(entitylib.character)
			end
		end
	end,
	Tooltip = 'Disables GetPropertyChangedSignal detections for movement'
})
vape.Categories.Utility:CreateModule({
	Name = 'Panic',
	Function = function(callback)
		if callback then
			for _, v in vape.Modules do
				if v.Enabled then
					v:Toggle()
				end
			end
		end
	end,
	Tooltip = 'Disables all currently enabled modules'
})
local Rejoin

Rejoin = vape.Categories.Utility:CreateModule({
	Name = 'Rejoin',
	Function = function(callback)
		if callback then
			notif('Rejoin', 'Rejoining...', 5)
			Rejoin:Toggle()

			if playersService.NumPlayers > 1 then
				teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
			else
				teleportService:Teleport(game.PlaceId)
			end
		end
	end,
	Tooltip = 'Rejoins the server'
})
local ServerHop
local Sort

ServerHop = vape.Categories.Utility:CreateModule({
	Name = 'ServerHop',
	Function = function(callback)
		if callback then
			ServerHop:Toggle()
			serverHop(nil, Sort.Value)
		end
	end,
	Tooltip = 'Teleports into a unique server'
})
Sort = ServerHop:CreateDropdown({
	Name = 'Sort',
	List = {'Descending', 'Ascending'},
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
})
ServerHop:CreateButton({
	Name = 'Rejoin Previous Server',
	Function = function()
		notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
		if shared.vapeserverhopprevious then
			teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
		end
	end
})
local StaffDetector
local Mode
local Profile
local Users
local Group
local Role

local function getRole(plr, id)
	local suc, res
	for _ = 1, 3 do
		suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if suc then break end
	end
	return suc and res or 0
end

local function getLowestStaffRole(roles)
	local highest = math.huge
	for _, v in roles do
		local low = v.Name:lower()
		if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
			highest = v.Rank
		end
	end
	return highest
end

local function playerAdded(plr)
	if not vape.Loaded then
		repeat task.wait() until vape.Loaded
	end

	local user = table.find(Users.ListEnabled, tostring(plr.UserId))
	if user or getRole(plr, tonumber(Group.Value) or 0) >= (tonumber(Role.Value) or 1) then
		notif('StaffDetector', 'Staff Detected ('..(user and 'blacklisted_user' or 'staff_role')..'): '..plr.Name, 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}

		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected\n'..plr.Name,
				Duration = 60,
			})
		elseif Mode.Value == 'ServerHop' then
			serverHop()
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape.Profile = Profile.Value
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			vape.Save = function() end
			for _, v in vape.Modules do
				if v.Enabled then
					v:Toggle()
				end
			end
		end
	end
end

StaffDetector = vape.Categories.Utility:CreateModule({
	Name = 'StaffDetector',
	Function = function(callback)
		if callback then
			if Group.Value == '' or Role.Value == '' then
				local placeinfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
				if Group.Value == '' then
					placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
					if placeinfo.Creator.CreatorType ~= 'Group' then
						local desc = placeinfo.Description:split('\n')
						for _, str in desc do
							local _, begin = str:find('roblox.com/groups/')
							if begin then
								local endof = str:find('/', begin + 1)
								placeinfo = {Creator = {
									CreatorType = 'Group',
									CreatorTargetId = str:sub(begin + 1, endof - 1)
								}}
							end
						end
					end

					if placeinfo.Creator.CreatorType ~= 'Group' then
						notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
						return
					end
				end

				local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
				Group:SetValue(placeinfo.Creator.CreatorTargetId)
				Role:SetValue(getLowestStaffRole(groupinfo.Roles))
			end

			if Group.Value == '' or Role.Value == '' then
				return
			end

			StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
			for _, v in playersService:GetPlayers() do
				task.spawn(playerAdded, v)
			end
		end
	end,
	Tooltip = 'Detects people with a staff rank ingame'
})
Mode = StaffDetector:CreateDropdown({
	Name = 'Mode',
	List = {'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify'},
	Function = function(val)
		if Profile.Object then
			Profile.Object.Visible = val == 'Profile'
		end
	end
})
Profile = StaffDetector:CreateTextBox({
	Name = 'Profile',
	Default = 'default',
	Darker = true,
	Visible = false
})
Users = StaffDetector:CreateTextList({
	Name = 'Users',
	Placeholder = 'player (userid)'
})
Group = StaffDetector:CreateTextBox({
	Name = 'Group',
	Placeholder = 'Group Id'
})
Role = StaffDetector:CreateTextBox({
	Name = 'Role',
	Placeholder = 'Role Rank'
})
local StateSpoofer
local State
local hook

StateSpoofer = vape.Categories.Utility:CreateModule({
	Name = 'StateSpoofer',
	Function = function(callback)
		if callback then
			if not rakNetCheck('StateSpoofer') then
				StateSpoofer:Toggle()
				return
			end

			hook = function(packet)
				if packet.AsArray[1] == 0x1b then
					local data = packet.AsBuffer
					buffer.writeu8(data, 25, Enum.HumanoidStateType[State.Value].Value + 32)
					packet:SetData(data)
				end
			end

			raknet.add_send_hook(hook)
		elseif hook then
			raknet.remove_send_hook(hook)
			hook = nil
		end
	end,
	Tooltip = 'Spoof humanoid states on the server.'
})
local states = {}
for _, v in Enum.HumanoidStateType:GetEnumItems() do
	if v.Name ~= 'None' then
		table.insert(states, v.Name)
	end
end
State = StateSpoofer:CreateDropdown({
	Name = 'Humanoid State',
	List = states
})
local connections = {}

vape.Categories.World:CreateModule({
	Name = 'Anti-AFK',
	Function = function(callback)
		if callback then
			for _, v in getconnections(lplr.Idled) do
				table.insert(connections, v)
				v:Disable()
			end
		else
			for _, v in connections do
				v:Enable()
			end
			table.clear(connections)
		end
	end,
	Tooltip = 'Lets you stay ingame without getting kicked'
})
local Freecam
local Value
local randomkey, module, old = httpService:GenerateGUID(false)

Freecam = vape.Categories.World:CreateModule({
	Name = 'Freecam',
	Function = function(callback)
		if callback then
			repeat
				task.wait(0.1)
				for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
					if v.Function then
						module = debug.getupvalue(v.Function, 1)
					end
				end
			until module or not Freecam.Enabled

			if module and module.activeCameraController and Freecam.Enabled then
				old = module.activeCameraController.GetSubjectPosition
				local camPos = old(module.activeCameraController) or Vector3.zero
				module.activeCameraController.GetSubjectPosition = function()
					return camPos
				end

				Freecam:Clean(runService.PreSimulation:Connect(function(dt)
					if not inputService:GetFocusedTextBox() then
						local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
						local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
						local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
						dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
						camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
					end
				end))

				contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
					return Enum.ContextActionResult.Sink
				end, false, Enum.ContextActionPriority.High.Value,
					Enum.KeyCode.W,
					Enum.KeyCode.A,
					Enum.KeyCode.S,
					Enum.KeyCode.D,
					Enum.KeyCode.E,
					Enum.KeyCode.Q,
					Enum.KeyCode.Up,
					Enum.KeyCode.Down
				)
			end
		else
			pcall(function()
				contextService:UnbindAction('FreecamKeyboard'..randomkey)
			end)
			if module and old then
				module.activeCameraController.GetSubjectPosition = old
				module = nil
				old = nil
			end
		end
	end,
	Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
})
Value = Freecam:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
local Gravity
local Mode
local Value
local changed, old = false

Gravity = vape.Categories.World:CreateModule({
	Name = 'Gravity',
	Function = function(callback)
		if callback then
			if Mode.Value == 'Workspace' then
				old = workspace.Gravity
				workspace.Gravity = Value.Value
				Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
					if changed then return end
					changed = true
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					changed = false
				end))
			else
				Gravity:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
						local root = entitylib.character.RootPart
						if Mode.Value == 'Impulse' then
							root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
						else
							root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
						end
					end
				end))
			end
		else
			if old then
				workspace.Gravity = old
				old = nil
			end
		end
	end,
	Tooltip = 'Changes the rate you fall'
})
Mode = Gravity:CreateDropdown({
	Name = 'Mode',
	List = {'Workspace', 'Velocity', 'Impulse'},
	Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
})
Value = Gravity:CreateSlider({
	Name = 'Gravity',
	Min = 0,
	Max = 192,
	Function = function(val)
		if Gravity.Enabled and Mode.Value == 'Workspace' then
			changed = true
			workspace.Gravity = val
			changed = false
		end
	end,
	Default = 192
})
local Parkour

Parkour = vape.Categories.World:CreateModule({
	Name = 'Parkour',
	Function = function(callback)
		if callback then 
			local oldfloor
			Parkour:Clean(runService.RenderStepped:Connect(function()
				if entitylib.isAlive then 
					local material = entitylib.character.Humanoid.FloorMaterial
					if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then 
						entitylib.character.Humanoid.Jump = true
					end
					oldfloor = material
				end
			end))
		end
	end,
	Tooltip = 'Automatically jumps after reaching the edge'
})
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local module, old

vape.Categories.World:CreateModule({
	Name = 'SafeWalk',
	Function = function(callback)
		if callback then
			if not module then
				local suc = pcall(function() 
					module = require(lplr.PlayerScripts.PlayerModule).controls 
				end)
				if not suc then module = {} end
			end
			
			old = module.moveFunction
			module.moveFunction = function(self, vec, face)
				if entitylib.isAlive then
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					local root = entitylib.character.RootPart
					local movedir = root.Position + vec
					local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
					if not ray then
						local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
						if check then
							vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
						end
					end
				end

				return old(self, vec, face)
			end
		else
			if module and old then
				module.moveFunction = old
			end
		end
	end,
	Tooltip = 'Prevents you from walking off the edge of parts'
})
local Xray
local List
local modified = {}

local function modifyPart(v)
	if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
		modified[v] = true
		v.LocalTransparencyModifier = 0.5
	end
end

Xray = vape.Categories.World:CreateModule({
	Name = 'Xray',
	Function = function(callback)
		if callback then
			Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
			for _, v in workspace:GetDescendants() do
				modifyPart(v)
			end
		else
			for i in modified do
				i.LocalTransparencyModifier = 0
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Renders whitelisted parts through walls.'
})
List = Xray:CreateTextList({
	Name = 'Part',
	Function = function()
		if Xray.Enabled then
			Xray:Toggle()
			Xray:Toggle()
		end
	end
})