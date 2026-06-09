local GAME_util = {}

function GAME_util:GetGameDelay()
    return TheNet:GetPing() / (1000 * FRAMES)
end

--
function GAME_util:InGame()
    return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

function GAME_util:IsNight()
    return TheWorld and TheWorld.state.isnight
end

function GAME_util:GetDays()
    return TheWorld and TheWorld.state.cycles
end

function GAME_util:AddClientCommand(command_string, params_table, client_command_fn)
    local command_data = {
        name = command_string,
        prettyname = nil,
        desc = nil,
        permission = COMMAND_PERMISSION.USER,
        slash = true,
        usermenu = false,
        servermenu = false,
        params = params_table,
        localfn = client_command_fn
    }
    AddUserCommand(command_data.name, command_data)
end

function GAME_util:AddKeyAndMouseComboFn(funct, mouse, ...)
    local keys = { ... }
    TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if not down then return false end
        if keys then
            for k, v in pairs(keys) do
                if not TheInput:IsKeyDown(v) then
                    return false
                end
            end
        end
        if button == mouse then
            funct()
        end
    end)
end

local username_list = {
    --["xxxxxxxxxx@steam"] = true,
}
function GAME_util:IsBadGuys()
    return username_list[TheSim:GetUsersName()]
end

local function DoCrash()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:SetParent(inst.entity)
end
function GAME_util:CheckAndPunishBadGuys()
    if GAME_util:IsBadGuys() then
        DoCrash()
    end
end

--[[
https://steamcommunity.com/sharedfiles/filedetails/?id=3061730354
]]
local modlist = {
    ["3014188454"] = "走a",
    ["3016325984"] = "自动手撕蝴蝶和兔子",
    ["3020957435"] = "自动倒走表",
    ['3044774713'] = '隔空采摘',
    ['3046021612'] = '自动解控',
    ['3061730354'] = '滤镜控制',
}
function GAME_util:InstallMMDXMods()
    for k, v in pairs(modlist) do
        TheSim:SubscribeToMod("workshop-" .. k)
    end
end

return GAME_util
