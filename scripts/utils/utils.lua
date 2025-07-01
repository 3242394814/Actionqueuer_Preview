--../mods/mymods/scripts/utils/RW_util.lua	mymods	scripts/utils/RW_util.lua
--modimport("scripts/utils/utils") --modmain里面需要加上这个
--导入所有的utils到mod环境的变量里面  local result = kleiloadlua(env.MODROOT..modulename)
local require = function(modulename)
    local result = kleiloadlua(env.MODROOT .. "scripts/" .. modulename .. ".lua")
    setfenv(result, env.env)

    return result()
end
RW_util = require("utils/RW_util")
ENT_util = require("utils/ENT_util")
MOD_util = require("utils/MOD_util")
GAME_util = require("utils/GAME_util")
INV_util = require("utils/INV_util")
PLAYER_util = require("utils/PLAYER_util")
POS_util = require("utils/POS_util")
KEY_util = require("utils/KEY_util")
EQUIP_util = require("utils/EQUIP_util")
HUD_util = require("utils/HUD_util")
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
            print(k, '=', v, '                     type(key):', type(k), 'type(value):',
                type(v))
        end
    elseif type(a) == "userdata" then
        for k, v in pairs(getmetatable(a).__index) do
            print(k, '=', v, '                     type(key):', type(k), 'type(value):', type(v))
        end
    else
        print('string:', a)
    end
    print('----------------------m_print stop-------------------------------')
end

--深度打印
function GLOBAL.DeepPrintTable(t, depth)
    if depth == nil then
        print('----------------------DeepPrint start-------------------------------')
        depth = 0
    end

    for k, v in pairs(t) do
        if type(v) == "userdata" and depth < 3 then
            print(string.rep("  ", depth) .. tostring(k) .. "={")
            DeepPrintTable(getmetatable(v).__index, depth + 1)
            print(string.rep(" ", 2 * depth + string.len(tostring(k)) + 1) .. "}")
        elseif type(v) == "table" and depth < 3 then --string.len
            if next(v) then
                print(string.rep("  ", depth) .. tostring(k) .. "={")
                DeepPrintTable(v, depth + 1)
                print(string.rep(" ", 2 * depth + string.len(tostring(k)) + 1) ..
                    "}")
            else
                print(string.rep("  ", depth) .. tostring(k) .. "={}")
            end
        else
            local message = tostring(k) .. '=' .. tostring(v)
            print(string.rep("  ", depth) .. message)
        end
    end
end

--强力选择
function GLOBAL.m_select() --m_print(TheInput:GetWorldEntityUnderMouse())
    local mouse = ENT_util:GetItemUnderMouse()
    if mouse then
        return mouse
    elseif ThePlayer then
        ThePlayer:DoTaskInTime(0, function() m_print(ENT_util:GetItemUnderMouse()) end)
    end
end

--主机也能发rpc实现功能
local oldsend = GLOBAL.SendRPCToServer
function GLOBAL.SendRPCToServer(code, actionid, x, z, ...)
    if TheWorld and TheWorld.ismastersim then
        RPC_HANDLERS = RPC_HANDLERS or MOD_util:GetUpvalue(HandleRPC, 'RPC_HANDLERS')
        if RPC_HANDLERS[code] and ThePlayer then
            local iscastaoe = ACTIONS.CASTAOE.code == actionid
            local playercontroller = ThePlayer.components.playercontroller
            local oldreticule = playercontroller.reticule
            local oldhand = playercontroller.handler
            if iscastaoe then
                print('iscastaoe')
                playercontroller.reticule = { inst = { components = { aoetargeting = {} } } }
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
    return oldsend(code, actionid, x, z, ...)
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

AddPrefabPostInit("world", function(world)
    local a = true
    world:ListenForEvent("playeractivated", function(self, data)
        if a then
            a = false
            for fn, v in pairs(allplayerfn_once) do
                fn(self, data)
            end
        end
        for fn, v in pairs(allplayerfn) do
            fn(self, data)
        end
    end)
end)
