---@diagnostic disable: lowercase-global
name = "列队行为学 · 动作预览"
version = "0.1"
description = [[
为【ActionQueue RB3】添加动作预览（需同时开启原模组）
动作预览代码来自呼吸的【群鸟绘卷 · 江海󰀃】

支持种植植物预览、放置建筑预览、丢弃物品预览、挖地皮预览、耕地预览、浇水预览
兼容原版几何布局&耕地对齐模组
]]
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
        name = "number",
        label = "预览数量",
        hover = "太多会导致游戏掉帧",
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
        label = "预览亮度",
        hover = "感觉主要是影响在黑暗环境下的亮度...",
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
        label = "预览颜色",
        hover = "给预览的物品染个色",
        options = { -- 和行为学的设置一致
            {description = "白色", data = "WHITE"},
            {description = "红色", data = "FIREBRICK"},
            {description = "橙色", data = "TAN"},
            {description = "黄色", data = "LIGHTGOLD"},
            {description = "绿色",  data = "GREEN"},
            {description = "青色",   data = "TEAL"},
            {description = "蓝色" ,  data = "OTHERBLUE"},
            {description = "紫色", data = "DARKPLUM"},
            {description = "粉色" ,  data = "ROSYBROWN"},
            {description = "金色",   data = "GOLDENROD"},
        },
        default = "GREEN",
    },
    {
        name = "dont_color",
        label = "禁用颜色",
        hover = "禁用预览颜色，预览物品将变得和真的一样",
        options = {
            {description = "是", data = true},
            {description = "否", data = false},
        },
        default = false,
    },
    {
        name = "debug_mode",
        label = "调试模式",
        hover = "",
        options = {
            {description = "是", data = true},
            {description = "否", data = false},
        },
        default = false,
    }
}