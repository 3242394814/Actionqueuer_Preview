name = "黑化排队论"
author = "萌萌的新" --

description = [[
作者：萌萌的新/呼吸/null / eXiGe / simplex(Original Author)
包含以下要素，
0.兼容了所有的mod动作。
0.1.女工批量检查花朵，需要带着玫瑰帽，shift右键双击花朵启动，按住CTRL可以增加选中范围。
0.2捡东西非常快,捡东西有两种模式1.shift加左键（慢速）2.shift加右键（高速但有漏掉的风险），捡东西无法使用右键框选。
0.3如果你发现不能打断，请检查是否开启了无尽重复模式，按键是F9
1.替换部分动作为手柄动作
2.自动执行拿起熟睡的鸟换鸟蛋操作等等
3.配合另一个点击切装备食用更佳。
4.线程开启的时候自动关闭延迟补偿，结束后自动开启。
5.薇诺娜可以用shift右键快速转化花朵
6.可与预览部署的物品
]]
forumthread = ""
api_version = 10

all_clients_require_mod = false
client_only_mod = true

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

icon_atlas = "icn.xml"
icon = "icn.tex"

version = "2.2.20"
server_filter_tags = {}
local null_options = {
	{ description = "", data = 0 }
}

local enable_disable_options = {
	{ description = "开启", data = true },
	{ description = "关闭", data = false },
}
local string = ""
local keys = {
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
	"LALT", "RALT", "LCTRL", "RCTRL", "LSHIFT", "RSHIFT", "TAB", "CAPSLOCK",
	"SPACE", "MINUS", "EQUALS", "BACKSPACE", "INSERT", "HOME", "DELETE", "END",
	"PAGEUP", "PAGEDOWN", "PRINT", "SCROLLOCK", "PAUSE", "PERIOD", "SLASH",
	"SEMICOLON", "LEFTBRACKET", "RIGHTBRACKET", "BACKSLASH", "UP", "DOWN", "LEFT", "RIGHT",
	"ENTER", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}
local keylist = {}
for i = 1, #keys do
	keylist[i] = {
		description = keys[i],
		data = "KEY_" .. string.upper(keys[i])
	}
end
keylist[#keylist + 1] = {
	description = "Disabled",
	data = false
}

local function MakeRangeOptions(first, last, step, textfn, datafn)
	local options = {}
	for value = first, last, step do
		local data = datafn and datafn(value) or value
		options[#options + 1] = {
			description = textfn and textfn(value, data),
			data = data,
		}
	end
	return options
end

local colour_options = MakeRangeOptions(0, 255, 5)
local opacity_options = MakeRangeOptions(0, 10, 1, function(_, data)
	return string.format("%.1f", data)
end, function(value)
	return value / 10
end)
local range_options = MakeRangeOptions(0, 80, 5)

local collect_options = {
	{ description = "关闭", data = 1 },
	{ description = "挖树根模式", data = 2 },
	{ description = "挖树根并收集", data = 3 },
	{ description = "收集模式", data = 4 },
}

local function AddTitle(name, label)
	return {
		name = name,
		label = label,
		options = null_options,
		default = 0,
	}
end

local function AddConfig(name, label, default, options, hover)
	return {
		name = name,
		label = label,
		hover = hover or "",
		options = options or enable_disable_options,
		default = default,
	}
end

configuration_options =
{
	AddTitle("aq_title_selectwidget", "框选显示"),
	AddConfig("aq_selectwidget", "显示框选提示框", true, nil, "开启后框选时显示选择范围。"),
	AddConfig("aq_selectwidget_r", "提示框颜色 R", 255, colour_options),
	AddConfig("aq_selectwidget_g", "提示框颜色 G", 90, colour_options),
	AddConfig("aq_selectwidget_b", "提示框颜色 B", 45, colour_options),
	AddConfig("aq_selectwidget_opacity", "提示框透明度", 0.5, opacity_options),

	AddTitle("aq_title_keys", "按键绑定"),
	AddConfig("aq_queuekey", "排队论启动键", "KEY_LSHIFT", keylist),
	AddConfig("aq_gridkey", "网格显示键", "KEY_F3", keylist),
	AddConfig("aq_recipekey", "重复制作键", "KEY_C", keylist),
	AddConfig("aq_endlesskey", "无尽重复模式键", "KEY_F9", keylist),
	AddConfig("aq_autocollectkey", "切换收集模式键", "KEY_F4", keylist),

	AddTitle("aq_title_behavior", "功能开关"),
	AddConfig("aq_highlight", "高亮选中目标", true),
	AddConfig("aq_endless_deploy", "无尽部署模式", false, nil, "是否默认开启无尽重复部署。"),
	AddConfig("aq_autocollect", "默认收集模式", 1, collect_options, "排队论自动收集的默认模式。"),
	AddConfig("aq_equipcane", "部分动作自动切手杖", true),
	AddConfig("aq_double_click_range", "双击选取范围", 20, range_options),
	AddConfig("aq_automaketool", "自动制作工具", true),
	AddConfig("aq_showdeploy", "显示部署预览", true),
	AddConfig("aq_autoequipmedal", "自动装备勋章", true),
}
