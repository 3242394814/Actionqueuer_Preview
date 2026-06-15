--../mods/mymods/scripts/utils/RW_util.lua	mymods	scripts/utils/RW_util.lua
--modimport("m_utils/m_utils") --modmain里面需要加上这个
--导入所有的utils到mod环境的变量里面  local result = kleiloadlua(env.MODROOT..modulename)
local require = function(modulename)
	local result = kleiloadlua(env.MODROOT .. modulename .. ".lua")
	if result then
		setfenv(result, env.env)
		return result()
	end
end
RW_util = require("m_utils/RW_util")
ENT_util = require("m_utils/ENT_util")
MOD_util = require("m_utils/MOD_util")
GAME_util = require("m_utils/GAME_util")
INV_util = require("m_utils/INV_util")
PLAYER_util = require("m_utils/PLAYER_util")
POS_util = require("m_utils/POS_util")
KEY_util = require("m_utils/KEY_util")
EQUIP_util = require("m_utils/EQUIP_util")
HUD_util = require("m_utils/HUD_util")
MAP_util = require("m_utils/MAP_util")
HACKER_util = require("m_utils/HACKER_util")
ACTIONS_util = require("m_utils/ACTIONS_util")
if MOD_util:Ismmdx() then
	GLOBAL.RW_util = RW_util
	GLOBAL.ENT_util = ENT_util
	GLOBAL.MOD_util = MOD_util
	GLOBAL.GAME_util = GAME_util
	GLOBAL.INV_util = INV_util
	GLOBAL.PLAYER_util = PLAYER_util
	GLOBAL.POS_util = POS_util
	GLOBAL.KEY_util = KEY_util
	GLOBAL.EQUIP_util = EQUIP_util
	GLOBAL.HUD_util = HUD_util
	GLOBAL.MAP_util = MAP_util
	GLOBAL.HACKER_util = HACKER_util
	GLOBAL.ACTIONS_util = ACTIONS_util
	do
		GLOBAL.PRINT = print
	end
end
--调试参数
DelayFrame = 0
TheInput:AddKeyDownHandler(KEY_LEFT, function()
	DelayFrame = DelayFrame - 1
	print('调试参数:', DelayFrame)
end)
TheInput:AddKeyDownHandler(KEY_RIGHT, function()
	DelayFrame = DelayFrame + 1
	print('调试参数:', DelayFrame)
end)

--强力打印
function GLOBAL.m_print(a)
	print('----------------------m_print start-------------------------------')
	if type(a) == "table" then
		for k, v in pairs(a or {}) do
			print(k, '=', v, '\ttype(key):', type(k), 'type(value):',
				type(v))
		end
	elseif type(a) == "userdata" then
		for k, v in pairs(getmetatable(a).__index) do
			print(k, '=', v, '\ttype(key):', type(k), 'type(value):', type(v))
		end
	else
		print(type(a) .. ':', a)
	end
	print('----------------------m_print stop-------------------------------')
end

--强力选择
function GLOBAL.m_select(a) --m_print(TheInput:GetWorldEntityUnderMouse())
	local mouse = ENT_util:GetItemUnderMouse()
	if mouse then
		return mouse
	elseif ThePlayer and not a then
		ThePlayer:DoTaskInTime(0, function() m_print(ENT_util:GetItemUnderMouse()) end)
	end
end

--打印表 RW_util:SaveData(print_table(a), "mods/tempt.lua")
local str = ""
function GLOBAL.print_table(tab, noprint)
	local finalstr
	if type(tab) == "table" then
		str = str .. "{"
		for k, v in pairs(tab) do
			if type(k) == "number" then
				--str = str .. "[" .. k .. "]" .. "="
			else
				str = str .. "['" .. k .. "']" .. "="
			end

			if type(v) == "table" then
				GLOBAL.print_table(v, true)
			elseif type(v) == "number" then
				str = str .. tostring(v)
			elseif type(v) == "boolean" then
				str = str .. tostring(v)
			else
				str = str .. "[[" .. tostring(v) .. "]]"
			end
			str = str .. ","
		end
		str = str .. "}"
	end
	if not noprint then
		--print(str)
		finalstr = str
		str = ""
		return finalstr
	end
end

GLOBAL.SaveDataToFile = function(data)
	if type(data) ~= "table" then
		RW_util:SaveData(data, "test")
	else
		RW_util:SaveData(print_table(data), "test")
	end
end
if MOD_util then
	--https://steamcommunity.com/sharedfiles/filedetails/?id=3210776581
	MOD_util.fixrpc = function()
		if rawget(GLOBAL, "mmdx_hasfixrpc") then return end
		rawset(GLOBAL, "mmdx_hasfixrpc", true)
		--主机也能发rpc实现功能
		local oldsend = GLOBAL.NetworkProxy.SendRPCToServer
		function GLOBAL.NetworkProxy.SendRPCToServer(self, code, actionid, x, z, ...)
			if TheWorld and TheWorld.ismastersim then
				RPC_HANDLERS = RPC_HANDLERS or MOD_util:GetUpvalue_deekseek(HandleRPC, 'RPC_HANDLERS')
				if RPC_HANDLERS[code] and ThePlayer then
					local iscastaoe = ACTIONS.CASTAOE.code == actionid
					local playercontroller = ThePlayer.components.playercontroller
					local oldreticule = playercontroller.reticule
					local oldhand = playercontroller.handler
					if iscastaoe then
						playercontroller.reticule = {
							inst = { components = { aoetargeting = {} } },
							DestroyReticule = function()
							end
						}
					end
					playercontroller.handler = nil
					RPC_HANDLERS[code](ThePlayer, actionid, x, z, ...)
					playercontroller.handler = oldhand
					if iscastaoe then
						playercontroller.reticule = oldreticule
					end
					return
				end
			end
			return oldsend(self, code, actionid, x, z, ...)
		end

		MOD_util.hasfixrpc = true
	end
	MOD_util.fixrpc()
end

--越权
if GLOBAL.rawget(GLOBAL, "MOD_SRC_LOCK") == nil then
	local null = function()

	end
	GLOBAL.MOD_SRC_LOCK = false --锁住原版注册
	local _RegisterComponentActions = GLOBAL.EntityScript.RegisterComponentActions
	GLOBAL.EntityScript.RegisterComponentActions = function(...)
		return GLOBAL.MOD_SRC_LOCK or _RegisterComponentActions(...)
	end
	local oldSpawnPrefab = GLOBAL.SpawnPrefab
	function GLOBAL.SpawnPrefab(...)
		if GLOBAL.MOD_SRC_LOCK then
			local ent = oldSpawnPrefab(...)
			if ent then
				ent.UnregisterComponentActions = null
			end
			return ent
		end
		return oldSpawnPrefab(...)
	end
end

--给玩家加api 好处是不用官方的any接口
local allplayerfn = {}
local allplayerfn_once = {}
function MOD_util:AddPlayerPostInit(fn, onlyonce)
	if onlyonce then
		allplayerfn_once[fn] = true
	else
		allplayerfn[fn] = true
	end
end

local a = true
AddComponentPostInit("playercontroller", function(self, player)
	if a then
		a = false
		for fn, v in pairs(allplayerfn_once) do
			fn(self, player)
		end
	end
	for fn, v in pairs(allplayerfn) do
		fn(self, player)
	end
end)
--如果打印的长度太长就不要在日志显示
local maxchar = 4000
local oldUpdateConsoleOutput = GLOBAL.FrontEnd.UpdateConsoleOutput
function GLOBAL.FrontEnd:UpdateConsoleOutput(...)
	local consolestr = table.concat(GLOBAL.GetConsoleOutputList(), "\n")
	consolestr = consolestr .. "\n(Press CTRL+L to close this log)"
	if #consolestr > maxchar then
		consolestr = string.sub(consolestr, -maxchar)
		return self.consoletext:SetString(consolestr)
	end
	return oldUpdateConsoleOutput(self, ...)
end
