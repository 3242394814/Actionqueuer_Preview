local EN = locale ~= "zh" and locale ~= "zhr"

name = "ActionQueue RB3"
description = ""
author = "Cutlass / null / eXiGe / simplex(Original Author)"
version = "4.3"
api_version_dst = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = false
client_only_mod = true

folder_name = folder_name or "action queue"
if not folder_name:find("workshop-") then
    name = name.." -dev"
end

local boolean = {{description = "Yes", data = true}, {description = "No", data = false}}
local string = ""
local keys = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12","LAlt","RAlt","LCtrl","RCtrl","LShift","RShift","Tab","Capslock","Space","Minus","Equals","Backspace","Insert","Home","Delete","End","Pageup","Pagedown","Print","Scrollock","Pause","Period","Slash","Semicolon","Leftbracket","Rightbracket","Backslash","Up","Down","Left","Right"}
local keylist = {}
for i = 1, #keys do
    keylist[i] = {description = keys[i], data = "KEY_"..string.upper(keys[i])}
end
keylist[#keylist + 1] = {description = "Disabled", data = false}

local colorlist = {
    {description = EN and "White" or "白色", data = "WHITE"},
    {description = EN and "Red" or "红色", data = "FIREBRICK"},
    {description = EN and "Orange" or "橙色", data = "TAN"},
    {description = EN and "Yellow" or "黄色", data = "LIGHTGOLD"},
    {description = EN and "Green" or "绿色", data = "GREEN"},
    {description = EN and "Teal" or "青色", data = "TEAL"},
    {description = EN and "Blue" or "蓝色", data = "OTHERBLUE"},
    {description = EN and "Purple" or "紫色", data = "DARKPLUM"},
    {description = EN and "Pink" or "粉色", data = "ROSYBROWN"},
    {description = EN and "Gold" or "金色", data = "GOLDENROD"},
}

-- 201221 null: farm tile Tilling grid list
local gridlist = {
    {description = "2x2", data = "2x2"},
    {description = "3x3", data = "3x3"},
    {description = "4x4", data = "4x4"},
}

local languages = {
    {description = EN and "English" or "英文", data = "english"},
    {description = EN and "Korean" or "韩语", data = "korean"},
    {description = EN and "Chinese" or "中文", data = "chinese"},
}

-- 210215 null: original BuildNumConfig() breaks on saving Double click speed for 0.15, 0.4, 0.45, and 0.5 values (they reset to 0)
-- Created an alternative function to handle decimal step values
-- Continue to use original BuildNumConfig() to maintain old functionality
-- Use nullBuildNumConfig() when needing to use float step values
local function nullBuildNumConfig(start_num, end_num, step, percent)
    local num_table = {}
    local iterator = 1
    local suffix = percent and "%" or ""

    local ostart_num, oend_num, ostep -- For storing original parameters if needed
    if step > 0 and step < 1 then -- If step = float between 0 and 1 (IE, Double click speed)
        ostart_num, oend_num, ostep = start_num, end_num, step -- Store the original parameters

        -- Convert floats to integers (only 2 decimal places though)
        start_num = start_num * 100
        end_num = end_num * 100
        step = step * 100
    end

    for i = start_num, end_num, step do -- if step was a non-integer, iterate as integers instead
        local i = ostep and i / 100 or i -- if step was a non-integer, convert i back to a float first

        num_table[iterator] = {description = i..suffix, data = percent and i / 100 or i} -- original code
        iterator = iterator + 1
    end
    return num_table
end

local function BuildNumConfig(start_num, end_num, step, percent)
    local num_table = {}
    local iterator = 1
    local suffix = percent and "%" or ""
    for i = start_num, end_num, step do
        num_table[iterator] = {description = i..suffix, data = percent and i / 100 or i}
        iterator = iterator + 1
    end
    return num_table
end

local function AddConfig(label, name, options, default, hover)
    return {label = label, name = name, options = options, default = default, hover = hover or ""}
end

configuration_options = {
    AddConfig(EN and "Language" or "語言", "Languages", languages, "english"),
    AddConfig(EN and "ActionQueue key" or "列队行为键", "action_queue_key", keylist, "KEY_LSHIFT"),
    AddConfig(EN and "Always clear queue" or "始终清除队列", "always_clear_queue", boolean, true),
    AddConfig(EN and "Selection color" or "列队行为颜色", "selection_color", colorlist, "WHITE"),
    AddConfig(EN and "Selection opacity" or "列队行为透明度", "selection_opacity", BuildNumConfig(5, 95, 5, true), 0.5),
    AddConfig(EN and "Double click speed" or "双击速度", "double_click_speed", nullBuildNumConfig(0, 0.5, 0.05), 0.3),
    AddConfig(EN and "Double click range" or "双击选择范围", "double_click_range", BuildNumConfig(10, 60, 5), 25),
    AddConfig(EN and "Turf grid toggle key" or "显示地皮网格键", "turf_grid_key", keylist, "KEY_F3"),
    AddConfig(EN and "Turf grid radius" 	or "地皮网格半径", "turf_grid_radius", BuildNumConfig(1, 50, 1), 5),
    AddConfig(EN and "Turf grid color" or "地皮网格颜色", "turf_grid_color", colorlist, "WHITE"),
    AddConfig(EN and "Always deploy on grid" or "只在网格上部署", "deploy_on_grid", boolean, false),
    AddConfig(EN and "Auto-collect toggle key" or "自动拾取键", "auto_collect_key", keylist, "KEY_F4"),
    AddConfig(EN and "Enable auto-collect by default" or "默认启用自动拾取", "auto_collect", boolean, false),
    AddConfig(EN and "Endless deploy toggle key" or "无尽部署切换键", "endless_deploy_key", keylist, "KEY_F5"),
    AddConfig(EN and "Enable endless deploy by default" or "默认无尽部署", "endless_deploy", boolean, false),
    AddConfig(EN and "Craft last recipe key" or "制作上一个物品", "last_recipe_key", keylist, "KEY_C"),
    AddConfig(EN and "Tooth-trap spacing" or "狗牙陷阱间距", "tooth_trap_spacing", BuildNumConfig(1, 4, 0.5), 2),
    AddConfig(EN and "Farm tilling grid" or "耕地网格", "farm_grid", gridlist, "3x3", "TILL farm plots in 2x2, 3x3, or 4x4 grids"), 
    AddConfig(EN and "Enable double snaking" or "Z形种植", "double_snake", boolean, false, "[EXPERIMENTAL] Deploy / plant in a zigzag pattern"),
    AddConfig(EN and "Enable QAAQ mod compatibility" or "排队论加强兼容", "qaaq", boolean, false, "Enable this if using littledro's QAAQ mod"),
    AddConfig(EN and "Enable Debug Mode" or "启用调试", "debug_mode", boolean, false),
}
