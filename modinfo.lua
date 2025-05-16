---@diagnostic disable: lowercase-global

local function zh_en(zh, en)  -- Other languages don't work
    local chinese_languages =
    {
        zh = "zh", -- Chinese for Steam
        zhr = "zh", -- Chinese for WeGame
        ch = "zh", -- Chinese mod
        chs = "zh", -- Chinese mod
        sc = "zh", -- simple Chinese
        zht = "zh", -- traditional Chinese for Steam
        tc = "zh", -- traditional Chinese
        cht = "zh", -- Chinese mod
    }

    if chinese_languages[locale] ~= nil then
        lang = chinese_languages[locale]
    else
        lang = en
    end

    return lang ~= "zh" and en or zh
end

name = zh_en("列队行为学 · 动作预览", "ActionQueue · Action Preview")

description = zh_en(
[[
为【ActionQueue RB3】添加动作预览（需同时开启原模组）

动作预览代码基于呼吸的【群鸟绘卷 · 江海󰀃】修改，感谢呼吸

支持种植植物预览、放置建筑预览、丢弃物品预览、挖地皮预览、耕地预览、浇水预览

兼容原版几何布局&耕地对齐模组
]],
[[
Adds action previews for [ActionQueue RB3] (original mod must be enabled)

Action preview code is based on 呼吸's [群鸟绘卷 · 江海󰀃] — thanks to 呼吸

Supports plant preview, building placement preview, item drop preview, turf digging preview, farm soil tilling preview, and watering preview

Compatible with original Geometric Placement & Snapping tills mods
]]
)

version = "0.1.1"
author = "冰冰羊"
api_version = 10
priority = -11

dst_compatible = true

all_clients_require_mod = false
client_only_mod = true
server_only_mod = false

icon_atlas = "images/modicon.xml"
icon = "modicon.tex"
configuration_options =
{
    {
        name = "preview_able",
        label = zh_en("预览功能", "Preview function"),
        hover = zh_en("是否开启预览功能？", "Do you want to enable preview?"),
        options = {
            {description = zh_en("开启", "Enable"), data = true},
            {description = zh_en("关闭", "Disable"), data = false},
        },
        default = true,
    },
    {
        name = "number",
        label = zh_en("预览数量", "Preview Amount"),
        hover = zh_en("太多会导致游戏掉帧", "Too many may cause frame drops"),
        options =
        {
            {description = "20", data = 20},
            {description = "25", data = 25},
            {description = "30", data = 30},
            {description = "35", data = 35},
            {description = "40", data = 40},
            {description = "50", data = 50},
            {description = "60", data = 60},
            {description = "70", data = 70},
            {description = "80", data = 80},
            {description = "90", data = 90},
            {description = "100", data = 100},
            {description = "120", data = 120},
            {description = "160", data = 160},
            {description = "200", data = 200},
            {description = "250", data = 250},
            {description = "300", data = 300},
            {description = "400", data = 400},
            {description = "500", data = 500},
            {description = "1000", data = 1000},
        },
        default = 80,
    },
    {
        name = "highlight",
        label = zh_en("预览亮度", "Preview Brightness"),
        hover = zh_en("感觉主要是影响在黑暗环境下的亮度...", "Seems to mainly affect brightness in dark environments..."),
        options = {
            {description = "10%", data = 0.1},
            {description = "20%", data = 0.2},
            {description = "30%", data = 0.3},
            {description = "40%", data = 0.4},
            {description = "50%", data = 0.5},
            {description = "60%", data = 0.6},
            {description = "70%", data = 0.7},
            {description = "80%", data = 0.8},
            {description = "90%", data = 0.9},
            {description = "100%", data = 1},
        },
        default = 0.3,
    },
    {
        name = "color",
        label = zh_en("预览颜色", "Preview Color"),
        hover = zh_en("给预览的物品染个色", "Tint the previewed items with a color"),
        options = { -- 和行为学的设置一致
            {description = zh_en("白色", "White"), data = "WHITE"},
            {description = zh_en("红色", "Red"), data = "FIREBRICK"},
            {description = zh_en("橙色", "Orange"), data = "TAN"},
            {description = zh_en("黄色", "Yellow"), data = "LIGHTGOLD"},
            {description = zh_en("绿色", "Green"), data = "GREEN"},
            {description = zh_en("青色", "Teal"), data = "TEAL"},
            {description = zh_en("蓝色", "Blue"), data = "OTHERBLUE"},
            {description = zh_en("紫色", "Purple"), data = "DARKPLUM"},
            {description = zh_en("粉色", "Pink"), data = "ROSYBROWN"},
            {description = zh_en("金色", "Gold"), data = "GOLDENROD"},
        },
        default = "GREEN",
    },
    {
        name = "dont_color",
        label = zh_en("禁用颜色", "Disable Color"),
        hover = zh_en("禁用预览颜色，预览物品将变得和真的一样", "Disable preview color; previewed items will look like the real ones"),
        options = {
            {description = zh_en("是", "Yes"), data = true},
            {description = zh_en("否", "No"), data = false},
        },
        default = false,
    },
    {
        name = "debug_mode",
        label = zh_en("调试模式", "Debug Mode"),
        hover = zh_en("开启后将在控制台打印各种调试信息", "Prints debug info to the console when enabled"),
        options = {
            {description = zh_en("是", "Yes"), data = true},
            {description = zh_en("否", "No"), data = false},
        },
        default = false,
    },

}