name = "ActionQueue RB3汉化版"
description = ""
author = "Cutlass / null / eXiGe / simplex(Original Author)"
version = "2.9"
api_version_dst = 10

description = '此模组汉化自Cutlass的ActionQueue RB3！请支持原作者！'

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
    {description = "白色",  data = "WHITE"},
    {description = "红色",    data = "FIREBRICK"},
    {description = "橙色", data = "TAN"},
    {description = "黄色", data = "LIGHTGOLD"},
    {description = "绿色",  data = "GREEN"},
    {description = "青色",   data = "TEAL"},
    {description = "蓝色" ,  data = "OTHERBLUE"},
    {description = "紫色", data = "DARKPLUM"},
    {description = "粉色" ,  data = "ROSYBROWN"},
    {description = "金色",   data = "GOLDENROD"},
}

-- 201221 null: farm tile Tilling grid list
local gridlist = {
    {description = "2x2", data = "2x2"},
    {description = "3x3", data = "3x3"},
    {description = "4x4", data = "4x4"},
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
    AddConfig("列队行为键", "action_queue_key", keylist, "KEY_LSHIFT"),
    AddConfig("始终清除队列", "always_clear_queue", boolean, true),
    AddConfig("列队行为颜色", "selection_color", colorlist, "WHITE"),
    AddConfig("列队行为透明度", "selection_opacity", BuildNumConfig(5, 95, 5, true), 0.5),
    AddConfig("双击速度", "double_click_speed", nullBuildNumConfig(0, 0.5, 0.05), 0.3), 
    -- AddConfig("Double click speed", "double_click_speed", BuildNumConfig(0, 0.5, 0.05), 0.3), -- original code
    AddConfig("双击选择范围", "double_click_range", BuildNumConfig(10, 60, 5), 25),
    AddConfig("显示地皮网格键", "turf_grid_key", keylist, "KEY_F3"),
    AddConfig("地皮网格半径", "turf_grid_radius", BuildNumConfig(1, 50, 1), 5),
    AddConfig("地皮网格颜色", "turf_grid_color", colorlist, "WHITE"),
    AddConfig("只在网格上部署", "deploy_on_grid", boolean, false),
    AddConfig("自动拾取键", "auto_collect_key", keylist, "KEY_F4","列队砍树挖矿或者捡东西后会自动拾取附近物品"),
    AddConfig("默认启用自动拾取", "auto_collect", boolean, false),
    AddConfig("无尽部署切换键", "endless_deploy_key", keylist, "KEY_F5","启动列队部署会让你不停地往下部署/种植(适合大面积种树)"),
    AddConfig("默认无尽部署", "endless_deploy", boolean, false,"开启此选项后会默认开启无尽部署"),
    AddConfig("制作上一个物品","last_recipe_key", keylist, "KEY_C"),
    AddConfig("狗牙陷阱间距", "tooth_trap_spacing", BuildNumConfig(1, 4, 0.5), 1),
    AddConfig("耕地网格", "farm_grid", gridlist, "3x3", "2×2、3×3或4×4的自动耕地"),  
    AddConfig("Z形种植", "double_snake", boolean, false, "[实验功能]以Z字形模式部署/种植"),
    AddConfig("排队论加强兼容", "qaaq", boolean, false, "如果使用了小小龙的排队论加强模组，请开启这个选项"),
    AddConfig("启用调试", "debug_mode", boolean, false),
}
