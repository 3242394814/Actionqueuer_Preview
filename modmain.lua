--设置为全局环境 就不用一个个GLOBAL的写
GLOBAL.setmetatable(env, {
	__index = function(t, k)
		return GLOBAL.rawget(GLOBAL, k)
	end
})
--[[do
	return
end]]
if not MOD_util then
	local function should_show_dig()
		if TheNet:GetIsServer() and TheNet:GetServerIsDedicated() then
			return false
		end
		if not TheFrontEnd then
			return false
		end
		if IsMigrating() then
			return false
		end
		return not InGamePlay()
	end
	if rawget(GLOBAL, "suggest_to_subscribe_mmdx_basementmod") then
		return
	end
	GLOBAL.suggest_to_subscribe_mmdx_basementmod = true
	AddGamePostInit(function()
		local pop
		pop = TheGlobalInstance:DoTaskInTime(0.1, function()
			if should_show_dig() then
				local PopupDialogScreen = require "screens/redux/popupdialog"
				TheFrontEnd:PushScreen(PopupDialogScreen(
					"模组基础运行库缺失！[you are lack the basement mod!]",
					"你缺少了模组基础运行库，你必须去订阅才能继续使用本模组\nyou lack of my basement mod,must to subscribe then you can use this mod",
					{
						{
							text = "返回[back]",
							cb = function()
								TheFrontEnd:PopScreen()
							end
						},
						{
							text = "启用库模组[enable]",
							cb = function()
								local modname = "workshop-3750329397"
								if table.contains(TheSim:GetModDirectoryNames(), modname) then
									KnownModIndex:Enable(modname)
									KnownModIndex:Save(nil)
								else
									return
								end
								TheFrontEnd:PopScreen()
							end
						},
						{
							text = "订阅！[subscribe!]",
							cb = function()
								VisitURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3750329397")
								TheSim:SubscribeToMod("workshop-3750329397")
								TheFrontEnd:PopScreen()
							end
						},
					}
				))
			end
		end)
	end)
	return
end
MOD_util:CheckUtilsVersion(1.0)
local Image = require("widgets/image")
local WX78Common = require("prefabs/wx78_common")
--
--https://steamcommunity.com/sharedfiles/filedetails/?id=3136701076
--organ queue https://steamcommunity.com/sharedfiles/filedetails/?id=2325441848
--默认
local function null()

end
local function GetConfigOrDefault(name, default, fallback_name)
	local value = GetModConfigData(name)
	if value == nil and fallback_name then
		value = GetModConfigData(fallback_name)
	end
	if value == nil then
		return default
	end
	return value
end

local function GetKeyConfigOrDefault(name, default)
	local value = GetConfigOrDefault(name, default)
	if type(value) == "string" then
		return rawget(GLOBAL, value) or default
	end
	return value
end

local default_aq_selectwidget = GetConfigOrDefault('aq_selectwidget', true)
local default_aq_queuekey = GetKeyConfigOrDefault('aq_queuekey', KEY_LSHIFT)
local default_aq_gridkey = GetKeyConfigOrDefault('aq_gridkey', KEY_F3)
local default_aq_recipekey = GetKeyConfigOrDefault('aq_recipekey', KEY_C)
local default_aq_endlesskey = GetKeyConfigOrDefault('aq_endlesskey', KEY_F9)
local default_aq_autocollectkey = GetKeyConfigOrDefault('aq_autocollectkey', KEY_F4)
local default_aq_highlight = GetConfigOrDefault('aq_highlight', true)
local default_aq_autocollect = GetConfigOrDefault('aq_autocollect', 1, 'autocollect')
local default_aq_endless_deploy = GetConfigOrDefault('aq_endless_deploy', false, 'endless_deploy')
local default_aq_selectwidget_r = GetConfigOrDefault('aq_selectwidget_r', 255)
local default_aq_selectwidget_g = GetConfigOrDefault('aq_selectwidget_g', 90)
local default_aq_selectwidget_b = GetConfigOrDefault('aq_selectwidget_b', 45)
local default_aq_selectwidget_opacity = GetConfigOrDefault('aq_selectwidget_opacity', 0.5)
local default_aq_lantern_chop = false --MOD_util:GetMOption("aq_lantern_chop", default_aq_lantern_chop)
local default_aq_equipcane = GetConfigOrDefault('aq_equipcane', true)
local default_aq_double_click_range = GetConfigOrDefault('aq_double_click_range', 20)
local default_aq_automaketool = GetConfigOrDefault('aq_automaketool', true)
local default_aq_showdeploy = GetConfigOrDefault('aq_showdeploy', true)
local default_aq_autoequipmedal = GetConfigOrDefault('aq_autoequipmedal', true) --auto equip medal
local default_dropcheck_internal = 0.5
Assets = Assets or {}
table.insert(Assets, Asset("ATLAS", "images/selection_square.xml"))
table.insert(Assets, Asset("IMAGE", "images/selection_square.tex"))
local authormode = true and MOD_util:Ismmdx() and true or false --没错，是我
local author_print = authormode and function(...)
	print(GetTime(), 'QUEUE:', ...)
end or function(...)
end
local ActionQueuer = {}
ActionQueuer.mem = {}
--来自lan的几何工具，代替了原版排队论的几何 射线法
local function isPointInSide(point, poss) --poss is {vector3,vector3,vector3,vector3}
	local x, z = point.x, point.z
	local inside = false
	local n = #poss
	for i = 1, n do
		local j = (i % n) + 1
		if ((poss[i].z > z) ~= (poss[j].z > z)) and (x < (poss[j].x - poss[i].x)
				* (z - poss[i].z) / (poss[j].z - poss[i].z) + poss[i].x) then
			inside = not inside
		end
	end
	return inside
end
local farm_spacing = 4 / 3
--selectitemfn_force 用到的
local ticketprefabs = { 'trinket', 'winter_', 'halloween', '_seeds' }
--寻找身上物品的函数
local custom_rpc = function(actionid)
	return function(act)
		SendRPCToServer(RPC.LeftClick, ACTIONS[actionid].code, act.target:GetPosition().x,
			act.target:GetPosition().z,
			act.target, nil, nil, ACTIONS[actionid].canforce, ACTIONS[actionid].mod_name)
	end
end
local custom_selectitemfn_force = function(tab)
	if tab.item and tab.item.prefab then
		for k, v in pairs(ticketprefabs) do
			if tab.oldprefab and string.find(tab.oldprefab, v) then
				return string.find(tab.item.prefab, v)
			end
		end
	end
end
local custom_addtimefn = function(rangerange)
	return function(act)
		return distsq(act.target:GetPosition(), ActionQueuer.inst:GetPosition()) < rangerange
	end
end
local function IsBusy(doer)
	doer = doer or ThePlayer
	return doer and doer.components.playercontroller and
		doer.components.playercontroller:IsDoingOrWorking()
end
local function IsTalking(doer)
	doer = doer or ThePlayer
	local talker = doer and doer.components and doer.components.talker
	local widget = talker and
		talker.widget
	local text = widget and widget.text
	return text and text.string
end
-- 视角角度，判断部署建筑的角度
local headings = {
	[0] = true,
	[45] = false,
	[90] = false,
	[135] = true,
	[180] = true,
	[225] = false,
	[270] = false,
	[315] = true,
	[360] = true
}
local sameprefablist = {
	['rock_flintless_low'] = 'rock_flintless',
	['rock_flintless_med'] = 'rock_flintless',
	['rock_flintless'] = 'rock_flintless',
	['stalagmite_tall'] = 'stalagmite',
	['stalagmite_tall_full'] = 'stalagmite',
	['stalagmite_tall_med'] = 'stalagmite',
	['stalagmite_tall_low'] = 'stalagmite',
	['stalagmite'] = 'stalagmite1',
	['stalagmite_full'] = 'stalagmite1',
	['stalagmite_med'] = 'stalagmite1',
	['stalagmite_low'] = 'stalagmite1',
	['gargoyle_werepighowl'] = 'gargoyle',
	['gargoyle_werepigdeath'] = 'gargoyle',
	['gargoyle_werepigatk'] = 'gargoyle',
	['gargoyle_hounddeath'] = 'gargoyle',
	['gargoyle_houndatk'] = 'gargoyle',
	['chessjunk'] = 'chessjunk',
	['chessjunk1'] = 'chessjunk',
	['chessjunk2'] = 'chessjunk',
	['chessjunk3'] = 'chessjunk',
	['shyerrytree1'] = 'shyerrytree',
	['shyerrytree2'] = 'shyerrytree',
	['shyerrytree3'] = 'shyerrytree',
	['shyerrytree4'] = 'shyerrytree',
	['chessjunk_spawner'] = 'chessjunk',
	['ruins_statue_head'] = 'ruins_statue',
	['ruins_statue_mage'] = 'ruins_statue',
	['ruins_statue_head_nogem'] = 'ruins_statue',
	['ruins_statue_mage_nogem'] = 'ruins_statue',
	['deer_antler'] = 'antler',
	['deer_antler1'] = 'antler',
	['deer_antler2'] = 'antler',
	['deer_antler3'] = 'antler',
	['klaussackkey'] = 'antler',
	['redgem'] = 'gem',
	['purplegem'] = 'gem',
	['bluegem'] = 'gem',
	['greengem'] = 'valuegem',
	['yellowgem'] = 'valuegem',
	['orangegem'] = 'valuegem',
	['opalpreciousgem'] = 'valuegem',
	['feather_canary'] = 'feather',
	['feather_crow'] = 'feather',
	['feather_robin'] = 'feather',
	['feather_robin_winter'] = 'feather',
	['goose_feather'] = 'feather',
	['malbatross_feather'] = 'feather',
	['flower_cave_double'] = 'flower',
	['flower_cave'] = 'flower',
	['lightflier_flower_cave'] = 'flower',
	['flower_cave_triple'] = 'flower',
}
local function ownerIsPlayer(item)
	return item.replica.inventoryitem and item.replica.inventoryitem:IsGrandOwner(ThePlayer)
end
local function returnfunction()
	local backpack = ThePlayer.replica.inventory:GetOverflowContainer()
	if backpack then
		for i = 1, backpack:GetNumSlots() do
			if not backpack:GetItemInSlot(i) then
				SendRPCToServer(RPC.PutAllOfActiveItemInSlot, i, backpack.inst)
				return
			end
		end
	end
	for i = 1, ThePlayer.replica.inventory:GetNumSlots() do
		if not ThePlayer.replica.inventory:GetItemInSlot(i) then
			SendRPCToServer(RPC.PutAllOfActiveItemInSlot, i)
			return
		end
	end
	for k, v in pairs(ThePlayer.replica.inventory:GetOpenContainers() or {}) do
		if k and k.replica and k.replica.container and ThePlayer.replica.inventory:IsHolding(k, true) then
			for i = 1, k.replica.container:GetNumSlots() do
				if not k.replica.container:GetItemInSlot(i) and ownerIsPlayer(k) then
					SendRPCToServer(RPC.PutAllOfActiveItemInSlot, i, k)
					return
				end
			end
		end
	end
	SendRPCToServer(RPC.ReturnActiveItem)
end
local fn_list = {}
local posaction_postab = {} --储存位置坐标，对于无实体的动作
local mem = {}
local function DealWx78_spinact(act, actcode, skip)
	if ThePlayer.GetModuleTypeCount and ThePlayer:GetModuleTypeCount("spin") > 0 then
		mem.need_clear_controls = true
		ThePlayer.components.playercontroller.remote_controls[CONTROL_PRIMARY] = 0
		if not skip then
			SendRPCToServer(RPC.LeftClick, actcode, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target)
		end
		return true
	end
end
local PlayerController = require "components/playercontroller"
local oldIsAnyOfControlsPressed = PlayerController.IsAnyOfControlsPressed
function PlayerController:IsAnyOfControlsPressed(...)
	if TheWorld.ismastersim and self.handler ~= nil then
		for i, v in ipairs({ ... }) do
			if self.remote_controls[v] ~= nil then
				return true
			end
		end
	end
	return oldIsAnyOfControlsPressed(self, ...)
end

local allowed_actions
allowed_actions = {
	["CHOP"] = {
		equipspeeditem = function()
			if ThePlayer.GetModuleTypeCount and ThePlayer:GetModuleTypeCount("spin") > 0 then
				return
			end
			return true
		end,
		act_pre_fn = function(act, self)
			if EQUIPSLOTS.MEDAL and not ThePlayer.replica.inventory:EquipHasTag('chopMedal')
				and ActionQueuer:CanEquipMedal() then
				local now = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.MEDAL)
				self.oldmedal = self.oldmedal or now
				local medal, k, backpack = INV_util:FindInInventory(nil, 'chopMedal')
				if medal then --multivariate_certificate
					if now and now:HasTag('multivariate_certificate') and not medal:HasTag('multivariate_certificate') then
						SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, k, backpack)
						SendRPCToServer(RPC.SwapEquipWithActiveItem)
						SendRPCToServer(RPC.ReturnActiveItem)
					else
						self:EquipItem(medal)
					end
				end
			end
		end,
		canuselantern = true,
		isleftclick = true,
		notbreakfn = function(act)
			local target = act.target
			if target and target:HasTag("rock_tree") then
				local anim = ENT_util:GetAnimation(target)
				if anim and (anim:find('fall_pre') or anim:find("fall_miss") or anim:find("fall_bounce")) then
					return true
				end
			end
		end,
		rpc = function(act)
			local target = act.target
			if DealWx78_spinact(act, ACTIONS.CHOP.code) then
				return
			end
			if target and target:HasTag("rock_tree") then --tree_rock1
				local anim = ENT_util:GetAnimation(target)
				if anim and (anim:find('fall_pre') or anim:find("fall_miss") or anim:find("fall_bounce")) then
					local pos = POS_util:CalculateAimPos(target, ThePlayer, 0,
						(target:HasTag("tree_rock1") and 3 or 4) + 0.5)
					local speeditem
					speeditem = ActionQueuer:HasAddSpeedEquipment()
					ActionQueuer:EquipItem(speeditem)
					ActionQueuer.waiting_for_break = 1
					POS_util:GoToPoint(pos.x, pos.z)
				else
					SendRPCToServer(RPC.LeftClick, ACTIONS.CHOP.code, act.target:GetPosition().x,
						act.target:GetPosition().z,
						act.target)
				end
			else
				SendRPCToServer(RPC.LeftClick, ACTIONS.CHOP.code, act.target:GetPosition().x, act.target:GetPosition().z,
					act.target)
			end
		end,
		tool = function(item)
			if type(item) == "string" then
				return string.find(item, "axe") and not string.find(item, "pick")
			end
			return item and item.HasTag and item:HasTag('CHOP_tool')
		end,
		maketool = true,
		breakfn = function(act)
			return act.target and act.target:HasTag('stump')
		end,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
		reselectfn = function(act)
			if act.target and (ActionQueuer.autocollect == 2 or ActionQueuer.autocollect == 3) and ActionQueuer:GetAction(act.target, 'DIG') then
				ActionQueuer:SelectEntity(act.target, 'DIG', nil, nil, true)
			end
		end,
	},
	['MINE'] = {
		equipspeeditem = function()
			if ThePlayer.GetModuleTypeCount and ThePlayer:GetModuleTypeCount("spin") > 0 then
				return
			end
			return true
		end,
		act_pre_fn = function(act, self)
			if EQUIPSLOTS.MEDAL and not ThePlayer.replica.inventory:EquipHasTag('minerMedal')
				and ActionQueuer:CanEquipMedal() then
				local now = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.MEDAL)
				self.oldmedal = self.oldmedal or now
				local medal, k, backpack = INV_util:FindInInventory(nil, 'minerMedal')
				if medal then
					if now and now:HasTag('multivariate_certificate') and not medal:HasTag('multivariate_certificate') then
						SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, k, backpack)
						SendRPCToServer(RPC.SwapEquipWithActiveItem)
						SendRPCToServer(RPC.ReturnActiveItem)
					else
						self:EquipItem(medal)
					end
				end
			end
		end,
		canuselantern = true,
		isleftclick = true,
		rpc = function(act)
			if DealWx78_spinact(act, ACTIONS.MINE.code) then
				return
			end

			SendRPCToServer(RPC.LeftClick, ACTIONS.MINE.code, act.target:GetPosition().x, act.target:GetPosition().z,
				act.target)
		end,
		tool = function(item)
			if type(item) == "string" then
				return string.find(item, "pickaxe")
			end
			return item and item.HasTag and item:HasTag('MINE_tool')
		end,
		maketool = true,
		breakfn = function(act)
			if act.target and act.target.prefab == "daywalker_pillar" and act.target.AnimState then
				return act.target.AnimState:IsCurrentAnimation("pillar_shake") or
					ThePlayer.AnimState:IsCurrentAnimation("pickaxe_recoil") and
					distsq(ThePlayer:GetPosition(), act.target:GetPosition()) < 9
			end
		end,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
		reselectfn = function(act)
			if act.target and act.target.prefab == 'spiderhole' then
				for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 4, nil)) do
					if ent.prefab == "spiderhole_rock" then
						ActionQueuer:SelectEntity(ent, 'MINE')
					end
				end
			end
			if act.target and act.target.prefab == 'rock_ice' then
				for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 4, nil)) do
					if ent.prefab == "ice" then
						ActionQueuer:SelectEntity(ent, 'PICKUP')
					end
				end
			end
		end,
	},
	["HAMMER"] = {
		equipspeeditem = true,
		canuselantern = true,
		isleftclick = false,
		rpc = function(act)
			SendRPCToServer(RPC.RightClick, ACTIONS.HAMMER.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target)
		end,
		tool = function(item)
			if type(item) == "string" then
				return item == 'hammer'
			end
			return item and item.HasTag and item:HasTag('HAMMER_tool')
		end,
		maketool = true,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
		reselectfn = function(act)
			if act.target and act.target.prefab == 'ancient_altar' then
				for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 4, nil)) do
					if ent.prefab == "ancient_altar_broken" then
						ActionQueuer:SelectEntity(ent, 'HAMMER', nil, nil, true)
					end
				end
			end
		end,
	},
	['MEDALHAMMER'] = { --勋章月光锤
		equipspeeditem = true,
		isleftclick = false,
		rpc = function(act)
			SendRPCToServer(RPC.RightClick, ACTIONS.MEDALHAMMER.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, nil, ACTIONS['MEDALHAMMER'].canforce, ACTIONS['MEDALHAMMER'].mod_name)
		end,
		tool = function(item)
			return item and item.prefab == 'medal_moonglass_hammer'
		end,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
	},
	['NET'] = {
		equipspeeditem = true,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.NET.code, act.target:GetPosition().x, act.target:GetPosition().z,
					act.target, nil, nil, true)
			end
		end,
		tool = function(item)
			if type(item) == "string" then
				return item == 'bugnet'
			end
			return item and item.HasTag and item:HasTag('NET_tool')
		end,
		maketool = true,
	},
	['DIG'] = {
		equipspeeditem = true,
		canuselantern = true,
		--isleftclick = false,
		rpc = function(act)
			SendRPCToServer(RPC.LeftClick, ACTIONS.DIG.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target)
		end,
		tool = function(item)
			if type(item) == "string" then
				return string.find(item, "shovel")
			end
			return item and item.HasTag and item:HasTag('DIG_tool')
		end,
		maketool = true,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
	},
	['MEDALTRANSPLANT'] = { --勋章移植
		equipspeeditem = true,
		isleftclick = false,
		rpc = function(act)
			SendRPCToServer(RPC.RightClick, ACTIONS.MEDALTRANSPLANT.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, nil, ACTIONS['MEDALTRANSPLANT'].canforce, ACTIONS['MEDALTRANSPLANT'].mod_name)
		end,
		tool = function(item)
			return item and item.prefab == 'medal_moonglass_shovel'
		end,
		allowautocollect = function(target, self)
			return self.autocollect > 2
		end,
	},
	["READ"] = {
		--dontneedhighlight = true,
		rpc = function(act)
			if ThePlayer.AnimState:IsCurrentAnimation("book") and ThePlayer.AnimState:GetCurrentAnimationFrame() < 54 then
			else
				SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.READ.code, act.item)
			end
		end,
		selectitemfn = function(book)
			local i = 100
			local classified = book.replica and book.replica.inventoryitem and
				book.replica.inventoryitem.classified
			if classified and classified.percentused then
				i = classified.percentused:value()
				if i == 100 then
					return true --至少读一次
				end
			end
			if CMP_util then
				local total = CMP_util:CalculateCMPData(CMP_util:GetPrefabData(book.prefab), "finiteuses", "SetMaxUses",
					1)
				if type(total) == "number" then
					return i > 100 / total
				end
			else
				return true
			end
		end,
		sleeptime = 0.1,
		controllertable = { needreturnactiveitem = true },
	},
	["HEAL"] = {
		rpc = function(act)
			if act.target == ThePlayer then
				SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.HEAL.code, act.item)
			else
				if not IsBusy() or act.time < 0.1 then
					ActionQueuer:SendControllerRPCSafely(ACTIONS.HEAL.code, act.item, act.target,
						ACTIONS.HEAL.mod_name)
				end
			end
		end,
		sleeptime = 0.1,
		controllertable = {

		},
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "USEITEM", "HEAL", act)
		end,
	},
	["FEEDPLAYER"] = {
		isleftclick = false,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				ActionQueuer:SendControllerRPCSafely(ACTIONS.FEEDPLAYER.code, act.item, act.target,
					ACTIONS.FEEDPLAYER.mod_name)
			end
		end,
		stacknumdirtyezsylisten = true,
		controllertable = {

		},
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "USEITEM", "FEEDPLAYER", act)
		end,
	},
	["EAT"] = {
		rpc = function(act)
			SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.EAT.code, act.item)
		end,
		sleeptime = 0.1,
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "INVENTORY", "EAT", act)
		end,
		controllertable = {},
	},
	["PICKUP"] = {
		dontselectbyselectbox = function(ent, rightclick)
			--ban rightclick selectbox select
			if rightclick == true then
				return true
			end
		end,
		equipspeeditem = true,
		--[[ isleftclick = function(target)
            if target and (target:HasTag("spider") or target:HasTag("heavy")) then
                return false
            end
            return true
        end, ]]
		rpc = function(act) --self.selected_ents[ent].rightclick
			-- print(self.selected_ents[ent].rightclick)
			if act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.PICKUP.code, act.target:GetPosition().x,
					act.target:GetPosition().z, act.target)
			elseif ActionQueuer.inst:HasTag("working") then
				SendRPCToServer(RPC.LeftClick, ACTIONS.PICKUP.code, act.target:GetPosition().x,
					act.target:GetPosition().z, act.target)
				--ActionButton is safety,will not pickup twice
			elseif (act.target and math.sqrt(distsq(act.target:GetPosition(), ActionQueuer.inst:GetPosition())) < 5) then
				SendRPCToServer(RPC.ActionButton, ACTIONS.PICKUP.code, act.target)
			else
				SendRPCToServer(RPC.LeftClick, ACTIONS.PICKUP.code, act.target:GetPosition().x,
					act.target:GetPosition().z, act.target)
			end
		end,
		breakfn = function(act)
			local selecttable = ActionQueuer and ActionQueuer:GetSelectedEnt(act.target)
			--rightclick will lead fast break for fast pickup
			if selecttable and selecttable.rightclick or true then
				if act.time > 0.1 and (ActionQueuer.inst.AnimState:IsCurrentAnimation("pickup_pst"))
					and ActionQueuer:HaveAnotherSelectedEnt(act.target) then
					--delay 0.2 then reselect
					act.target:DoTaskInTime(0.2, function()
						if not act.target:HasTag("INLIMBO") then
							ActionQueuer:SelectEntity(act.target, 'PICKUP')
						end
					end)
					return true
				end
			end
		end,
		noactfn = function(act)
			ActionQueuer:DeselectEntity(act.target)
			if act.target and act.target.replica.stackable then
				ActionQueuer:SelectEntity(act.target, 'COMBINESTACK')
			end
		end,
		reselectfn = function(act)
			--这里的逻辑是对于有deploypos的实体，捡起来后立刻部署在对应位置。用于发电机？
			if act.target and act.target.deploypos then
				if not ActionQueuer:HaveAnotherSelectedEnt(act.target) then
					local pos = act.target.deploypos
					local x, z = pos.x, pos.z
					--ThePlayer:DoTaskInTime(0.5, function()
					SendRPCToServer(RPC.ControllerActionButtonDeploy, act.target, x, z)
					--end)
				end
				act.target.deploypos = nil
			end
		end,
	},
	['UNWRAPGIFTFRUIT'] = { --勋章拆包裹
		rpc = function(act)
			if act.item then
				SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.UNWRAPGIFTFRUIT.code, act.item,
					ACTIONS.UNWRAPGIFTFRUIT.mod_name)
			elseif act.target then
				SendRPCToServer(RPC.RightClick, ACTIONS.UNWRAPGIFTFRUIT.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, nil, nil, ACTIONS.UNWRAPGIFTFRUIT.mod_name)
			end
		end,
		sleeptime = 0.1,
		controllercanselect = function(act)
			return act.item
		end,
		controllertable = {},
	},
	["PICK"] = {
		equipspeeditem = function(act)
			if ThePlayer.GetModuleTypeCount and ThePlayer:GetModuleTypeCount("spin") > 0
				and act.target:HasAnyTag(HARVESTABLE_PLANT_TARGET_TAGS) then
				local item = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
				if WX78Common.CanSpinUsingItem(item) then
					return
				end
			end
			return true
		end,
		--isleftclick = true,
		isleftclick = function(target)
			if target and (target:HasTag("flower")) then
				return true
			end
			return nil
		end,
		rpc = function(act)
			-- if (act.target and math.sqrt(distsq(act.target:GetPosition(), ThePlayer:GetPosition())) < 5) then
			--SendRPCToServer(RPC.ActionButton, ACTIONS.PICK.code, act.target, nil, true)
			--else
			if DealWx78_spinact(act, ACTIONS.PICK.code, true) then
				SendRPCToServer(RPC.LeftClick, ACTIONS.PICK.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.PICK.canforce, ACTIONS.PICK.mod_name)
			elseif act.time > 0.5 and not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.PICK.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.PICK.canforce, ACTIONS.PICK.mod_name)
			end
		end,
		notbreakfn = function(act)
			if act.target and act.target.prefab == 'junk_pile' then
				return true
			end
		end,
		breakfn = function(act)
			if act.target and act.target.prefab == 'junk_pile' and
				ActionQueuer.selected_ents[act.target].specialtag ~= 'destory_low_pile' then
				return act.target.AnimState:IsCurrentAnimation("idlelow")
					or act.target.AnimState:IsCurrentAnimation("looplow") --looplow
			end
		end,
		addtimefn = custom_addtimefn(3.95 * 3.95),
	},
	["PLANTSOIL"] = {
		equipspeeditem = true,
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS.PLANTSOIL.code, act.item, act.target,
				ACTIONS.PLANTSOIL.mod_name)
		end,
		controllertable = {},
	},
	["PLANTSOIL_LEGION"] = {
		equipspeeditem = true,
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS.PLANTSOIL_LEGION.code, act.item,
				act.target,
				ACTIONS.PLANTSOIL_LEGION.mod_name)
		end,
		controllertable = {},
	},
	["ERASE_PAPER"] = {
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS.ERASE_PAPER.code, act.item, act.target)
		end,
		controllertable = {},
		notbreakfn = function(act)
			local target = act.target
			local item = act.item
			if target:HasTag("papereraser")
				and not target:HasTag("fire")
				and not target:HasTag("burnt")
			then
				return item
			end
		end,
	},
	['CAST_POCKETWATCH'] = {
		rpc = function(act)
			SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.CAST_POCKETWATCH.code, act.item)
		end,
		selectitemfn = function(item)
			return item and item:HasTag('pocketwatch_inactive') and item:HasTag('pocketwatch')
		end,
		sleeptime = 0.1,
		controllertable = {},
	},
	["ADDFUEL"] = {
		equipspeeditem = true,
		isleftclick = true,
		rpc = function(act)
			local nextpit
			if ActionQueuer:HaveAnotherSelectedEnt(act.target) then
				nextpit = true
			end
			if not nextpit or not IsBusy() or act.time < 0.1 or act.time > 0.5 then
				ActionQueuer:SendControllerRPCSafely(ACTIONS.ADDFUEL.code, act.item, act.target)
			end
		end,
		controllertable = {},
		breakfn = function(act)
			if act.target and act.target.prefab == "firesuppressor" and act.target.AnimState then
				local _, symbol = act.target.AnimState:GetSymbolOverride("swap_meter")
				if hash(10) == symbol then
					return true
				end
			end
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.stacknumdirty or act.time > 0.5
			end)
		end,
		notbreakfn = function(act)
			return act and act.item
		end,
		addtimefn = custom_addtimefn(1.5)
	},
	["ADDWETFUEL"] = {
		equipspeeditem = true,
		isleftclick = true,
		rpc = function(act) --acttab
			local nextpit
			if ActionQueuer:HaveAnotherSelectedEnt(act.target) then
				nextpit = true
			end
			if not nextpit or not IsBusy() or act.time < 0.1 or act.time > 0.5 then
				ActionQueuer:SendControllerRPCSafely(ACTIONS.ADDWETFUEL.code, act.item, act.target)
			end
		end,
		controllertable = {},
		breakfn = function(act)
			if act.target and act.target.prefab == "firesuppressor" and act.target.AnimState then
				local _, symbol = act.target.AnimState:GetSymbolOverride("swap_meter")
				if hash(10) == symbol then
					return true
				end
			end
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.stacknumdirty or act.time > 0.5
			end)
		end,
		notbreakfn = function(act)
			return act and act.item
		end,
		addtimefn = custom_addtimefn(1.5)
	},
	["GIVE"] = {
		isleftclick = true,
		doinganim = "give",
		rpc = function(act)
			if act.target and act.target.prefab == 'birdcage' then
				if act.target.AnimState:IsCurrentAnimation("sleep_loop") or
					act.target.AnimState:IsCurrentAnimation("sleep_pre") then
					SendRPCToServer(RPC.ControllerActionButton, ACTIONS.HARVEST.code, act.target)
				elseif act.target.AnimState:IsCurrentAnimation("idle_empty") then
					local bird = INV_util:FindInInventory(nil, 'bird')
					ActionQueuer:SendControllerRPCSafely(ACTIONS.STORE.code, bird, act.target)
				else
					ActionQueuer:SendControllerRPCSafely(ACTIONS.GIVE.code, act.item, act.target)
				end
				return
			end
			if act.time < 0.1 or not ActionQueuer.inst.AnimState:IsCurrentAnimation("give") then
				ActionQueuer:SendControllerRPCSafely2(ACTIONS.GIVE.code, act.item, act.target)
			end
		end,
		notbreakfn = function(act)
			if act.target and act.target.prefab == 'birdcage' then
				return act.item and act.target.AnimState:IsCurrentAnimation("idle_empty") and
					INV_util:FindInInventory(nil, 'bird')
			end
		end,
		addbusytime = function(act)
			return distsq(act.target:GetPosition(), ActionQueuer.inst:GetPosition()) < 3 * 3
		end,
		breakfn = function(act)
			if act.target and act.target.prefab == 'mushroom_farm' then
				return act.busytime > 1 and ActionQueuer:HaveAnotherSelectedEnt(act.target)
			end
		end,
		stacknumdirtyezsylisten = true,
		controllertable = {
			cancelcontroller = function(act)
				if act and act.target then
					if act.target.prefab == 'siving_ctlall' or act.target.prefab == 'siving_ctldirt'
						or act.target.prefab == 'siving_thetree' then
						return true
					end
				end
				return false
			end,
			needreturnactiveitem = function(act)
				return act.target and act.target.prefab == 'birdcage'
			end,
		},
		selectitemfn_force = custom_selectitemfn_force,
	},
	["GIVEALLTOPLAYER"] = {
		isleftclick = true,
		rpc = custom_rpc("GIVEALLTOPLAYER"),
		selectitemfn_force = custom_selectitemfn_force,
	},
	GIVETOPLAYER = {
		isleftclick = true,
		stacknumdirtyezsylisten = true,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.GIVETOPLAYER.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, 10, ACTIONS.GIVETOPLAYER.canforce, ACTIONS.GIVETOPLAYER.mod_name)
			end
		end,
		selectitemfn_force = custom_selectitemfn_force,
	},
	FISH = {
		equipspeeditem = true,
		isleftclick = true,
		rpc = function(act)
			if not act.target then return end
			local pos = act.target:GetPosition()
			local hand = INV_util:GetHandsEquip()
			local fishingrod = hand and hand.replica.fishingrod
			if fishingrod and fishingrod:HasHookedFish() then
				SendRPCToServer(RPC.LeftClick, ACTIONS.REEL.code,
					pos.x,
					pos.z, act.target)
			elseif ThePlayer:HasTag("nibble") then
				SendRPCToServer(RPC.LeftClick, ACTIONS.REEL.code,
					pos.x,
					pos.z, act.target)
			else
				SendRPCToServer(RPC.LeftClick, ACTIONS.FISH.code,
					pos.x,
					pos.z, act.target)
			end
		end,
		notbreakfn = function(act)
			return ThePlayer.replica.inventory:EquipHasTag("fishingrod")
		end,
		tool = function(item)
			if type(item) == "string" then
				return string.find(item, "fishingrod")
			end
			return item and item.HasTag and item:HasTag("fishingrod")
		end,
		addtimefn = function(act)
			return true
		end,
		breakfn = function(act)
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time > 25 and ThePlayer.AnimState:IsCurrentAnimation("fishing_cast") or act.time > 50
			end)
		end,
	},
	MURDER = {
		rpc = function(act)
			SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.MURDER.code, act.item)
		end,
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "INVENTORY", "MURDER", act)
		end,
		controllertable = {},
	},
	LIGHT = {
		rpc = function(act)
			if act.time < 0.1 or not ThePlayer:HasTag('moving') then
				ActionQueuer:SendControllerRPCSafely(ACTIONS.LIGHT.code, act.item
					or INV_util:GetHandsEquip(), act.target)
			end
		end,
		controllertable = {},
	},

	STORE = {
		dontselectbyselectbox = true,
		isleftclick = true,
		rpc = function(act)
			local acceptstacksize = act.target.replica.container and act.target.replica.container:AcceptsStacks()
			if act.target.replica.container and act.target.replica.container:IsOpenedBy(ThePlayer)
				and not acceptstacksize then
				if act.item == INV_util:GetActiveItem() then
					local num = act.target.replica.container and act.target.replica.container:GetNumSlots() or 10
					local stacksize = act.item.replica.stackable and act.item.replica.stackable:StackSize() or 1
					for k = 1, num do
						if not act.target.replica.container:GetItemInSlot(k) then
							if stacksize == 1 then
								SendRPCToServer(RPC.PutAllOfActiveItemInSlot, k, act.target)
							else
								SendRPCToServer(RPC.PutOneOfActiveItemInSlot, k, act.target)
								stacksize = stacksize - 1
							end
						end
					end
				else
					local a, b, c = INV_util:FindInInv(nil, nil, nil, function(item)
						return item == act.item
					end)
					if a then
						if c then
							SendRPCToServer(RPC.MoveItemFromAllOfSlot, b, c, act.target)
						else
							SendRPCToServer(RPC.MoveInvItemFromAllOfSlot, b, act.target)
						end
					end
				end
				return
			end
			if not acceptstacksize then
				if not IsBusy() or act.time < 0.1 then
					ActionQueuer:SendControllerRPCSafely(ACTIONS.STORE.code, act.item, act.target)
				end
				return
			end
			ActionQueuer:SendControllerRPCSafely(ACTIONS.STORE.code, act.item, act.target)
			if not ActionQueuer:CanSeeTarget(act.target) then
				local num = act.target.replica.container and act.target.replica.container:GetNumSlots() or 10
				for i = 1, num do
					SendRPCToServer(RPC.MoveItemFromAllOfSlot, i, act.target)
				end
			end
		end,
		--[[controllertable = {
			cancelcontroller = function(act)
				if act and act.target and act.target.replica.container then
					return not act.target.replica.container:AcceptsStacks()
				end
			end,
		},]]
		selectitemfn = function(item) --store需要排除掉目标箱子里面的
			return ownerIsPlayer(item)
		end,
		breakfn = function(act)
			local container = act.target and act.target.replica and act.target.replica.container
			if act.item and
				act.target and act.target:HasTag("mermonly") then
				--Container:Has(prefab, amount, iscrafting)
				--ENT_util:GetMaxSize(update_item)
				return container and container:Has(act.item.prefab, ENT_util:GetMaxSize(act.item), false)
			end
			--[[ merm_armory
            merm_armory_upgraded ]]
			if container and container:IsFull() then
				return true
			end
			return false
		end,

		selectitemfn_force = function(tab)
			if ownerIsPlayer(tab.item) then
				return custom_selectitemfn_force(tab)
			end
		end,
		addtimefn = function(act)
			return act.target and act.target.replica and act.target.replica.container and
				act.target.replica.container:IsOpenedBy(ActionQueuer.inst)
		end,
		controllercanselect = function(act)
			act.right = false
			return ActionQueuer:collectActions(act.item, "USEITEM", "STORE", act)
		end,
	},
	["ATTACK"] = {
		dontneedhighlight = true,
		dontselectbyselectbox = function(ent)
			if ent and ent.prefab == "mandrake_active" then
				return false
			end
			return true
		end,
		--isleftclick = true,
		rpc = function(act)
			if DealWx78_spinact(act, ACTIONS.ATTACK.code, true) then
				SendRPCToServer(RPC.LeftClick, ACTIONS.ATTACK.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, 10, ACTIONS.ATTACK.canforce, ACTIONS.ATTACK.mod_name)
				return
			end
			SendRPCToServer(RPC.LeftClick, ACTIONS.ATTACK.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, 10, ACTIONS.ATTACK.canforce, ACTIONS.ATTACK.mod_name)
		end,
		tool = function(item, hand_item)
			local handprefab = hand_item and hand_item.prefab
			if item and handprefab == item.prefab then
				return true
			end
		end,
		--
		specialselectfn = function(actiontable, target)
			local attack = target and
				ThePlayer.components.playeractionpicker:SortActionList({ ACTIONS.ATTACK }, target, nil)
				and target.replica.combat and ThePlayer.replica.combat:CanTarget(target)
			if attack then
				return ACTIONS.ATTACK, actiontable
			end
		end,
	},
	["SHAVE"] = {
		isleftclick = true,
		rpc = function(act)
			if act.target == ActionQueuer.inst then
				SendRPCToServer(RPC.LeftClick, ACTIONS.SHAVE.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target)
			else
				ActionQueuer:SendControllerRPCSafely(ACTIONS.SHAVE.code, act.item, act.target)
			end
		end,
		controllertable = {},
		controllercanselect = function(act)
			act.right = false
			return ActionQueuer:collectActions(act.item, "USEITEM", "SHAVE", act)
		end,
		breakfn = function(act) --brushable
			--[[ if act.target and act.target:HasTag('has_beard') then
                return not act.target.AnimState:IsCurrentAnimation("sleep_loop")
            end ]] --spiderden
			if act.target and act.target:HasTag('spiderden') then
				local tag = ActionQueuer.selected_ents[act.target].specialtag
				if tag == 'destory_cocoon_small' then
					return act.target.AnimState:IsCurrentAnimation("cocoon_dead")
				else
					return act.target.AnimState:IsCurrentAnimation("cocoon_small")
						or act.target.AnimState:IsCurrentAnimation("shave_medium_to_small")
				end
			elseif act.target == ActionQueuer.inst then
				return (act.time - act.busytime) > 1
				--inst:AddTag("has_beard")
			elseif act.target:HasTag("beefalo") then
				if act.target:HasTag('sleeping') then
					return not act.target:HasTag("has_beard")
				elseif ActionQueuer:HaveAnotherSelectedEnt(act.target) then
					return true
				end
			else
				return (act.time - act.busytime) > 1 or
					(act.busytime > 0.3 and not IsBusy())
			end
		end,
		addbusytime = function(act)
			return distsq(act.target:GetPosition(), ActionQueuer.inst:GetPosition()) < 16 and IsBusy()
		end,
		addtimefn = function(act)
			return distsq(act.target:GetPosition(), ActionQueuer.inst:GetPosition()) < 16
		end,
		sleeptime = 0.1,
	},
	['MEDALPOLLUTE'] = {                  --勋章黑化血糖
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then --因为目标会瞬移所以不能一直发
				ActionQueuer:SendControllerRPCSafely(ACTIONS.MEDALPOLLUTE.code, act.item,
					act.target,
					ACTIONS.MEDALPOLLUTE.mod_name)
			end
		end,
		controllertable = {},
	},
	['ACTIVATE'] = {
		--isleftclick = true,
		dontselectbyselectbox = function(ent)
			return ent and ent.prefab ~= 'dirtpile' and ent.prefab ~= 'catcoonden'
		end,
		rpc = function(act)
			SendRPCToServer(RPC.LeftClick, ACTIONS.ACTIVATE.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, ACTIONS.ACTIVATE.canforce, ACTIONS.ACTIVATE.mod_name)
		end,
		reselectfn = function(act)
			if act.target and act.target.prefab == 'dirtpile' then
				for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 45, { 'dirtpile' })) do
					if ent and ent.prefab == 'dirtpile' then
						ActionQueuer:SelectEntity(ent, 'ACTIVATE')
						break
					end
				end
			end
		end,
		addtimefn = custom_addtimefn(4 * 4),
		breakfn = function(act)
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time > 5
			end)
		end,
	},
	['ROTATE_FENCE'] = {
		isleftclick = false,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 or act.time > 0.4 then --最有操作的一集
				SendRPCToServer(RPC.LeftClick, ACTIONS.ROTATE_FENCE.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.ROTATE_FENCE.canforce, ACTIONS.ROTATE_FENCE.mod_name)
			end
		end,
		breakfn = function(act)
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time > 0.3
			end)
		end,
		addtimefn = custom_addtimefn(4)
	},
	["CASTSPELL"] = {
		isleftclick = false,
		rpc = function(act)
			local hand = INV_util:GetHandsEquip()
			if hand and hand:HasTag('veryquickcast') then --扫把
				if act.time < 0.1 or act.time > 0.4 then --最有操作的一集
					SendRPCToServer(RPC.LeftClick, ACTIONS.CASTSPELL.code, act.target:GetPosition().x,
						act.target:GetPosition().z,
						act.target, nil, nil, ACTIONS.CASTSPELL.canforce, ACTIONS.CASTSPELL.mod_name)
				end
			else
				SendRPCToServer(RPC.LeftClick, ACTIONS.CASTSPELL.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.CASTSPELL.canforce, ACTIONS.CASTSPELL.mod_name)
			end
		end,
		breakfn = function(act)
			local hand = INV_util:GetHandsEquip()
			if hand and hand:HasTag('veryquickcast') then
				return ActionQueuer.mem.not_unique_target and
					act.time > 0.3 --[[ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
					return act.time > 0.3
				end)]]
			elseif hand and hand.prefab == 'staff_tornado' then
				return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
					return act.time > 0.4
				end)
			end
		end,
		addtimefn = custom_addtimefn(20 * 20),
		tool = function(item, hand_item)
			local handprefab = hand_item and hand_item.prefab
			if item and handprefab == item.prefab then
				return true
			elseif not handprefab then
				return item and item.HasOneOfTags and
					item:HasOneOfTags({ 'veryquickcast', 'castonrecipes', "castontargets", "castonlocomotors",
						"castoncombat",
						"castonworkable", }) --maybe has bug?
			end
		end,
		noactfn = function(act)
			local handprefab = act.hand and act.hand.prefab
			if handprefab then
				local item = INV_util:FindInInventory(handprefab)
				if item then
					SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, item, nil, nil)
					ActionQueuer:SelectEntity(act.target, "CASTSPELL", nil, nil, true)
				else
					ActionQueuer:DeselectEntity(act.target)
				end
			end
		end,
	},
	["DECORATEVASE"] = { --插花
		isleftclick = true,
		rpc = function(act)
			if not IsBusy() then
				SendRPCToServer(RPC.LeftClick, ACTIONS.DECORATEVASE.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.DECORATEVASE.canforce, ACTIONS.DECORATEVASE.mod_name)
			end
		end,
		stacknumdirtyezsylisten = true,
		breakfn = function(act)
			return act.time > 3 --[[ ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time >  1 and not IsBusy()
					and not ActionQueuer.inst:HasTag("moving")
					and ActionQueuer.inst:HasTag("idle")
			end)]]
		end,
		addtimefn = custom_addtimefn(2 * 2)
	},
	['RAISE_ANCHOR'] = {
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS['RAISE_ANCHOR'].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS['RAISE_ANCHOR'].canforce, ACTIONS['RAISE_ANCHOR'].mod_name)
			end
		end,
	},
	['LOWER_ANCHOR'] = {
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS['LOWER_ANCHOR'].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS['LOWER_ANCHOR'].canforce, ACTIONS['LOWER_ANCHOR'].mod_name)
			end
		end,
	},
	["LOWER_SAIL_BOOST"] = {
		rpc = custom_rpc('LOWER_SAIL_BOOST'), --closed
		notbreakfn = function(act)
			if act.target and act.target.prefab == 'mast' and act.target.AnimState and not act.target.AnimState:IsCurrentAnimation("closed") then
				return true
			elseif act.target and act.target.prefab == 'mast_malbatross' and act.target.AnimState
				and not act.target.AnimState:IsCurrentAnimation("open_loop") then --knot_tie
				return true
			end
		end
	},
	["REPAIR_LEAK"] = {
		isleftclick = true,
		rpc = function(act)
			if not IsBusy() and act.time < 0.5 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.REPAIR_LEAK.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.REPAIR_LEAK.canforce, ACTIONS.REPAIR_LEAK.mod_name)
			end
		end,
		breakfn = function(act)
			if act.time > 0.5 and not IsBusy()
				and not ActionQueuer.inst:HasTag("moving") then
				return true
			end
		end,
		addtimefn = custom_addtimefn(2.5 * 2.5)
	},
	["LIFEBEND"] = { --棱镜子规歃
		isleftclick = false,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 or act.time > 1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.LIFEBEND.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS.LIFEBEND.canforce, ACTIONS.LIFEBEND.mod_name)
			end
		end,
		breakfn = function(act)
			--barren
			if act.target and act.target:HasTag('barren') then
			else
				return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
					return act.time > 0.3
				end)
			end
		end,
		addtimefn = custom_addtimefn(1)
	},
	['MAKECOOLDOWN'] = { --勋章红晶降温
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS['MAKECOOLDOWN'].code, act.item,
				act.target,
				ACTIONS['MAKECOOLDOWN'].mod_name)
		end,
		controllertable = {},
	},
	['MEDALPYTREDE'] = { --勋章py
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS['MEDALPYTREDE'].code, act.item,
				act.target,
				ACTIONS['MEDALPYTREDE'].mod_name)
		end,
		controllertable = {},
		stacknumdirtyezsylisten = true,
	},
	['CHEFFLAVOUR'] = {
		isleftclick = true,
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS['CHEFFLAVOUR'].code, act.item,
				act.target,
				ACTIONS['CHEFFLAVOUR'].mod_name)
		end,
		controllertable = {},
	},
	['RUB_L'] = { --电气石摩擦
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS['RUB_L'].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS['RUB_L'].canforce, ACTIONS['RUB_L'].mod_name)
			end
		end,
		breakfn = function(act)
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time > 1
			end)
		end,
		addtimefn = function(act)
			return distsq(act.target:GetPosition(), ThePlayer:GetPosition()) <
				(act.target:GetPhysicsRadius(0) + ThePlayer:GetPhysicsRadius(0) + 0.2) ^ 2
		end,
	},
	['PLUCK'] = { --富贵
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS['PLUCK'].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS['PLUCK'].canforce, ACTIONS['PLUCK'].mod_name)
			end
		end,
	},
	['SCYTHE'] = {
		rpc = function(act)
			--IsWithinAngle
			local hand = INV_util:GetHandsEquip()
			local scythe = hand and hand.prefab == 'voidcloth_scythe' and hand or act.item or
				INV_util:FindInInventory('voidcloth_scythe')
			local item = scythe
			if item and item.replica.equippable and item.replica.equippable:IsEquipped() then
			elseif item then
				SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, item, nil, nil)
			end
			if distsq(ThePlayer:GetPosition(), act.target:GetPosition()) < 0.2 ^ 2 then
				local pos = POS_util:CalculateAimPos(act.target:GetPosition(), ThePlayer:GetPosition(), 0, 2)
				SendRPCToServer(RPC.LeftClick, ACTIONS.WALKTO.code, pos.x,
					pos.z)
				Sleep(0.5)
				return
			end
			do
				if ActionQueuer.performaction then
					local doer_rotation = ThePlayer.Transform:GetRotation()
					local facing = Vector3(math.cos(-doer_rotation / RADIANS), 0, math.sin(-doer_rotation / RADIANS))
					if IsWithinAngle(ThePlayer:GetPosition(), facing, TUNING.VOIDCLOTH_SCYTHE_HARVEST_ANGLE_WIDTH,
							act.target:GetPosition()) then
						Sleep(0.5)
						local pos = POS_util:CalculateAimPos(act.target:GetPosition(), ThePlayer:GetPosition(), 90 *
							DEGREES, 2)
						SendRPCToServer(RPC.LeftClick, ACTIONS.WALKTO.code, pos.x,
							pos.z)
						Sleep(0.5)
						ActionQueuer.performaction = false
					end
				end
			end
			SendRPCToServer(RPC.LeftClick, ACTIONS.SCYTHE.code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, ACTIONS.SCYTHE.canforce, ACTIONS.SCYTHE.mod_name)
		end,
		--[[ez_listenperformaction = true,]]
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "USEITEM", "SCYTHE", act)
		end,
		breakfn = function(act)
			--target:HasOneOfTags(HARVESTABLE_PLANT_TARGET_TAGS)
			return not act.target or not act.target:HasTag('pickable')
		end,
		reselectfn = function(act)
			for k, v in pairs(ActionQueuer.selected_ents) do
				if k and not k:HasTag('pickable') then
					ActionQueuer:DeselectEntity(k)
				end
			end
		end
	},
	--pos_act
	['DROP'] = { --一点丢东西
		isposaction = true,
		insertpos = false,
		oneclickapply = false,
		isleftclick = true,
		canselect = function(ent)
			return ent == nil --drop在getaction里面传入的target是nil
		end,
		rpc = function(act)
			SendRPCToServer(RPC.LeftClick, ACTIONS.DROP.code, act.target:GetPosition().x,
				act.target:GetPosition().z)
		end,
	},
	['DEPLOY_TILEARRIVE'] = { --施肥
		isposaction = true,
		frameselect = true,
		insertpos = true,
		oneclickapply = true,
		isleftclick = false,
		rpc = function(act)
			local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(act.target:GetPosition().x, 0,
				act.target:GetPosition().z))
			local playerpos = Point(TheWorld.Map:GetTileCenterPoint(ThePlayer:GetPosition().x, 0,
				ThePlayer:GetPosition().z))
			if playerpos.x == tilecenter.x and playerpos.z == tilecenter.z then
				SendRPCToServer(RPC.ControllerActionButtonDeploy, act.item, ThePlayer:GetPosition().x,
					ThePlayer:GetPosition().z)
			else
				SendRPCToServer(RPC.ControllerActionButtonDeploy, act.item, act.target:GetPosition().x,
					act.target:GetPosition().z)
			end
		end,
		breakfn = function(act)
			if not IsBusy() or act.time < 1 then
				return false
			end
			local nutrient
			local xx, zz = act.target:GetPosition().x, act.target:GetPosition().z
			for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(xx, 0, zz)) do
				if ent.prefab == "nutrients_overlay" then
					nutrient = ent
					break
				end
			end
			if (not act.target.lasttime or GetTime() - act.target.lasttime > 1) and nutrient and nutrient.nutrientlevels and nutrient.nutrientlevels:value() then
				if act.target.nutrient == nutrient.nutrientlevels:value() then
					return true
				end
				act.target.lasttime = GetTime()
				act.target.nutrient = nutrient.nutrientlevels:value()
			end
		end,
		reselectfn = function(act)
			if act.target ~= ActionQueuer.posaction then return end
			act.target.nutrient = nil
			local mindistsq, target, lastaction
			local player_pos = ThePlayer:GetPosition()
			local x, z = act.target:GetPosition().x, act.target:GetPosition().z
			for k, v in pairs(posaction_postab) do
				if k.x == x and k.z == z or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then
					posaction_postab[k] = nil
				elseif v == 'DEPLOY_TILEARRIVE' then
					local curdistsq = distsq(k, player_pos)
					if not mindistsq or curdistsq < mindistsq then
						mindistsq = curdistsq
						target = k
					end
				else
					lastaction = { pos = k, id = v }
				end
			end
			if target then
				act.target.Transform:SetPosition(target.x, 0, target.z)
				ActionQueuer:SelectEntity(act.target, 'DEPLOY_TILEARRIVE', act.item, nil, true)
			end
		end,
		controllertable = {},
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "POINT", "DEPLOY_TILEARRIVE", act)
		end,
	},
	['TERRAFORM'] = { --挖地皮
		isposaction = true,
		frameselect = true,
		insertpos = true,
		oneclickapply = true,
		isleftclick = false,
		rpc = function(act)
			local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(act.target:GetPosition().x, 0,
				act.target:GetPosition().z))
			local playerpos = Point(TheWorld.Map:GetTileCenterPoint(ThePlayer:GetPosition().x, 0,
				ThePlayer:GetPosition().z))
			if playerpos.x == tilecenter.x and playerpos.z == tilecenter.z then
				if act.time < 0.1 or act.time > 1 then
					SendRPCToServer(RPC.RightClick, ACTIONS.TERRAFORM.code, ThePlayer:GetPosition().x,
						ThePlayer:GetPosition().z)
				end
			else
				if not IsBusy() or act.time < 0.1 then
					SendRPCToServer(RPC.RightClick, ACTIONS.TERRAFORM.code, act.target:GetPosition().x,
						act.target:GetPosition().z)
				end
			end
		end,
		reselectfn = function(act)
			if act.target ~= ActionQueuer.posaction then return end
			if ActionQueuer.posaction and ActionQueuer.posaction.endlessaction then --双击挖地皮流程
				local ground = act.target and
					act.target
					.ground --来自ActionQueuer.posaction的ground
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				--ActionQueuer.posaction
				for k, v in pairs({ { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, }) do
					if TheWorld.Map:GetTileAtPoint(x + v[1] * 4, 0, z + v[2] * 4) == ground then
						act.target.Transform:SetPosition(x + v[1] * 4, 0, z + v[2] * 4)
						ActionQueuer:SelectEntity(act.target, 'TERRAFORM', nil, nil, true)
						return
					end
				end
				for k, v in pairs({ { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, }) do
					if TheWorld.Map:GetTileAtPoint(x + v[1] * 8, 0, z + v[2] * 8) == ground then
						act.target.Transform:SetPosition(x + v[1] * 8, 0, z + v[2] * 8)
						ActionQueuer:SelectEntity(act.target, 'TERRAFORM', nil, nil, true)
						return
					end
				end
			else
				local mindistsq, target, lastaction
				local player_pos = ThePlayer:GetPosition()
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				for k, v in pairs(posaction_postab) do
					if k.x == x and k.z == z or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then
						posaction_postab[k] = nil
					elseif v == 'TERRAFORM' and TheWorld.Map:GetTileAtPoint(k.x, 0, k.z) == 4 then
						posaction_postab[k] = nil
					elseif v == 'TERRAFORM' then
						local curdistsq = distsq(k, player_pos) -- 点距
						if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
							mindistsq = curdistsq
							target = k
						end
					else
						lastaction = { pos = k, id = v }
					end
				end
				if target then
					act.target.Transform:SetPosition(target.x, 0, target.z)
					ActionQueuer:SelectEntity(act.target, 'TERRAFORM', nil, nil, true)
				end
			end
		end,
		breakfn = function(act)
			local x, z = act.target:GetPosition().x, act.target:GetPosition().z
			if TheWorld.Map:GetTileAtPoint(x, 0, z) == 4 then
				return true
			end
		end,
		addtimefn = function(act)
			local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(act.target:GetPosition().x, 0,
				act.target:GetPosition().z))
			local playerpos = Point(TheWorld.Map:GetTileCenterPoint(ThePlayer:GetPosition().x, 0,
				ThePlayer:GetPosition().z))
			if playerpos.x == tilecenter.x and playerpos.z == tilecenter.z then
				return true
			end
		end
	},
	--[[['TILL'] = { --耕地
		isposaction = true,
		frameselect = true,
		selectposaction = function(pos)
			local x, z
			local tilecenter = _G.Point(_G.TheWorld.Map:GetTileCenterPoint(pos.x, 0,
				pos.z)) -- center of tile
			if math.abs(pos.x - tilecenter.x) < 2 / 3 then
				x = tilecenter.x
			elseif pos.x > tilecenter.x then
				x = tilecenter.x + farm_spacing
			else
				x = tilecenter.x - farm_spacing
			end
			if math.abs(pos.z - tilecenter.z) < 2 / 3 then
				z = tilecenter.z
			elseif pos.z > tilecenter.z then
				z = tilecenter.z + farm_spacing
			else
				z = tilecenter.z - farm_spacing
			end
			return Vector3(x, 0, z)
		end,
		insertpos = true,
		oneclickapply = true,
		isleftclick = false,
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.RightClick, ACTIONS.TILL.code, act.target:GetPosition().x,
					act.target:GetPosition().z)
			end
		end,
		reselectfn = function(act)
			if act.target ~= ActionQueuer.posaction then return end
			if ActionQueuer.posaction and ActionQueuer.posaction.endlessaction then --双击挖地皮流程
				local ground = act.target and
					act.target
					.ground --来自ActionQueuer.posaction的ground
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				--ActionQueuer.posaction
				for k, v in pairs({ { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, }) do
					local select = true
					for _, ent in pairs(TheSim:FindEntities(x + v[1] * farm_spacing, 0, z + v[2] * farm_spacing, 0.2, { "soil" })) do
						if not ent:HasTag("NOCLICK") then
							select = false
							break
						end
					end
					if select and TheWorld.Map:GetTileAtPoint(x + v[1] * farm_spacing, 0, z + v[2] * farm_spacing) == ground then
						act.target.Transform:SetPosition(x + v[1] * farm_spacing, 0, z + v[2] * farm_spacing)
						ActionQueuer:SelectEntity(act.target, 'TILL', nil, nil, true)
						return
					end
				end
			else
				local mindistsq, target, lastaction
				local player_pos = ThePlayer:GetPosition()
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				for k, v in pairs(posaction_postab) do
					if k.x == x and k.z == z
						or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then --筛选出已经挖过的
						posaction_postab[k] = nil
					elseif v == 'TILL' and ActionQueuer:GetAction(nil, 'TILL', true, nil, k) then
						local curdistsq = distsq(k, player_pos) -- 点距
						if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
							mindistsq = curdistsq
							target = k
						end
					else
						lastaction = { pos = k, id = v }
					end
				end
				if target then
					act.target.Transform:SetPosition(target.x, 0, target.z)
					ActionQueuer:SelectEntity(act.target, 'TILL', nil, nil, true)
				end
			end
		end,
		breakfn = function(act)
			local x, z = act.target:GetPosition().x, act.target:GetPosition().z
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, 1)) do
				if act.time > 0.2 and ent.spawntime and GetTime() - ent.spawntime < 0.2 and ent:HasTag("soil") then
					return true
				end
			end
		end,
	},]]
	['POUR_WATER_GROUNDTILE'] = { --浇水
		isposaction = true,
		frameselect = true,
		insertpos = true,
		oneclickapply = true,
		isleftclick = false,
		rpc = function(act)
			local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(act.target:GetPosition().x, 0,
				act.target:GetPosition().z))
			local playerpos = Point(TheWorld.Map:GetTileCenterPoint(ThePlayer:GetPosition().x, 0,
				ThePlayer:GetPosition().z))
			if playerpos.x == tilecenter.x and playerpos.z == tilecenter.z then
				SendRPCToServer(RPC.RightClick, ACTIONS.POUR_WATER_GROUNDTILE.code, ThePlayer:GetPosition().x,
					ThePlayer:GetPosition().z)
			else
				SendRPCToServer(RPC.RightClick, ACTIONS.POUR_WATER_GROUNDTILE.code, act.target:GetPosition().x,
					act.target:GetPosition().z)
			end
		end,
		reselectfn = function(act)
			if act.target ~= ActionQueuer.posaction then return end
			if ActionQueuer.posaction and ActionQueuer.posaction.endlessaction then
				local ground = act.target and act.target.ground
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				for k, v in pairs({ { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, }) do
					if TheWorld.Map:GetTileAtPoint(x + v[1] * 4, 0, z + v[2] * 4) == ground then
						local moisture
						local xx, zz = x + v[1] * 4, z + v[2] * 4
						for _, ent in pairs(TheWorld.Map:GetEntitiesOnTileAtPoint(xx, 0, zz)) do
							if ent.prefab == "nutrients_overlay" then -- Look for tile's nutrients_overlay entity, that contains moisture data
								moisture = ent
								break
							end
						end
						if moisture and moisture.AnimState and moisture.AnimState:GetCurrentAnimationTime() < 0.9 then
							act.target.Transform:SetPosition(x + v[1] * 4, 0, z + v[2] * 4)
							ActionQueuer:SelectEntity(act.target, 'POUR_WATER_GROUNDTILE', nil, nil, true)
							return
						end
					end
				end
			else
				local mindistsq, target, lastaction
				local player_pos = ThePlayer:GetPosition()
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				for k, v in pairs(posaction_postab) do
					if k.x == x and k.z == z or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then
						posaction_postab[k] = nil
					elseif v == 'POUR_WATER_GROUNDTILE' and TheWorld.Map:GetTileAtPoint(k.x, 0, k.z) ~= 47 then
						posaction_postab[k] = nil
					elseif v == 'POUR_WATER_GROUNDTILE' then
						local curdistsq = distsq(k, player_pos) -- 点距
						if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
							mindistsq = curdistsq
							target = k
						end
					else
						lastaction = { pos = k, id = v }
					end
				end
				if target then
					act.target.Transform:SetPosition(target.x, 0, target.z)
					ActionQueuer:SelectEntity(act.target, 'POUR_WATER_GROUNDTILE', nil, nil, true)
				end
			end
		end,
		breakfn = function(act)
			local moisture
			local x, z = act.target:GetPosition().x, act.target:GetPosition().z
			for _, ent in pairs(_G.TheWorld.Map:GetEntitiesOnTileAtPoint(x, 0, z)) do
				if ent.prefab == "nutrients_overlay" then -- Look for tile's nutrients_overlay entity, that contains moisture data
					moisture = ent
					break
				end
			end
			if not moisture or type(moisture) ~= "table" or not moisture.AnimState then return true end

			if moisture.AnimState:GetCurrentAnimationTime() >= 0.9 then
				return true
			end
		end,
		tool = function(item)
			--wateryprotection
			if not item or not ActionQueuer:HasActionComponent(item, "wateryprotection") then return end
			local i = 100
			local classified = item and item.replica and item.replica.inventoryitem and
				item.replica.inventoryitem.classified
			if classified and classified.percentused then
				i = classified.percentused:value()
			end
			return i ~= 0
		end,
	},
	['DEPLOY'] = {
		isposaction = true,
		frameselect = true,
		insertpos = true,
		oneclickapply = true,
		isleftclick = false,
		reselectfn = function(act)
			if act.target ~= ActionQueuer.posaction then return end
			if act.item and act.item:HasTag('groundtile') then
				if ActionQueuer.posaction and ActionQueuer.posaction.endlessaction then
					local x, z = act.target:GetPosition().x, act.target:GetPosition().z
					for k, v in pairs({ { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, }) do
						if TheWorld.Map:GetTileAtPoint(x + v[1] * 4, 0, z + v[2] * 4) == 4 then
							act.target.Transform:SetPosition(x + v[1] * 4, 0, z + v[2] * 4)
							ActionQueuer:SelectEntity(act.target, 'DEPLOY', act.item, nil, true)
							return
						end
					end
				else
					local mindistsq, target, lastaction
					local player_pos = ThePlayer:GetPosition()
					local x, z = act.target:GetPosition().x, act.target:GetPosition().z
					for k, v in pairs(posaction_postab) do
						if k.x == x and k.z == z or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then
							posaction_postab[k] = nil
						elseif v == 'DEPLOY' and TheWorld.Map:GetTileAtPoint(k.x, 0, k.z) ~= 4 then
							posaction_postab[k] = nil
						elseif v == 'DEPLOY' then
							local curdistsq = distsq(k, player_pos) -- 点距
							if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
								mindistsq = curdistsq
								target = k
							end
						else
							lastaction = { pos = k, id = v }
						end
					end
					if target then
						act.target.Transform:SetPosition(target.x, 0, target.z)
						ActionQueuer:SelectEntity(act.target, 'DEPLOY', act.item, nil, true)
					end
				end
			elseif act.item and act.item.prefab == 'minisign_item' then
				local mindistsq, target, lastaction
				local player_pos = ThePlayer:GetPosition()
				local x, z = act.target:GetPosition().x, act.target:GetPosition().z
				for k, v in pairs(posaction_postab) do
					if k.x == x and k.z == z or math.abs(k.x - x) + math.abs(k.z - z) < 0.01 then
						posaction_postab[k] = nil
					elseif v == 'DEPLOY' then
						local curdistsq = distsq(k, player_pos) -- 点距
						if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
							mindistsq = curdistsq
							target = k
						end
					else
						lastaction = { pos = k, id = v }
					end
				end
				if target then
					act.target.Transform:SetPosition(target.x, 0, target.z)
					ActionQueuer:SelectEntity(act.target, 'DEPLOY', act.item, nil, true)
				end
			end
		end,
		breakfn = function(act)
			local x, z = act.target:GetPosition().x, act.target:GetPosition().z
			if act.item and act.item:HasTag('groundtile') then
				if TheWorld.Map:GetTileAtPoint(x, 0, z) ~= 4 then
					return true
				end
			elseif act.item and act.item.prefab == 'minisign_item' then
				local e = ActionQueuer.posaction and ActionQueuer.posaction.ent
				if e and e.prefab == 'minisign' then return false end --对着小木牌将会一直在一个点插
				for _, ent in pairs(TheSim:FindEntities(act.target:GetPosition().x, 0, act.target:GetPosition().z, 1)) do
					if ent.spawntime and GetTime() - ent.spawntime < 0.1 and ent.prefab == 'minisign' and act.time > 0.15 then
						return true
					end
				end
			end
		end,
		canselect = function(target, self)
			local active = INV_util:GetActiveItem()
			local ent = self.posaction and self.posaction.ent or TheInput:GetWorldEntityUnderMouse()
			if active and active:HasTag('groundtile') then
				return true
			end
			if active and active.prefab == 'minisign_item'
			--[[ and ent and ent.prefab == 'minisign' ]] then -- 种植小木牌的
				return true
			end
		end,
		rpc = function(act)
			if act.item and act.item:HasTag('groundtile') then
				if not IsBusy() or act.time < 0.1 then
					local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(act.target:GetPosition().x, 0,
						act.target:GetPosition().z))
					local playerpos = Point(TheWorld.Map:GetTileCenterPoint(ThePlayer:GetPosition().x, 0,
						ThePlayer:GetPosition().z))
					if playerpos.x == tilecenter.x and playerpos.z == tilecenter.z then
						SendRPCToServer(RPC.ControllerActionButtonDeploy, act.item, ThePlayer:GetPosition().x,
							ThePlayer:GetPosition().z)
					else
						SendRPCToServer(RPC.ControllerActionButtonDeploy, act.item, act.target:GetPosition().x,
							act.target:GetPosition().z)
					end
				end
			else
				if not IsBusy() or act.time < 0.1 or act.time > 0.5 then
					SendRPCToServer(RPC.ControllerActionButtonDeploy, act.item, act.target:GetPosition().x,
						act.target:GetPosition().z)
				end
			end
		end,
		controllertable = {},
		controllercanselect = function(act)
			act.right = true
			return ActionQueuer:collectActions(act.item, "POINT", "DEPLOY", act)
		end,

		addtimefn = custom_addtimefn(4)
	},
	--pos_act

	["FILL"] = {
		rpc = custom_rpc('FILL'),
		tool = function(item)
			if not item or not item:HasTag('fillable') then return end
			local i = 100
			local classified = item and item.replica and item.replica.inventoryitem and
				item.replica.inventoryitem.classified
			if classified and classified.percentused then
				i = classified.percentused:value()
			end
			return i ~= 100
		end,
	},
	["HAUNT"] = {
		rpc = custom_rpc('HAUNT'),
		reselectfn = function(act) --选择护符或者二次表作祟
			if ActionQueuer:HaveAnotherSelectedEnt(act.target) then
				return
			end
			local watch
			for _, ent in pairs(TheSim:FindEntities(act.target:GetPosition().x, 0, act.target:GetPosition().z, 4)) do
				if ent and ent.prefab == 'amulet' then
					ActionQueuer:SelectEntity(ent, 'HAUNT')
					return
				elseif ent and ent.prefab == 'pocketwatch_revive' then
					watch = ent
				end
			end
			if ThePlayer.prefab == 'wanda' and watch then
				ActionQueuer:SelectEntity(watch, 'HAUNT')
				return
			end
		end,
	},
	["FERTILIZE"] = {
		rpc = function(act)
			if ThePlayer:HasTag("self_fertilizable") and act.time >= 0.1 then
				if act.target == ThePlayer then
					ActionQueuer:SendControllerRPCSafely(ACTIONS["FERTILIZE"].code, act.item, act.target)
				end
			else
				ActionQueuer:SendControllerRPCSafely(ACTIONS["FERTILIZE"].code, act.item, act.target)
			end
		end,
		controllertable = {},
		act_pre_fn = function(act, self) --负重
			if act.target and act.target.prefab == 'fwd_in_pdt_plant_coffeebush' then
				for k, v in pairs(ActionQueuer.selected_ents) do
					if k and k.AnimState and not k.AnimState:IsCurrentAnimation("idle_dead") then
						ActionQueuer:DeselectEntity(k)
					end
				end
			end
		end,
		breakfn = function(act)
			return act.target and act.target.prefab == 'fwd_in_pdt_plant_coffeebush' and
				not act.target.AnimState:IsCurrentAnimation("idle_dead")
		end,
	},
	["JUMPIN"] = {
		dontselectbyselectbox = true,
		rpc = custom_rpc('JUMPIN'),
		reselectfn = function(act)
			for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 4, nil)) do
				if ent.prefab == "wormhole" then
					ActionQueuer:SelectEntity(ent, "JUMPIN")
				end
			end
		end,
	},
	["DRY"] = {
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				ActionQueuer:SendControllerRPCSafely(ACTIONS["DRY"].code, act.item, act.target)
			end
		end,
		controllertable = {},
	},

	['RUMMAGE'] = {
		--only double click
		dontselectbyselectbox = true,
		equipspeeditem = true,
		isleftclick = true,
		--[[canselect = function(target, self)
			return rawget(_G, 'mmdx_data')
		end,]]
		rpc = function(act)
			if not IsBusy() or act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS.RUMMAGE.code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS["RUMMAGE"].canforce, ACTIONS["RUMMAGE"].mod_name)
			end
		end,
		breakfn = function(act)
			return act.target and act.target.replica.container and
				act.target.replica.container:IsOpenedBy(ThePlayer)
				or act.target and act.target.prefab == 'magician_chest' and
				not act.target.AnimState:IsCurrentAnimation("closed")
		end,
		meatrack_list = { meatrack = 1, meatrack_hermit = 1, meatrack_hermit_multi = 1, ocean_trawler = 1, },
		reselectfn = function(act)
		end,
		exit_loop_fn = function(act)
			if act.target and act.target.prefab and allowed_actions.RUMMAGE.meatrack_list[act.target.prefab] then
				local num = act.target.replica.container and act.target.replica.container:GetNumSlots() or 3
				for i = 1, num do
					SendRPCToServer(RPC.MoveItemFromAllOfSlot, i, act.target)
				end
				act.target:DoTaskInTime(2 * FRAMES, function()
					for i = 1, num do
						SendRPCToServer(RPC.MoveItemFromAllOfSlot, i, act.target)
					end
				end)
			end
		end,
	},
	['MIGRATE'] = {
		dontselectbyselectbox = true,
		act_pre_fn = function(act, self)
			SendRPCToServer(RPC.LeftClick, ACTIONS['MIGRATE'].code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, ACTIONS['MIGRATE'].canforce, ACTIONS['MIGRATE'].mod_name)
			local cursed_monkey_token, pos = INV_util:FindInInventory('cursed_monkey_token')
			if not cursed_monkey_token then return end
			local backpack = ThePlayer.replica.inventory:GetOverflowContainer()
			for k, v in pairs(backpack and backpack:GetItems() or {}) do
				SendRPCToServer(RPC.MoveItemFromAllOfSlot, k, backpack.inst, nil)
			end
			for k, v in pairs(ThePlayer.replica.inventory:GetItems()) do
				if v.prefab ~= 'cursed_monkey_token' and v.replica.stackable and v.replica.stackable:StackSize() > 1 then
					SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, k)
					SendRPCToServer(RPC.PutOneOfActiveItemInSlot, k)
					local a
					for i = 1, ThePlayer.replica.inventory:GetNumSlots() do
						if not ThePlayer.replica.inventory:GetItemInSlot(i) then
							a = true
							SendRPCToServer(RPC.PutAllOfActiveItemInSlot, i)
							break
						end
					end
					if not a then
						break
					end
				end
			end
			SendRPCToServer(RPC.SwapActiveItemWithSlot, pos)
		end,
		rpc = custom_rpc('MIGRATE'),
	},
	['MEDALCHANGEDESTINY'] = {
		rpc       = function(act)
			if act.time < 0.1 then
				SendRPCToServer(RPC.LeftClick, ACTIONS['MEDALCHANGEDESTINY'].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS['MEDALCHANGEDESTINY'].canforce, ACTIONS['MEDALCHANGEDESTINY'].mod_name)
			end
		end,
		breakfn   = function(act)
			return act.time > 0.5
		end,
		addtimefn = custom_addtimefn(2 * 2),
	},
	['LOOKAT'] = _G.rawget(_G, 'REFORGED_SETTINGS') and {
		isleftclick = true,
		dontselectbyselectbox = true,
		rpc = custom_rpc('LOOKAT'),
	} or {
		isleftclick = false,
		dontselectbyselectbox = true,
		canselect = function(target, self)
			local inventory = self.inst and self.inst.replica.inventory
			local rosehat = inventory and inventory:EquipHasTag("roseglassesvision")
			return rosehat and target and target:HasTag("flower")
		end,
		notbreakfn = function(act)
			return true
		end,
		breakfn = function(act)
			return act.target and act.target.client_forward_target
		end,
		rpc = function(act)
			SendRPCToServer(RPC.LeftClick, ACTIONS['LOOKAT'].code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, 1, ACTIONS['LOOKAT'].canforce, ACTIONS['LOOKAT'].mod_name)
		end,
	},
	["ADDCOMPOSTABLE"] = {
		rpc = custom_rpc('ADDCOMPOSTABLE'),
		-- return act.time > 0.5
		addtimefn = custom_addtimefn(3 * 3),
		--stacknumdirtyezsylisten = true, stacknumdirty
		breakfn = function(act)
			return not ActionQueuer:HaveAnotherSelectedEnt(act.target) and act.time > 5
				or ActionQueuer:HaveAnotherSelectedEnt(act.target) and act.time > 3
		end,
	},
	['OPEN_CRAFTING'] = {
		dontselectbyselectbox = true,
		isleftclick = true,
		rpc = custom_rpc('OPEN_CRAFTING'),
	},
	["TOSS"] = {
		rpc = custom_rpc('TOSS'),
		breakfn = function(act)
			return ActionQueuer:HaveAnotherSelectedEnt(act.target, function()
				return act.time > 0.5
			end)
		end,
		addtimefn = custom_addtimefn(8 * 8),
	},
	["DISMANTLE"] = { --这个动作是"portablestructure"组件的
		act_pre_fn = function(act, self)
			if act.target then
				act.target.rememberpos = act.target:GetPosition()
			end
		end,
		rpc = custom_rpc('DISMANTLE'),
		allowautocollect = true,
		markfn = function(ent, target)
			if ent and ent.prefab == "winona_battery_high_item" then
				local pos = target.rememberpos
				ent.deploypos = Vector3(pos.x, 0, pos.z)
			end
		end,
	},
	--"TAKEITEM"
	TAKEITEM = {
		dontselectbyselectbox = true,
		rpc = custom_rpc("TAKEITEM")
	},
	GRAVEDIG = {
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS.GRAVEDIG.code, act.item, act.target, ACTIONS.GRAVEDIG.mod_name)
		end,
		selectitemfn = function(obj)
			return ActionQueuer:HasActionComponent(obj, "gravedigger")
		end,
		controllertable = { needreturnactiveitem = true },
	},
	FEED = {
		rpc = custom_rpc("FEED"),
		stacknumdirtyezsylisten = true,
	},
	STARTELECTRICLINK = {
		rpc = custom_rpc("STARTELECTRICLINK"),
		ez_listenperformaction = true,
	},
}
if _G.rawget(_G, 'REFORGED_SETTINGS') then
	allowed_actions.ATTACK = nil
end
for k, v in pairs({ "PLANTREGISTRY_RESEARCH",
	"RESETMINE", "TURNON", "TURNOFF", "UNWRAP",
	"POUR_WATER", 'EXTEND_PLANK', 'RETRACT_PLANK', 'STARTCHANNELING',
	"PLANT", "RAISE_SAIL", "REPAIR",
	"HARVEST", 'BOAT_CANNON_START_AIMING', 'BOAT_CANNON_LOAD_AMMO',
	"INTERACT_WITH", 'CHECKTRAP', "ADVANCE_TREE_GROWTH",
	'DRAW', 'COMBINESTACK', "JUMPIN",
	'DOINGOLD', 'USEKLAUSSACKKEY', 'ATTUNE', 'WAX', 'SMOTHER',
	"OCEAN_TRAWLER_FIX", 'OCEAN_TRAWLER_RAISE', 'OCEAN_TRAWLER_LOWER', "BEDAZZLE", 'TEACH' }) do --普通动作
	allowed_actions[v] = allowed_actions[v] or {
		rpc = custom_rpc(v)
	}
end
for k, v in pairs({ 'DISMANTLE_POCKETWATCH', "COOK", "SEW", "UPGRADE" }) do --控制器rpc
	allowed_actions[v] = allowed_actions[v] or {
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS[v].code, act.item, act.target, ACTIONS[v].mod_name)
		end,
		controllertable = {},
	}
end
local function addaction(actionid, rpctype, actiontab)
	actionid = actionid or 'NONE'
	allowed_actions[actionid] = allowed_actions[actionid] or actiontab or rpctype == 'CONTROLLER' and {
		rpc = function(act)
			ActionQueuer:SendControllerRPCSafely(ACTIONS[actionid].code, act.item,
				act.target, ACTIONS[actionid].mod_name)
		end,
		controllertable = {}
	} or {
		rpc = function(act)
			SendRPCToServer(RPC.LeftClick, ACTIONS[actionid].code, act.target:GetPosition().x,
				act.target:GetPosition().z,
				act.target, nil, nil, ACTIONS[actionid].canforce, ACTIONS[actionid].mod_name)
		end,
	}
end
local function addactionlist(actionidtab, rpctype)
	actionidtab = actionidtab or {}
	for k, v in pairs(actionidtab) do
		addaction(v, rpctype)
	end
end
addactionlist({ 'REPAIR_LEGION', 'POWERABSORB', 'BOTTLESSOUL', 'POWERPRINT', 'REPAIRCOMMON', 'MEDALSTAFFDEVOUR',
	'DOPROPHESY', 'GRAFTING_TREE', 'MEDALNORMALTRANSPLANT', 'FISHMOONINWATER', 'USE_UPGRADEKIT', 'MEDALMAKEVARIATION', })
local function addallactions()
	local custom_act = function(actionid)
		return {
			dontselectbyselectbox = true,
			rpc = function(act)
				SendRPCToServer(RPC.LeftClick, ACTIONS[actionid].code, act.target:GetPosition().x,
					act.target:GetPosition().z,
					act.target, nil, nil, ACTIONS[actionid].canforce, ACTIONS[actionid].mod_name)
			end,
		}
	end
	for k, v in pairs(ACTION_MOD_IDS) do
		for kk, actionid in pairs(v) do
			allowed_actions[actionid] = allowed_actions[actionid] or custom_act(actionid)
		end
	end
	local banactions = { "WALKTO", "LOOKAT" }
	for k, v in pairs(ACTIONS) do
		if not allowed_actions[k] and not table.contains(banactions, k) then --
			allowed_actions[k] = allowed_actions[k] or custom_act(k)
		end
	end
end
MOD_util:DoTaskInTime(0, addallactions)
--
-- Shift右键粘贴 【蜘蛛巢已经不能种在蜘蛛巢上了，排队论过时啦】
local easy_stack = { minisign_item = "structure", minisign_drawn = "structure", spidereggsack = "spiderden" }
-- 部署间隔

local deploy_spacing = { wall = 1, fence = 1, trap = 1.5, mine = 2, turf = 4, moonbutterfly = 4 }
local action_spacing = { TILL = farm_spacing, TERRAFORM = 4, DROP = 1, POUR_WATER_GROUNDTILE = 4, DEPLOY_TILEARRIVE = 4, DEPLOY = 2 }
-- 类似特效、无法点击的、玩家等不能被选中
local unselectable_tags = { "DECOR", "FX", "INLIMBO", --[[  "NOCLICK", ]] "player" }

local offsets = {}
for i, offset in pairs({ { 0, 0 }, { 0, 1 }, { 1, 1 }, { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, -1 }, { -1, 0 }, { -1, 1 } }) do
	offsets[i] = Point(offset[1] * 1.5, 0, offset[2] * 1.5)
end
local farm3x3_offset = farm_spacing / 2
local double_snake = true
--框选相关
function ActionQueuer:creatSelectionWidget()
	if self.selection_widget then
		self.selection_widget:Kill()
	end
	self.selection_widget = Image("images/selection_square.xml", "selection_square.tex")
	self.selection_widget:Hide()
	return self.selection_widget
end

function ActionQueuer:hideSelectionWidget()
	self.selection_widget:Hide()
end

function ActionQueuer:SetSelectionPosition(xmin, xmax, ymin, ymax)
	self.selection_widget:SetPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
	self.selection_widget:SetSize(xmax - xmin + 2, ymax - ymin + 2)
	if MOD_util:GetMOption("aq_selectwidget", default_aq_selectwidget) then
		self.selection_widget:Show()
	end
end

function ActionQueuer:SetSelectionColor(r, g, b, a)
	if self.selection_widget then
		self.selection_widget:SetTint(r, g, b, a)
	end
	if self.color then
		self.color.x = r * 0.5
		self.color.y = g * 0.5
		self.color.z = b * 0.5
	end
end

function ActionQueuer:UpdateSelectionColor()
	local r, g, b
	r = MOD_util:GetMOption("aq_selectwidget_r", default_aq_selectwidget_r)
	g = MOD_util:GetMOption("aq_selectwidget_g", default_aq_selectwidget_g)
	b = MOD_util:GetMOption("aq_selectwidget_b", default_aq_selectwidget_b)
	r = r / 255
	g = g / 255
	b = b / 255
	local default_selection_opacity = MOD_util:GetMOption("aq_selectwidget_opacity", default_aq_selectwidget_opacity)
	self:SetSelectionColor(r, g, b, default_selection_opacity)
end

function ActionQueuer:InitFn(inst)
	ThePlayer:ListenForEvent("performaction", function(inst, data)
		self.performaction = true
	end)

	self.inst = inst

	self:creatSelectionWidget()

	self.clicked = false
	self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
	TheInput:AddMoveHandler(function(x, y)
		self.screen_x, self.screen_y = x, y
		self.queued_movement = true
	end)
	--Maps ent to key and rightclick(true or false) to value
	self.selected_ents = {}
	self.selection_thread = nil
	self.action_thread = nil
	self.action_delay = FRAMES * 3
	self.work_delay = FRAMES * 6
	-- self.color = { x = 0.5, y = 0.5, z = 0.5 }
	self.color = { x = 207 / 255, y = 61 / 255, z = 61 / 255 }
	self.deploy_on_grid = false
	self.deploy_hint_markers = {}
	self.deploy_hint_count = 0
	self.endless_deploy = MOD_util:GetMOption("aq_endless_deploy", default_aq_endless_deploy) or false
	self.last_click = { time = 0 }
	self.double_click_speed = 0.3
	self.double_click_range = 20
	self.control_click_range = 20
	self.autocollect = MOD_util:GetMOption("aq_autocollect", default_aq_autocollect) or 1 --收集模式
	self.posaction = nil
end

local function canusecontroller(position, item, target, actionid)
	--author_print(position, item, target, actionid)
	--left
	local function dofind(isright)
		local playeractionpicker = ThePlayer.components.playeractionpicker
		local actions = nil
		local useitem = item
		if useitem ~= nil then
			if useitem:IsValid() then
				if target == ThePlayer then
					actions = playeractionpicker:GetInventoryActions(useitem, isright)
				elseif target ~= nil and not target:HasTag("walkableplatform") and not target:HasTag("ignoremouseover") then
					actions = playeractionpicker:GetUseItemActions(target, useitem, isright)
					if #actions == 0 and target:HasTag("walkableperipheral") then
						actions = playeractionpicker:GetPointActions(position, useitem, isright, target)
					end
				else
					actions = playeractionpicker:GetPointActions(position, useitem, isright, target)
				end
			end
		end
		for k, v in pairs(actions or {}) do
			local id = v and v.action and v.action.id
			if actionid == id then
				return v
			end
		end
	end
	do
		local r = dofind()
		if r then return r end
	end
	do
		local r = dofind(true)
		if r then return r end
	end
	--right
end
-- HUD
local function IsHUDEntity()
	local ent = TheInput:GetWorldEntityUnderMouse()
	return ent and ent:HasTag("INLIMBO") or TheInput:GetHUDEntityUnderMouse()
end

-- 将屏幕坐标转化为世界坐标
local function GetWorldPosition(screen_x, screen_y)
	return Point(TheSim:ProjectScreenPos(screen_x, screen_y))
end



-- 比较实体的原版部署间隔与给定的间隔
local function CompareDeploySpacing(item, spacing)
	return item and item.replica.inventoryitem and item.replica.inventoryitem.classified
		and item.replica.inventoryitem.classified.deployspacing:value() == spacing
end

-- 获取固定的视角角度与对应的布尔值
local function GetHeadingDir()
	local dir = headings[TheCamera.heading]
	if dir ~= nil then return TheCamera.heading, dir end
	for heading, dir in pairs(headings) do --diagonal priority
		local check_angle = heading % 2 ~= 0 and 23 or 22.5
		if math.abs(TheCamera.heading - heading) < check_angle then
			return heading, dir
		end
	end
end

-- 获取可用地皮焦点
local function GetAccessibleTilePosition(pos)
	local ent_blockers = TheSim:FindEntities(pos.x, 0, pos.z, 4, { "blocker" })
	for _, offset in pairs(offsets) do
		local offset_pos = offset + pos
		for _, ent in pairs(ent_blockers) do
			local ent_radius = ent:GetPhysicsRadius(0) + ThePlayer:GetPhysicsRadius(0) + 0.1 --character size + 0.1
			if offset_pos:DistSq(ent:GetPosition()) < ent_radius * ent_radius then
				offset_pos = nil
				break
			end
		end
		if offset_pos then return offset_pos end
	end
	return nil
end
function ActionQueuer:HaveAnotherSelectedEnt(now, fn)
	for k, v in pairs(self.selected_ents) do
		if k and now and v and now.GUID ~= k.GUID then
			if not fn or fn(k) then
				return true
			end
			return false
		end
	end
end

-- 部署间隔
function ActionQueuer:GetDeploySpacing(item)
	for key, spacing in pairs(deploy_spacing) do
		if item.prefab:find(key) or item:HasTag(key) then return spacing end
	end
	local spacing = item.replica.inventoryitem:DeploySpacingRadius()
	return spacing ~= 0 and spacing or 1
end

function ActionQueuer:CanSeeTarget(ent)
	return ent and (TheSim:GetLightAtPoint(ent:GetPosition().x, 0, ent:GetPosition().z) > TUNING.DARK_CUTOFF
		or ThePlayer.components.playervision.nightvision or ThePlayer.prefab == 'wathom')
end

function ActionQueuer:SendControllerRPCSafely2(actioncode, item, target, modname)
	if INV_util:GetActiveItem() == item then
		SendRPCToServer(RPC.LeftClick, actioncode, target:GetPosition().x,
			target:GetPosition().z,
			target, nil, nil, true, modname)
	elseif self:CanSeeTarget(target) then --must can see it
		SendRPCToServer(RPC.ControllerUseItemOnSceneFromInvTile, actioncode, item, target, modname)
	else
		if INV_util:GetActiveItem() then
			SendRPCToServer(RPC.LeftClick, actioncode, target:GetPosition().x,
				target:GetPosition().z,
				target, nil, nil, true, modname)
		else
			POS_util:GoToPoint(target:GetPosition().x,
				target:GetPosition().z)
		end
	end
end

function ActionQueuer:SendControllerRPCSafely(actioncode, item, target, modname)
	if self:CanSeeTarget(target) then --must can see it
		SendRPCToServer(RPC.ControllerUseItemOnSceneFromInvTile, actioncode, item, target, modname)
	else
		if INV_util:GetActiveItem() then
			SendRPCToServer(RPC.LeftClick, actioncode, target:GetPosition().x,
				target:GetPosition().z,
				target, nil, nil, true, modname)
		else
			POS_util:GoToPoint(target:GetPosition().x,
				target:GetPosition().z)
		end
	end
end

function ActionQueuer:GetSelectedEnt(ent)
	return self.selected_ents[ent]
end

function ActionQueuer:RegardAsSame(ent1, ent2)
	if not ent1 or not ent2 then return end
	local prefab1, prefab2 = type(ent1) == "table" and ent1.prefab or ent1, type(ent2) == "table" and ent2.prefab or ent2
	if not prefab1 or not prefab2 then return end
	--
	if type(prefab1) ~= "string" or type(prefab2) ~= "string" then return end
	--
	for k, v in pairs({ 'trinket', 'halloween', '_seeds' }) do
		if string.find(prefab1, v) then
			return string.find(prefab2, v)
		end
	end
	--圣诞节的分开判断（因为灯泡）
	if string.find(prefab1, "winter_") and string.find(prefab2, "winter_") then
		local islight1 = string.find(prefab1, "winter_ornament_light")
		local islight2 = string.find(prefab2, "winter_ornament_light")
		if islight1 or islight2 then
			return islight1 and islight2
		end
		return true
	end
	--'winter_food','winter_ornament_boss', 'winter_',
	if sameprefablist[prefab1] and sameprefablist[prefab2] then
		return sameprefablist[prefab1] == sameprefablist[prefab2]
	end
end

function ActionQueuer:Wait()
	-- local current_time = GetTime()
	Sleep(self.work_delay)
	repeat
		-- 3帧
		Sleep(self.action_delay)
		-- 移动打断，其他条件？？？
	until not self.inst:HasTag("moving")
		and self.inst:HasTag("idle") and not IsBusy()
end

-- 传入 目标,是否右键,位置 返回 合法的动作,是否右键
function ActionQueuer:GetAction(target, action, rightclick, mouse_item, pos) --action是储存的target的动作
	local actionid = action and action.id or action and action.action and action.action.id or action
	--author_print('callGetAction:', target, actionid)
	local actiontable = actionid and allowed_actions[actionid] and allowed_actions[actionid]
	pos = pos or target and target:GetPosition() or TheInput:GetWorldPosition()
	if target == self.posaction then target = nil end --self.posaction是虚构的目标，实际上获取动作的时候还是nil
	--如果这个东西不在玩家身上
	if mouse_item and not ActionQueuer:IsHoldingItem(mouse_item, true) then
		author_print('return1:', mouse_item)
		return
	end
	--获取控制器动作
	if mouse_item and actiontable and actiontable.controllercanselect and actiontable.controllercanselect({ target = target,
			item = mouse_item, pos = pos }) then
		author_print('return2:', mouse_item)
		return ACTIONS[actionid], allowed_actions[actionid]
	end
	local activeitem = INV_util:GetActiveItem()
	--author_print(activeitem, mouse_item)
	if mouse_item and (not activeitem or activeitem ~= mouse_item) then --这里有时候进不来？？
		local a = canusecontroller(pos, mouse_item, target, actionid) --byd
		author_print('return3:', mouse_item)
		return a,
			a and a.action and a.action.id and allowed_actions[a.action.id] or
			a and a.id and allowed_actions[a.id]
	end
	local playeractionpicker = self.inst.components.playeractionpicker
	--攻击动作单独区分
	if actiontable and actiontable.specialselectfn then
		local act, acttab = actiontable.specialselectfn(actiontable, target)
		if act then
			author_print('return4:', mouse_item)
			return act, acttab
		end
	end
	--适配自己的点击切装备
	local lmb, rmb = playeractionpicker:DoGetMouseActions(pos, target)
	--author_print(target, lmb, rmb)
	if rightclick ~= false then --这里是排队论选择的时候左键或者右键
		if rmb then          --必须在allowed_actions这个表里面的动作
			local rmbacttab = allowed_actions[rmb.action.id]
			if rmbacttab and ENT_util:FnOrNum(rmbacttab.isleftclick, target) ~= true then
				if not actionid or actionid == rmb.action.id then         --actionid为传入的动作id，必须是没传入或者传入的和获取的相同
					if not rmbacttab.canselect or rmbacttab.canselect(target, self) then --canselect没有或者满足这个函数才能选择
						return rmb, rmbacttab
					end
				end
			end
		end
		for _, act in ipairs(playeractionpicker:GetRightClickActions(pos, target)) do
			local acttab = allowed_actions[act.action.id]
			if acttab and ENT_util:FnOrNum(acttab.isleftclick, target) ~= true then
				if not actionid or actionid == act.action.id then
					if not acttab.canselect or acttab.canselect(target, self) then
						return act, acttab
					end
				end
			elseif not acttab and not action then
				author_print('AQ,unknown Right actionid:', act.action.id)
			end
		end
	end
	if rightclick ~= true then
		if lmb then
			local lmbacttab = allowed_actions[lmb.action.id]
			if lmbacttab and ENT_util:FnOrNum(lmbacttab.isleftclick, target) ~= false then
				if not actionid or lmb.action.id == actionid then
					if not lmbacttab.canselect or lmbacttab.canselect(target, self) then
						return lmb, lmbacttab
					end
				end
			end
		end
		for _, act in ipairs(playeractionpicker:GetLeftClickActions(pos, target)) do
			local acttab = allowed_actions[act.action.id]
			if acttab and ENT_util:FnOrNum(acttab.isleftclick, target) ~= false then
				if not actionid or act.action.id == actionid then
					if not acttab.canselect or acttab.canselect(target, self) then
						return act, acttab
					end
				end
			elseif not acttab and not action then
				author_print('AQ,unknown Left actionid:', act.action.id)
			end
		end
	end
	--
	if mouse_item and activeitem == mouse_item then             --这里有时候进不来？？
		local a = canusecontroller(pos, mouse_item, target, actionid) --byd
		author_print('return controller:', mouse_item)
		if a and a.action and a.action.id and allowed_actions[a.action.id] and allowed_actions[a.action.id].controllertable then
			return a,
				a and a.action and a.action.id and allowed_actions[a.action.id] or
				a and a.id and allowed_actions[a.id]
		end
	end
end

--check if item has the action actionid
function ActionQueuer:collectActions(inst, actiontype, actionid, params)
	local useitem = inst
	if not useitem then return end
	local actions = {}
	local doer = ThePlayer
	local target = params.target
	local pos = params.pos
	local right = params.right
	--[[ { target = target,
            item = mouse_item, pos = pos } ]]
	if actiontype == "SCENE" then
		useitem:CollectActions("SCENE", doer, actions, right)
	elseif actiontype == "USEITEM" then
		useitem:CollectActions("USEITEM", doer, target, actions, right)
	elseif actiontype == "POINT" then
		useitem:CollectActions("POINT", doer, pos, actions, right, target)
	elseif actiontype == "EQUIPPED" then
		useitem:CollectActions("EQUIPPED", doer, target, actions, right)
	elseif actiontype == "INVENTORY" then
		useitem:CollectActions("INVENTORY", doer, actions, right)
	end
	for k, v in pairs(actions) do
		if v and v.id == actionid then
			return true
		end
	end
end

-- 排队论发送动作方法,统一为左右键的RPC
function ActionQueuer:SendAction(act, rightclick, target)
	local playercontroller = self.inst.components.playercontroller
	-- 主机直接做动作
	if playercontroller.ismastersim then
		self.inst.components.combat:SetTarget(nil)
		playercontroller:DoAction(act)
		return
	end
	local pos = act:GetActionPoint() or self.inst:GetPosition()
	local controlmods = 10 --force stack and force attack
	-- 开延迟
	if playercontroller.locomotor then
		act.preview_cb = function()
			if rightclick then
				SendRPCToServer(RPC.RightClick, act.action.code, pos.x, pos.z, target, act.rotation, true, nil, nil,
					act.action.mod_name)
			else
				SendRPCToServer(RPC.LeftClick, act.action.code, pos.x, pos.z, target, true, controlmods, nil,
					act.action.mod_name)
			end
		end
		playercontroller:DoAction(act)
	else
		-- 关延迟
		if act.action.code == ACTIONS.PICK.code and (target and math.sqrt(distsq(target:GetPosition(), ThePlayer:GetPosition())) < 5) then
			SendRPCToServer(RPC.ActionButton, act.action.code, target)
		elseif rightclick then
			SendRPCToServer(RPC.RightClick, act.action.code, pos.x, pos.z, target, act.rotation, true, nil,
				act.action.canforce, act.action.mod_name)
		else
			SendRPCToServer(RPC.LeftClick, act.action.code, pos.x, pos.z, target, true, controlmods, act.action.canforce,
				act.action.mod_name)
		end
	end
end

function ActionQueuer:SendActionAndWait(act, rightclick, target)
	self:SendAction(act, rightclick, target)
	self:Wait(act.action, target)
end

--有无加速道具，有的话返回那个道具和所在的位置
function ActionQueuer:HasAddSpeedEquipment()
	local maxspeed, speeditem, pos, backpack
	maxspeed = 0
	local function check(k, v)
		if v.prefab and v.replica.inventoryitem then
			local speed = v.replica.inventoryitem:GetWalkSpeedMult()
			local slot = v.replica.equippable and v.replica.equippable:EquipSlot()
			if speed and speed > maxspeed and speed > 1 and slot == EQUIPSLOTS.HANDS then
				maxspeed = speed
				speeditem, pos = v, k
			end
		end
	end
	for k, v in pairs(ThePlayer.replica.inventory:GetEquips()) do
		if v:HasTag("_equippable") then
			check(k, v)
		end
	end
	for k, v in pairs(ThePlayer.replica.inventory:GetItems()) do
		if v:HasTag("_equippable") then
			check(k, v)
		end
	end
	for k, v in pairs(ThePlayer.replica.inventory:GetOpenContainers() or {}) do
		if k and k.replica and k.replica.container then --如果是空表不知道k是不是nil??以防万一还是判定空
			for kkk, vvv in pairs(k.replica.container:GetItems()) do
				if vvv:HasTag("_equippable") then
					check(kkk, vvv)
				end
			end
		end
	end

	return speeditem, pos, backpack
end

function ActionQueuer:CanDeployHint()
	if not MOD_util:GetMOption("aq_showdeploy", default_aq_showdeploy) then
		return false
	end
	if self.selected_ents and next(self.selected_ents) then
		return
	end
	return true
end

function ActionQueuer:CanEquipMedal()
	return MOD_util:GetMOption("aq_autoequipmedal", default_aq_autoequipmedal)
end

local MAX_DEPLOY_HINT_MARKERS = 400

function ActionQueuer:ClearDeployHint(remove)
	local markers = self.deploy_hint_markers
	if not markers then return end
	for i, marker in pairs(markers) do
		if marker and marker:IsValid() then
			if remove then
				marker:Remove()
				markers[i] = nil
			else
				marker:Hide()
			end
		else
			markers[i] = nil
		end
	end
	self.deploy_hint_count = 0
end

function ActionQueuer:HideUnusedDeployHintMarkers(used_count)
	local markers = self.deploy_hint_markers
	if not markers then return end
	for i = used_count + 1, #markers do
		local marker = markers[i]
		if marker and marker:IsValid() then
			marker:Hide()
		end
	end
	self.deploy_hint_count = used_count
end

local function CreateDeployHintMarker()
	local marker = CreateEntity()
	marker.entity:AddTransform()
	marker.entity:AddAnimState()
	marker.entity:SetCanSleep(false)
	marker.persists = false
	marker:AddTag("CLASSIFIED")
	marker:AddTag("NOCLICK")
	marker:AddTag("placer")
	marker:AddTag("DECOR")
	marker:AddTag("FX")
	marker:AddTag("NOBLOCK")
	marker.AnimState:SetBank("sign_mini")
	marker.AnimState:SetBuild("sign_mini")
	marker.AnimState:PlayAnimation("idle", true)
	marker.AnimState:SetLightOverride(1)
	local placer = marker:AddComponent("placer")
	placer.hide_inv_icon = false
	return marker
end

local function IsValidDeployHintAnimSource(source)
	return source and source.IsValid and source:IsValid() and source.AnimState
end

local function GetDeployHintAnimSource(self, item)
	local playercontroller = self.inst and self.inst.components.playercontroller
	if playercontroller then
		if IsValidDeployHintAnimSource(playercontroller.deployplacer) then
			return playercontroller.deployplacer
		end
		if IsValidDeployHintAnimSource(playercontroller.placer) then
			return playercontroller.placer
		end
	end
	if IsValidDeployHintAnimSource(item) then
		return item
	end
	local active_item = INV_util:GetActiveItem()
	if IsValidDeployHintAnimSource(active_item) then
		return active_item
	end
end

local DEPLOY_HINT_ANIM_DATA_CACHE = {}

local function GetDeployHintAnimCacheKey(source, item)
	return source and source.prefab or item and item.prefab
end

local function GetDeployHintAnimData(source, item)
	local cache_key = item and item.prefab or "no_prefab"
	if cache_key and DEPLOY_HINT_ANIM_DATA_CACHE[cache_key] then
		return DEPLOY_HINT_ANIM_DATA_CACHE[cache_key]
	end
	if not source or not source.AnimState then return end
	local animstate = source.AnimState
	local ok_build, build = pcall(function() return animstate:GetBuild() end)
	if not ok_build or not build or build == "" or build == "FROMNUM" then
		return
	end
	local ok_bank, bank = pcall(function() return animstate:GetBankHash() end)
	if not ok_bank or not bank or bank == 0 then
		bank = build
	end
	local ok_history, _, anim = pcall(function() return animstate:GetHistoryData() end)
	if not ok_history or not anim or anim == "" then
		for _, anim_name in ipairs({ "idle", "idle_loop", "idle_planted", "idle1", "anim" }) do
			if animstate:IsCurrentAnimation(anim_name) then
				anim = anim_name
				break
			end
		end
	end
	if anim then
		local data = { bank = bank, build = build, anim = anim }
		if cache_key then
			DEPLOY_HINT_ANIM_DATA_CACHE[cache_key] = data
		end
		return data
	end
end

function ActionQueuer:SetDeployHintMarkerAnim(marker, item)
	local cache_key = item and item.prefab or "no_prefab"
	local data
	if cache_key and DEPLOY_HINT_ANIM_DATA_CACHE[cache_key] then
		data = DEPLOY_HINT_ANIM_DATA_CACHE[cache_key]
	else
		local source = GetDeployHintAnimSource(self, item)
		data = GetDeployHintAnimData(source, item)
	end

	local bank = data and data.bank or "sign_mini"
	local build = data and data.build or "sign_mini"
	local anim = data and data.anim or "idle"
	local anim_key = tostring(bank) .. "|" .. tostring(build) .. "|" .. tostring(anim)
	--marker.Transform:SetScale(1, 1, 1)
	marker.Transform:SetRotation(0)
	if marker.deploy_hint_anim_key == anim_key then return end
	marker.AnimState:SetBank(bank)
	marker.AnimState:SetBuild(build)
	marker.AnimState:PlayAnimation(anim, true)
	marker.deploy_hint_anim_key = anim_key
end

function ActionQueuer:GetDeployHintMarker(index, spacing, item)
	self.deploy_hint_markers = self.deploy_hint_markers or {}
	local marker = self.deploy_hint_markers[index]
	if not marker or not marker:IsValid() then
		marker = CreateDeployHintMarker()
		self.deploy_hint_markers[index] = marker
	end
	self:SetDeployHintMarkerAnim(marker, item)
	marker.AnimState:SetAddColour(.25, .75, .25, 0)
	marker.AnimState:SetMultColour(1, 1, 1, 0.65)
	return marker
end

function ActionQueuer:ShowDeployHintMarker(index, pos, spacing, item)
	local marker = self:GetDeployHintMarker(index, spacing, item)
	marker.Transform:SetPosition(pos.x, 0, pos.z)
	marker:Show()
end

local function FindDeployHintItem(self, item)
	local prefab = item and item.prefab
	local active_item = INV_util:GetActiveItem()
	if active_item and (not prefab or active_item.prefab == prefab) then
		return active_item
	end
	if item and item.IsValid and item:IsValid() then
		return item
	end
	if not prefab or not self.inst or not self.inst.replica or not self.inst.replica.inventory then
		return
	end
	local inventory = self.inst.replica.inventory
	local body_item
	if EQUIPSLOTS.BACK then
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BACK)
	else
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
	end
	local backpack = body_item and body_item.replica.container
	for _, inv in pairs(backpack and { inventory, backpack } or { inventory }) do
		for _, inv_item in pairs(inv:GetItems()) do
			if inv_item and inv_item.prefab == prefab then
				return inv_item
			end
		end
	end
end

local function GetDeployHintStackSize(item)
	return item and item.replica and item.replica.stackable and item.replica.stackable:StackSize() or 1
end

local function CountDeployHintItems(self, item, active_only)
	local prefab = item and item.prefab
	local inventory = self.inst and self.inst.replica and self.inst.replica.inventory
	if not prefab or not inventory then return end
	local count = 0
	local active_item = INV_util:GetActiveItem()
	if active_item and active_item.prefab == prefab then
		count = count + GetDeployHintStackSize(active_item)
	end
	if active_only then return count end
	for _, inv_item in pairs(inventory:GetItems()) do
		if inv_item and inv_item.prefab == prefab then
			count = count + GetDeployHintStackSize(inv_item)
		end
	end
	local body_item
	if EQUIPSLOTS.BACK then
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BACK)
	else
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
	end
	local backpack = body_item and body_item.replica.container
	if backpack then
		for _, inv_item in pairs(backpack:GetItems()) do
			if inv_item and inv_item.prefab == prefab then
				count = count + GetDeployHintStackSize(inv_item)
			end
		end
	end
	return count
end

local function GetDeployHintLimit(self, deploy_fn, item)
	if deploy_fn == self.DeployActiveItem or deploy_fn == self.DropActiveItem
		or deploy_fn == self.WormwoodPlantAtPoint then
		return CountDeployHintItems(self, item)
	end
end

local function CountDeployedHintPositions(deployed_pos)
	local count = 0
	for _ in pairs(deployed_pos or {}) do
		count = count + 1
	end
	return count
end

local function CanBuildHintAtPoint(self, pos)
	local playercontroller = self.inst.components.playercontroller
	local recipe = playercontroller and playercontroller.placer_recipe
	local builder = self.inst.replica.builder
	if not recipe or not builder then return false end
	if not builder:IsBuildBuffered(recipe.name) and not builder:CanBuild(recipe.name) then return false end
	local rotation = playercontroller.placer and playercontroller.placer:GetRotation() or 0
	return builder:CanBuildAtPoint(pos, recipe, rotation)
end

local function CanDeployHintAtPoint(self, deploy_fn, pos, item)
	if deploy_fn == null then
		return CanBuildHintAtPoint(self, pos)
	end
	if item == nil and self.inst.components.playercontroller and self.inst.components.playercontroller.placer_recipe then
		return CanBuildHintAtPoint(self, pos)
	end
	if deploy_fn == self.DeployActiveItem then
		local deploy_item = FindDeployHintItem(self, item)
		local inventoryitem = deploy_item and deploy_item.replica and deploy_item.replica.inventoryitem
		return inventoryitem and inventoryitem.CanDeploy and inventoryitem:CanDeploy(pos, nil, self.inst)
	end
	if deploy_fn == self.DropActiveItem then
		return FindDeployHintItem(self, item) ~= nil
	end
	if deploy_fn == self.TillAtPoint then
		return FindDeployHintItem(self, item) ~= nil and TheWorld.Map:CanTillSoilAtPoint(pos.x, 0, pos.z)
	end
	if deploy_fn == self.WormwoodPlantAtPoint then
		return FindDeployHintItem(self, item) ~= nil and TheWorld.Map:CanTillSoilAtPoint(pos.x, 0, pos.z)
	end
	if deploy_fn == self.TerraformAtPoint then
		return FindDeployHintItem(self, item) ~= nil and TheWorld.Map:CanTerraformAtPoint(pos.x, 0, pos.z)
	end
	return true
end

local function redir_valid_pos(self, deploy_fn, spacing, item)
	local snap_farm = false
	if deploy_fn == self.TillAtPoint or deploy_fn == self.WormwoodPlantAtPoint then snap_farm = true end
	local heading, dir = GetHeadingDir()
	local diagonal = heading % 2 ~= 0
	local X, Z = "x", "z"
	if dir then X, Z = Z, X end
	local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
	local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
	local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
	local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
	local width = math.floor(self.TL:Dist(self.TR) / adjusted_spacing_x)
	local height = math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))
	if height >= 1 then
		height = self.endless_deploy and 100 or height
	end
	local start_x, _, start_z = self.TL:Get()
	local terraforming = false

	if -- 201217 null: added support for Watering of farming tiles
		deploy_fn == self.TerraformAtPoint or
		item and item:HasTag("groundtile") then
		start_x, _, start_z = TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)
		terraforming = true
	elseif deploy_fn == self.DropActiveItem or item and (item:HasTag("wallbuilder") or item:HasTag("fencebuilder")) then
		start_x, start_z = math.floor(start_x) + 0.5, math.floor(start_z) + 0.5

		-- 210116 null: adjust farm grid start position + offsets (thanks to blizstorm for help)
	elseif snap_farm then
		-- 210709 null: fix for 3x3 alignment on medium/huge servers (different tile offsets)
		local tilecenter = _G.Point(_G.TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)) -- center of tile
		if tilecenter.x % 4 == 0 then                                                  -- if center of tile is divisible by 4, then it's a medium/huge server
			farm3x3_offset =
				farm_spacing                                                           -- adjust offset for medium/huge servers for 3x3 grid
		end
		start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
			math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
	elseif self.deploy_on_grid then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
		start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5
	end
	return {
		height = height,
		start_x = start_x,
		start_z = start_z,
		terraforming = terraforming,
		width = width,
		spacing_x = spacing_x,
		spacing_z = spacing_z,
		X = X,
		Z = Z,
		diagonal = diagonal,
	}
end
function ActionQueuer:RefreshDeployHint(deploy_fn, spacing, item, deployed_pos, fixed_data, fixed_limit)
	if not self:CanDeployHint() then
		self:ClearDeployHint()
		return
	end
	if deploy_fn and self.TL and spacing then
		--self.TL, self.BL, self.TR, self.BR
		local data = fixed_data or redir_valid_pos(self, deploy_fn, spacing, item)
		local hint_limit = fixed_limit
		if hint_limit == nil then
			hint_limit = GetDeployHintLimit(self, deploy_fn, item)
		end
		if hint_limit ~= nil then
			hint_limit = math.max(0, hint_limit - CountDeployedHintPositions(deployed_pos))
			if hint_limit <= 0 then
				self:HideUnusedDeployHintMarkers(0)
				return
			end
		end
		local height = data.height
		local start_x = data.start_x
		local start_z = data.start_z
		local terraforming = data.terraforming
		local width = data.width
		local spacing_x = data.spacing_x
		local spacing_z = data.spacing_z
		local X, Z = data.X, data.Z
		local diagonal = data.diagonal
		local cur_pos = Point()
		local count = { x = 0, y = 0, z = 0 }
		local row_swap = 1

		-- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
		local step = 1
		local countz2 = 0
		local countStep = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { 1, 0 } }
		local hint_count = 0
		if height < 1 then countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } } end -- 210130 null: bliz fix (210127)
		while self.inst:IsValid() do
			cur_pos.x = start_x + spacing_x * count.x
			cur_pos.z = start_z + spacing_z * count.z
			if diagonal then
				if width < 1 then
					if count[Z] > height then break end
					count[X] = count[X] - 1
					count[Z] = count[Z] + 1
				else
					local row = math.floor(count.y / 2)
					if count[X] + row > width or count[X] + row < 0 then
						count.y = count.y + 1
						if count.y > height then break end
						row_swap = -row_swap
						count[X] = count[X] + row_swap - 1
						count[Z] = count[Z] + row_swap
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count.x = count.x + row_swap
					count.z = count.z + row_swap
				end
			else
				if double_snake then -- 210127 null: snake within snake deployment (thanks to blizstorm)
					if count[X] > width or count[X] < 0 then
						countz2 = countz2 +
							2 -- assume first that next major row can be progressed since this is the case most of the time (blizstorm)

						-- if countz2 > height then -- old bliz code (210115)
						if countz2 + 1 > height then -- 210130 null: bliz fix (210127)
							-- if countz2 - 1 > height then -- old bliz code (210115)
							-- if countz2 - 1 <= height then -- old bliz code (210122)
							if countz2 <= height then -- 210130 null: bliz fix (210127)
								-- countz2 = countz2 - 1 -- old bliz code (210115)
								countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } }
							else
								break
							end
						end

						step = 1
						row_swap = -row_swap
						count[X] = count[X] + row_swap
						count[Z] = countz2
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count[X] = count[X] + countStep[step][1] * row_swap
					count[Z] = count[Z] + countStep[step][2]
					step = step % 4 + 1
				else -- Regular snaking deployment
					if count[X] > width or count[X] < 0 then
						count[Z] = count[Z] + 1
						if count[Z] > height then break end
						row_swap = -row_swap
						count[X] = count[X] + row_swap
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count[X] = count[X] + row_swap
				end
			end

			local accessible_pos = cur_pos
			if terraforming then
				accessible_pos = GetAccessibleTilePosition(cur_pos)
			elseif deploy_fn == self.TillAtPoint then -- 210117 null: check if pos already Tilled
				for _, ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.005, { "soil" })) do
					if not ent:HasTag("NOCLICK") then
						accessible_pos = false
						break
					end -- Skip Tilling this position
				end
			end
			if accessible_pos then
				local pos_key = accessible_pos.x .. "p" .. accessible_pos.z
				if (not deployed_pos or not deployed_pos[pos_key])
					and CanDeployHintAtPoint(self, deploy_fn, accessible_pos, item) then
					hint_count = hint_count + 1
					self:ShowDeployHintMarker(hint_count, accessible_pos, spacing, item)
					if hint_count >= MAX_DEPLOY_HINT_MARKERS or hint_limit and hint_count >= hint_limit then break end
				end
			end
		end
		self:HideUnusedDeployHintMarkers(hint_count)
	else
		self:ClearDeployHint()
	end
end

local function get_deploy_fn(self)
	if not self.TL then return end
	local active_item = INV_util:GetActiveItem()
	if active_item then
		-- 210103 null: added basic support for Wormwood planting
		if ThePlayer:HasTag("plantkin") and active_item:HasTag("deployedfarmplant") then
			local cx, cz = (self.TL.x + self.BR.x) / 2,
				(self.TR.z + self.BL.z) /
				2                                                        -- Get SelectionBox() center coords
			if (cx and cz) and TheWorld.Map:IsFarmableSoilAtPoint(cx, 0, cz) then -- if center = soil tile
				return self.WormwoodPlantAtPoint, farm_spacing, active_item
			else
				return self.DeployActiveItem, farm_spacing, active_item
			end
		end

		if active_item.replica.inventoryitem and active_item.replica.inventoryitem:IsDeployable(self.inst) then -- 如果鼠标上是允许放置的则放置
			return self.DeployActiveItem, ActionQueuer:GetDeploySpacing(active_item),
				active_item
		else -- 否则丢弃
			return self.DropActiveItem, 1, active_item
		end
		return
	end
	local equip_item = INV_util:GetHandsEquip()
	--local act = self:GetAction(nil, nil, rightclick)--"farmtiller"--HasActionComponent(name)
	if self:HasActionComponent(equip_item, "farmtiller") then
		return self.TillAtPoint, farm_spacing, equip_item
	end
end
-- 框选器(是否右键)
function ActionQueuer:SelectionBox(rightclick)
	local previous_ents = {}                           -- 先前的实体表
	local started_selection = false                    -- 开始选择标志位
	local start_x, start_y = self.screen_x, self.screen_y -- 开始选择的位置
	local start_pos = GetWorldPosition(start_x, start_y)
	self.update_selection = function()
		if not started_selection then
			if math.abs(start_x - self.screen_x) + math.abs(start_y - self.screen_y) < 32 then
				return
			end
			started_selection = true
		end
		local xmin, xmax = start_x, self.screen_x
		if xmax < xmin then
			xmin, xmax = xmax, xmin
		end
		local ymin, ymax = start_y, self.screen_y
		if ymax < ymin then
			ymin, ymax = ymax, ymin
		end

		self:SetSelectionPosition(xmin, xmax, ymin, ymax)

		self.TL, self.BL, self.TR, self.BR = GetWorldPosition(xmin, ymax), GetWorldPosition(xmin, ymin),
			GetWorldPosition(xmax, ymax), GetWorldPosition(xmax, ymin)
		local center = GetWorldPosition((xmin + xmax) / 2, (ymin + ymax) / 2) -- 窗口实际在世界的位置
		local range = math.sqrt(math.max(center:DistSq(self.TL), center:DistSq(self.BL), center:DistSq(self.TR),
			center:DistSq(self.BR)))                                    -- 两点间的距离公式
		local current_ents = {}
		for _, v in pairs(TheSim:FindEntities(center.x, 0, center.z, range, nil, unselectable_tags)) do
			local ent = v and v.client_forward_target or v
			if ENT_util:IsValid(ent) then
				local pos = ent:GetPosition()
				if pos and isPointInSide(pos, { self.TL, self.TR, self.BR, self.BL }) then -- 实体位置在框选范围内
					if not self:IsSelectedEntity(ent) and not previous_ents[ent] then -- 不是已选实体 且 不在之前的实体表中
						local act, acttab = self:GetAction(ent, nil, rightclick)
						if act and acttab and not ENT_util:FnOrNum(acttab.dontselectbyselectbox, ent, rightclick) then
							self:SelectEntity(ent, act.action.id, nil, nil, rightclick)
						end
					end
					current_ents[ent] = true -- 记录当前实体进入当前实体表
				end
			end
		end
		for ent in pairs(previous_ents) do -- 遍历之前的实体表
			if not current_ents[ent] then -- 如果之前的表中没有现在的量，则取消选中
				self:DeselectEntity(ent)
			end
		end
		previous_ents = current_ents
		if ActionQueuer:CanDeployHint() then
			---DeployToSelection
			local deploy_fn, spacing, item
			if rightclick then
				deploy_fn, spacing, item = get_deploy_fn(self)
			elseif self.inst.components.playercontroller.placer then
				local playercontroller = self.inst.components.playercontroller
				local recipe = playercontroller.placer_recipe
				deploy_fn = null
				spacing = recipe.min_spacing or 3.2
				item = nil
			end
			self:RefreshDeployHint(deploy_fn, spacing, item)
		else
			self:RefreshDeployHint()
		end
	end
	-- 框选线程
	self.selection_thread = StartThread(function() -- 该线程按帧刷新
		while self.inst:IsValid() do
			if self.queued_movement then
				self.update_selection()
				self.queued_movement = false
			end

			Sleep(FRAMES)
		end
		self:ClearSelectionThread() -- 清除选择器线程                                  -- StartThread(执行函数，线程ID)
	end, "actionqueue_selection_thread")
end

function ActionQueuer:nullPick(x, y, z, rightclick)
	for _, v in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
		local ent = v and v.client_forward_target or v
		if ENT_util:IsValid(ent) and (ent.prefab == self.last_click.prefab -- Original CherryPick condition
				or self:RegardAsSame(self.last_click.prefab, ent)
			)
			and not self:IsSelectedEntity(ent) then
			local act = self:GetAction(ent, nil, rightclick)
			if act and act.action == self.last_click.action then -- 两次动作相同
				self:SelectEntity(ent, act.action.id, nil, nil, rightclick)
			end
		end
	end
end

local trees = { "evergreen", "deciduoustree", "moon_tree", "twiggytree", "palmconetree", "evergreen_sparse" }
local tree_cherry = {
	cancherypick = function(self)
		return (self.last_click.action == ACTIONS.CHOP
			or self.last_click.action == ACTIONS.WAX)
	end,
	cherrypickfn = function(self, rightclick)
		local x, y, z = self.last_click.pos:Get()
		if (self.last_click.ent and self.last_click.ent:HasTag("burnt")) then
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, { "burnt" }, unselectable_tags)) do
				if table.contains(trees, ent.prefab) then
					self:SelectEntity(ent, self.last_click.action.id, nil, nil, rightclick)
				end
			end
		elseif (self.last_click.AnimState:IsCurrentAnimation("sway1_loop_tall") or -- Only check for lvl3/tall trees
				self.last_click.AnimState:IsCurrentAnimation("sway2_loop_tall")) then
			-- Only check for lvl3/tall trees. Otherwise default to original CherryPick code.
			-- Double Click on Tall trees only CHOPs the Tall trees.
			-- Double Click on any other size tree CHOPs trees of all sizes (including Tall trees).
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				if ent.prefab == self.last_click.prefab and
					-- 对不同状态的树区分
					(ent.AnimState:IsCurrentAnimation("sway1_loop_tall") or
						ent.AnimState:IsCurrentAnimation("sway2_loop_tall")) then
					self:SelectEntity(ent, self.last_click.action.id, nil, nil, rightclick)
				end
			end
		else
			self:nullPick(x, y, z, rightclick)
		end
	end
}
local cherryPickTable = {
	["rock_avocado_bush"] = {
		cancherypick = function(self) return self.last_click.action == ACTIONS.PICK end,
		cherrypickfn = function(self, rightclick)
			local x, y, z = self.last_click.pos:Get()
			local AnimstatePick = self.last_click.AnimState:IsCurrentAnimation("idle3") and "idle3" or "idle4"
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				-- 对不同状态的石果进行区分
				if ent.prefab == "rock_avocado_bush" and ent.AnimState:IsCurrentAnimation(AnimstatePick) then
					self:SelectEntity(ent, self.last_click.action.id, nil, nil, rightclick)
				end
			end
		end
	},
	["junk_pile"] = {
		cancherypick = function(self) return self.last_click.action == ACTIONS.PICK end,
		cherrypickfn = function(self, rightclick)
			local x, y, z = self.last_click.pos:Get()
			local dontneedanim = not self.last_click.AnimState:IsCurrentAnimation("idlelow")
				and not self.last_click.AnimState:IsCurrentAnimation("looplow") and "idlelow"
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				-- 不选择最小的垃圾堆--or act.target.AnimState:IsCurrentAnimation("looplow")
				if ent.prefab == "junk_pile" and (not dontneedanim or not ent.AnimState:IsCurrentAnimation(dontneedanim)) then
					self:SelectEntity(ent, self.last_click.action.id, nil,
						not dontneedanim
						and "destory_low_pile", rightclick)
				end
			end
		end
	},
	["spiderden"] = {
		cancherypick = function(self)
			return self.last_click.action == ACTIONS.SHAVE
		end,
		cherrypickfn = function(self, rightclick)
			local x, y, z = self.last_click.pos:Get()
			local dontneedanim = not self.last_click.AnimState:IsCurrentAnimation("cocoon_small")
				and not self.last_click.AnimState:IsCurrentAnimation("cocoon_small") and "cocoon_small"
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				-- 不选择最小的蜘蛛巢
				if ent.prefab == "spiderden" and (not dontneedanim or not ent.AnimState:IsCurrentAnimation(dontneedanim)) then
					self:SelectEntity(ent, self.last_click.action.id, nil,
						not dontneedanim
						and "destory_cocoon_small", rightclick)
				end
			end
		end
	}, --not act.target.AnimState:IsCurrentAnimation("cocoon_small")
	["marbleshrub"] = {
		cancherypick = function(self)
			return (self.last_click.action == ACTIONS.MINE or self.last_click.action == ACTIONS.WAX) and
				self.last_click.AnimState:IsCurrentAnimation("idle_tall")
		end,
		cherrypickfn = function(self, rightclick)
			local x, y, z = self.last_click.pos:Get()
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				-- 对不同状态的大理石树区分
				if ent.prefab == self.last_click.prefab and ent.AnimState:IsCurrentAnimation("idle_tall") then
					self:SelectEntity(ent, self.last_click.action.id, nil, nil, rightclick)
				end
			end
		end
	},
	["flower"] = {
		cancherypick = function(self)
			return self.last_click.action == ACTIONS.LOOKAT and not
				self.last_click.AnimState:IsCurrentAnimation("rose")
		end,
		cherrypickfn = function(self, rightclick)
			local x, y, z = self.last_click.pos:Get()
			for _, ent in pairs(TheSim:FindEntities(x, 0, z, self.control_click_range, nil, unselectable_tags)) do
				if ent.prefab == self.last_click.prefab and not ent.AnimState:IsCurrentAnimation("rose") then
					self:SelectEntity(ent, self.last_click.action.id, nil, nil, rightclick)
				end
			end
		end
	},
}
for k, v in pairs(trees) do
	cherryPickTable[v] = tree_cherry
end
function ActionQueuer:CherryPick(rightclick)
	local current_time = GetTime()
	if current_time - self.last_click.time < self.double_click_speed and self.last_click.prefab then -- 确认双击
		local x, y, z            = self.last_click.pos:Get()

		-- 230518 呼吸 如果按住ctrl 范围将为160, 否则为默认设置
		local newrange           = MOD_util:GetMOption("aq_double_click_range", default_aq_double_click_range)
		newrange                 = math.min(newrange, 160)
		self.control_click_range = TheInput:IsControlPressed(CONTROL_FORCE_STACK) and 160 or
			newrange or self.double_click_range

		local cherrypick_target  = cherryPickTable[self.last_click.prefab]
		--240630 萌萌的新: add cherrypick to cherrypicktable ,key:prefab value:{cancherypick,cherrypickfn}
		if cherrypick_target and ENT_util:FnOrNum(cherrypick_target.cancherypick, self) then
			cherrypick_target.cherrypickfn(self, rightclick)
		else
			-- 210705 null: added support for other mods to add their own CherryPick conditions
			self:nullPick(x, y, z, rightclick)
		end
		self.last_click.prefab = nil
		return
	end
	--单击
	local flag = true
	for _, v in ipairs(TheInput:GetAllEntitiesUnderMouse()) do
		--克雷啥时候加的client_forward_target？
		local ent = v and v.client_forward_target or v
		if ENT_util:IsValid(ent) then
			--这说明鼠标下吗有实体动作吗，那么就不会执行我的记录位置的动作pos_point_act
			local act = self:GetAction(ent, nil, rightclick) -- 但是Cherrypick是多次执行,第一次执行会给给这次点击赋值一个表,存入相关信息,第二次时间差满足才进入双击流程
			if act then
				flag = false                         -- 鼠标下的实体如果有合法的动作
				self:ToggleEntitySelection(ent, act, rightclick) -- 切换实体选择状态

				-- -- Original CherryPick code
				-- self.last_click = {prefab = ent.prefab, pos = ent:GetPosition(), action = act.action, time = current_time}

				-- 210213 null: save AnimState to support Stone Fruit Bush Pick (idle3) vs Crumble (idle4) state (blizstorm)
				self.last_click = {
					prefab = ent.prefab,
					pos = ent:GetPosition(),
					action = act.action,
					time = current_time,
					AnimState = ent.AnimState,
					-- 呼吸： 筛选烧焦的树
					ent = ent
				}

				break
			end
		end
	end
	if not self.posaction then --初始化
		self.posaction = CreateEntity()
		self.posaction.entity:AddTransform()
		self.posaction.entity:AddAnimState()
		if authormode then
			self.posaction.AnimState:SetBank("archive_resonator")
			self.posaction.AnimState:SetBuild("archive_resonator")
			self.posaction.AnimState:PlayAnimation("idle_loop", true)
		end
		self.posaction:AddTag("DECOR")
		self.posaction:AddTag("CLASSIFIED")
		self.posaction:AddTag("NOCLICK")
		posaction_postab = {}
	end
	if flag == true then                           --鼠标下无实体动作，进入记录位置动作流程pos_point_act
		local ent = TheInput:GetWorldEntityUnderMouse()
		self.posaction.ent = ent                   --记录位置动作下的实体
		local act = self:GetAction(nil, nil, rightclick) --记录动作
		if act and act.action.id and allowed_actions[act.action.id] and allowed_actions[act.action.id].isposaction then
			local pos = ent and ent:GetPosition() or TheInput:GetWorldPosition()
			if allowed_actions[act.action.id].selectposaction then
				author_print('selectposaction', pos)
				pos = allowed_actions[act.action.id].selectposaction(pos)
			end
			if not self.posaction.lastclicktime or GetTime() - self.posaction.lastclicktime >= self.double_click_speed then
				if allowed_actions[act.action.id].insertpos then
					author_print('insertpos:', pos, act.action.id)
					posaction_postab[pos] = act.action.id
				end
				if self.selected_ents[self.posaction] then
				elseif allowed_actions[act.action.id].oneclickapply then
					self.posaction.Transform:SetPosition(pos.x, 0, pos.z)
					self:SelectEntity(self.posaction, act.action.id, nil, nil, rightclick)
				end
				self.posaction.lastclicktime = GetTime()
				return --单击在这里返回
			else
				self.posaction.lastclicktime = nil
			end


			self.posaction.Transform:SetPosition(pos.x, 0, pos.z)
			self.posaction.ground = TheWorld.Map:GetTileAtPoint(pos.x, 0, pos.z)
			self.posaction.endlessaction = true
			self:SelectEntity(self.posaction, act.action.id, nil, nil, rightclick)
		end
	end
end

function ActionQueuer:OnDown(rightclick) -- 按下
	self:ClearSelectionThread()          -- 重置选择线程
	if self.inst:IsValid() and not IsHUDEntity() then
		self.clicked = true
		self:SelectionBox(rightclick)
		self:CherryPick(rightclick)
	end
end

--开关延迟补偿
function ActionQueuer:MovementPredict(enable)
	if enable then
		if self.closemovementprediction then
			ThePlayer:EnableMovementPrediction(true)
		end
		self.closemovementprediction = false
	else
		local movementprediction = Profile:GetMovementPredictionEnabled()
		if movementprediction then
			ThePlayer:EnableMovementPrediction(not movementprediction)
			self.closemovementprediction = true
		end
	end
end

--判断有没有一个动作组件
function ActionQueuer:HasActionComponent(item, actioncomponent)
	return item and item.HasActionComponent and item:HasActionComponent(actioncomponent)
end

function ActionQueuer:OnUp(rightclick) -- 抬起
	-- 210702 null: fix for Klei's mouse queue bug, clear Klei's own action queue
	ThePlayer.components.playercontroller:ClearActionHold()

	self:ClearSelectionThread()
	if self.clicked then
		self.clicked = false
		if not self.action_thread then
			if self:IsWalkButtonDown() then -- 按下移动键打断
				self:ClearSelectedEntities()
			elseif next(self.selected_ents) then -- 有选择的实体
				self:MovementPredict()
				self:ApplyToSelection() -- 选择器执行
			elseif rightclick then      -- 未选择实体实体时进入部署流程
				local active_item = INV_util:GetActiveItem()
				if active_item then
					if easy_stack[active_item.prefab] then -- 种植小木牌的
						local ent = TheInput:GetWorldEntityUnderMouse()
						if ent and ent:HasTag(easy_stack[active_item.prefab]) then
							local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, ent:GetPosition())
							self:SendAction(act, true) -- 为了粘贴小木牌
							return
						end
					end
				end
				local deploy_fn, spacing, item = get_deploy_fn(self)
				if deploy_fn then
					self:DeployToSelection(deploy_fn, spacing, item)
				end
			elseif self.inst.components.playercontroller.placer then
				self:MovementPredict()
				-- 批量部署
				local playercontroller = self.inst.components.playercontroller
				local recipe = playercontroller.placer_recipe
				local rotation = playercontroller.placer:GetRotation()
				local skin = playercontroller.placer_recipe_skin
				local builder = self.inst.replica.builder
				local spacing = recipe.min_spacing or 3.2
				self:DeployToSelection(function(self, pos, item)
					if not builder:IsBuildBuffered(recipe.name) then
						if not builder:CanBuild(recipe.name) then return false end
						builder:BufferBuild(recipe.name)
					end
					if builder:CanBuildAtPoint(pos, recipe, rotation) then
						builder:MakeRecipeAtPoint(recipe, pos, rotation, skin)
						self:Wait()
					end
					return true
				end, spacing)
			end
		end
		if self.posaction and self:IsSelectedEntity(self.posaction)
			and allowed_actions[self.selected_ents[self.posaction].id]
			and allowed_actions[self.selected_ents[self.posaction].id].frameselect then
			local active = INV_util:GetActiveItem()
			local hand = INV_util:GetHandsEquip()
			self:selectallpos(self.selected_ents[self.posaction].id, active and deploy_spacing[active.prefab]
				or action_spacing[self.selected_ents[self.posaction].id] or 2,
				active or hand)
		end
		if not self.action_thread then
			self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
			self:ClearDeployHint(true)
		end
	else
		self:ClearDeployHint(true)
	end
end

function ActionQueuer:IsWalkButtonDown()
	return self.inst.components.playercontroller:IsAnyOfControlsPressed(CONTROL_MOVE_UP, CONTROL_MOVE_DOWN,
		CONTROL_MOVE_LEFT, CONTROL_MOVE_RIGHT)
end

-- 从玩家身上拿取物品到鼠标
function ActionQueuer:GetNewActiveItem(prefab)
	local inventory = self.inst.replica.inventory
	local body_item
	if EQUIPSLOTS.BACK then
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BACK)
	else
		body_item = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
	end
	local backpack = body_item and body_item.replica.container
	for _, inv in pairs(backpack and { inventory, backpack } or { inventory }) do
		for slot, item in pairs(inv:GetItems()) do
			if item and item.prefab == prefab then
				inv:TakeActiveItemFromAllOfSlot(slot)
				return item
			end
		end
	end
end

local function IsNearOther(other, pt, min_spacing_sq, min_spacing)
	--FindEntities range check is <=, but we want <
	if min_spacing_sq <= 0 and other:HasTag("structure") then
		--special case (e.g. minisigns use DEPLOYSPACING.NONE)
		if other.deploy_extra_spacing then
			min_spacing_sq = other.deploy_extra_spacing * other.deploy_extra_spacing
		end
	elseif other.deploy_smart_radius then
		min_spacing = other.deploy_smart_radius + (min_spacing or math.sqrt(min_spacing_sq)) / 2
		min_spacing_sq = min_spacing * min_spacing
	elseif other.deploy_extra_spacing then
		min_spacing_sq = math.max(other.deploy_extra_spacing * other.deploy_extra_spacing, min_spacing_sq)
	elseif other.replica.inventoryitem then
		min_spacing = other:GetPhysicsRadius(0.5) + (min_spacing or math.sqrt(min_spacing_sq)) / 2
		min_spacing_sq = math.min(min_spacing * min_spacing, min_spacing_sq)
	end
	return other:GetDistanceSqToPoint(pt) < min_spacing_sq
end
local DEPLOY_IGNORE_TAGS = { "NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "walkableplatform", "walkableperipheral",
	"isdead" }
-- 部署
function ActionQueuer:DeployActiveItem(pos, item, skip)
	local active_item = INV_util:GetActiveItem() or self:GetNewActiveItem(item.prefab)
	if not active_item then return false end
	local inventoryitem = active_item.replica.inventoryitem
	if inventoryitem and inventoryitem:CanDeploy(pos, nil, self.inst) then
		local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, pos)
		local playercontroller = self.inst.components.playercontroller
		if playercontroller.deployplacer then
			act.rotation = playercontroller.deployplacer.Transform:GetRotation()
		end
		self:SendActionAndWait(act, true)
		if not playercontroller.ismastersim and not CompareDeploySpacing(active_item, DEPLOYSPACING.NONE) then
			while inventoryitem and inventoryitem:CanDeploy(pos, nil, self.inst) do
				Sleep(self.action_delay)
				if self.inst:HasTag("idle") then
					self:SendActionAndWait(act, true)
				end
			end
		end
	elseif not skip then --被挡住 无法部署了 尝试捡起来
		local x, y, z = pos:Get()
		local min_spacing = active_item.replica.inventoryitem ~= nil and
			active_item.replica.inventoryitem:DeploySpacingRadius() or
			DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT]
		local min_spacing_sq = min_spacing ~= nil and min_spacing * min_spacing or nil
		near_other_fn = near_other_fn or IsNearOther
		local work = false
		for _, v in ipairs(TheSim:FindEntities(x, 0, z, min_spacing + 1, nil, DEPLOY_IGNORE_TAGS)) do
			if v ~= active_item and
				v.entity:IsVisible() and
				v.components.placer == nil and
				v.entity:GetParent() == nil and
				v.replica.inventoryitem
				and v.replica.inventoryitem:CanBePickedUp(ThePlayer)
			then
				local v_min_spacing_sq = min_spacing_sq
				if near_other_fn(v, pos, v_min_spacing_sq, min_spacing) then
					if not work then
						SendRPCToServer(RPC.ReturnActiveItem, nil, nil, nil)
					end
					local act = BufferedAction(self.inst, v, ACTIONS.PICKUP)
					self:SendActionAndWait(act)
					work = true
				end
			end
		end
		if work then
			self:DeployActiveItem(pos, item, true)
		end
	end
	return true
end

-- 丢弃
function ActionQueuer:DropActiveItem(pos, item)
	local active_item = INV_util:GetActiveItem() or self:GetNewActiveItem(item.prefab)
	if not active_item then return false end
	if #TheSim:FindEntities(pos.x, 0, pos.z, 0.1, nil, unselectable_tags) == 0 then
		local act = BufferedAction(self.inst, nil, ACTIONS.DROP, active_item, pos)
		act.options.wholestack = false
		self:SendActionAndWait(act, false)
	end
	return true
end

-- 201217 null: added support for Tilling of farming tiles
-- 开垦
function ActionQueuer:TillAtPoint(pos, item)
	local x, y, z = pos:Get()
	if not INV_util:GetHandsEquip() then return false end
	if TheWorld.Map:CanTillSoilAtPoint(x, y, z) then -- 201221 null: Fix for when objects block Tilling
		local act = BufferedAction(self.inst, nil, ACTIONS.TILL, item and item:IsValid() and item, pos)
		self:SendActionAndWait(act, false)        -- false = RPC.LeftClick, avoids Geometric Placement mod's RPC.RightClick snap overrides
	end
	return true
end

-- 210103 null: added support for Wormwood planting inside farm soil grids
-- 种植
function ActionQueuer:WormwoodPlantAtPoint(pos, item)
	local active_item = INV_util:GetActiveItem() or self:GetNewActiveItem(item.prefab)
	if not active_item then return false end
	local x, y, z = pos:Get()
	if TheWorld.Map:CanTillSoilAtPoint(x, y, z) then -- Do not plant outside the farm soil tile in this scenario
		local act = BufferedAction(self.inst, nil, ACTIONS.DEPLOY, active_item, pos)
		self:SendActionAndWait(act, false)        -- 210127 null: false avoids Geometric Placement mod's RPC.RightClick snap overrides
	end
	return true
end

-- 铲地皮
function ActionQueuer:TerraformAtPoint(pos, item)
	local x, y, z = pos:Get()
	if not INV_util:GetHandsEquip() then return false end
	if TheWorld.Map:CanTerraformAtPoint(x, y, z) then
		local act = BufferedAction(self.inst, nil, ACTIONS.TERRAFORM, item, pos)
		self:SendActionAndWait(act, true)
		while TheWorld.Map:CanTerraformAtPoint(x, y, z) do
			Sleep(self.action_delay)
			if self.inst:HasTag("idle") then
				self:SendActionAndWait(act, true)
			end
		end
	end
	return true
end

-- 获取最近的实体
function ActionQueuer:GetClosestTarget()
	local mindistsq, target
	local player_pos = self.inst:GetPosition()
	for ent in pairs(self.selected_ents) do               -- 遍历已选实体
		if ENT_util:IsValid(ent) then
			local curdistsq = player_pos:DistSq(ent:GetPosition()) -- 点距
			if not mindistsq or curdistsq < mindistsq then -- 哪个点距小记录哪个
				mindistsq = curdistsq
				target = ent
			end
		else
			self:DeselectEntity(ent) -- 该实体废了，不要了
		end
	end
	return target
end

local endlesstable = {
	['junk_pile'] = {
		selectfn = function(inst)
			return inst.prefab == 'junk_pile' and not inst.AnimState:IsCurrentAnimation("idlelow")
				and not inst.AnimState:IsCurrentAnimation("looplow")
		end
	}
}
function ActionQueuer:SelectEndlessEnt(old_mouse)
	if not next(self.endless_repeat_target) then --有记录就不继续加了
		local a = self:GetClosestTarget()
		if a then
			self.endless_repeat_target.prefab = a and a.prefab
			self.endless_repeat_target.actid = self.selected_ents[a].id
			self.endless_repeat_target.item = self.selected_ents[a].item
			self.endless_repeat_target.specialtag = self.selected_ents[a].specialtag
			self.endless_repeat_target.rightclick = self.selected_ents[a].rightclick
		else
			return
		end
	end
	self.endless_repeat_target.all_prefab = self.endless_repeat_target.all_prefab or {}
	for ent in pairs(self.selected_ents) do -- 遍历已选实体
		if ENT_util:IsValid(ent) and ent.prefab
			and not self.endless_repeat_target.all_prefab[ent.prefab] then
			local data = {}
			self.endless_repeat_target.all_prefab[ent.prefab] = data
			local a = ent
			data.prefab = a and a.prefab
			data.actid = self.selected_ents[a].id
			data.item = self.selected_ents[a].item
			data.specialtag = self.selected_ents[a].specialtag
			data.rightclick = self.selected_ents[a].rightclick
		end
	end

	local entity = TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 20)
	for k, v in pairs(self.selected_ents) do
		if k and ENT_util:IsValid(k) and distsq(ThePlayer:GetPosition(), k:GetPosition()) > 40 * 40 then
			self:DeselectEntity(k)
		end
	end
	local need_prefab = self.endless_repeat_target.prefab
	local all_prefab = self.endless_repeat_target.all_prefab
	local endlesstab = endlesstable[need_prefab]
	for k, v in pairs(entity) do
		if not self:IsSelectedEntity(v) then
			local ent = v and v.client_forward_target or v
			if endlesstab then
				if endlesstab.selectfn and endlesstab.selectfn(ent) then
					--(ent, actid, item, specialtag, rightclick)
					self:SelectEntity(ent, self.endless_repeat_target.actid, self.endless_repeat_target.item,
						self.endless_repeat_target.specialtag
						, self.endless_repeat_target.rightclick)
				end
			elseif not endlesstab and ent and ENT_util:IsValid(ent) then
				if ent.prefab == need_prefab then
					if self:GetAction(ent, self.endless_repeat_target.actid, nil, old_mouse) then
						self:SelectEntity(ent, self.endless_repeat_target.actid, self.endless_repeat_target.item,
							self.endless_repeat_target.specialtag
							, self.endless_repeat_target.rightclick)
					end
				elseif all_prefab[ent.prefab] then
					local data = all_prefab[ent.prefab]
					if self:GetAction(ent, data.actid, nil, old_mouse) then
						self:SelectEntity(ent, data.actid, data.item,
							data.specialtag
							, data.rightclick)
					end
				end
			end
		end
	end
end

function ActionQueuer:MakeTool(toolfn, oldhandtool, hasclickequip)
	if not MOD_util:GetMOption("aq_automaketool", default_aq_automaketool) then return false end
	local maketool
	for recname, rec in pairs(AllRecipes) do
		if oldhandtool and (oldhandtool.prefab == (rec.product or recname))
			and IsRecipeValid(recname) and ThePlayer.replica.builder:KnowsRecipe(recname) and
			ThePlayer.replica.builder:HasIngredients(recname) then
			SendRPCToServer(RPC.MakeRecipeFromMenu, rec.rpc_id)
			maketool = true
			MOD_util:repeatsleepuntil(function(ticks)
				return ticks > 10 and INV_util:FindInInv(nil, nil, nil, function(inst)
						return toolfn(inst, oldhandtool)
					end) or hasclickequip and
					ticks > 10 and not IsBusy()
			end, 1000)
			break
		end
	end
	--[[if not maketool then
		for recname, rec in pairs(AllRecipes) do
			if toolfn(recname, oldhandtool) and IsRecipeValid(recname) and ThePlayer.replica.builder:KnowsRecipe(recname) and
				ThePlayer.replica.builder:HasIngredients(recname) then
				SendRPCToServer(RPC.MakeRecipeFromMenu, rec.rpc_id)
				maketool = true
				MOD_util:repeatsleepuntil(function(ticks)
					return ticks > 10 and INV_util:FindInInv(nil, nil, nil, function(inst)
							return toolfn(inst, oldhandtool)
						end) or hasclickequip and
						ticks > 10 and not IsBusy()
				end, 1000)
				break
			end
		end
	end]]

	return maketool
end

function ActionQueuer:IsHoldingItem(item, all)
	return item
		and item:IsValid() and ThePlayer and ThePlayer.replica.inventory and
		ThePlayer.replica.inventory:IsHolding(item, all)
end

local ban_list = {
	lureplant_rod = true,
}
function ActionQueuer:ShouldEquipSpeeditem()
	local item = INV_util:GetHandsEquip()
	if item and item:HasTag("waterproofer") and TheWorld.state.israining then
		return false
	end
	if item and item:HasTag("light") then
		return false
	end
	if item and ban_list[item.prefab] then
		return false
	end
	--[[if item.replica.inventoryitem and item.replica.inventoryitem:GetWalkSpeedMult() > 1 then
		return false
	end]]
	return true
end

-- 排队论精髓：动作线程
function ActionQueuer:ApplyToSelection(notclearbuffer)
	self.action_thread = StartThread(function()
		if not notclearbuffer then
			self.inst:ClearBufferedAction()
		end
		self.mem = {}

		--这个可能会更新，代表的需要交互的物品，不一定是拿在鼠标上的，可能是被返回到库存里面的。
		local update_item = INV_util:GetActiveItem()
		--这个在后续一直不会变
		local oldactive_item = INV_util:GetActiveItem()
		--储存最初始的手部物品
		local hand_item = INV_util:GetHandsEquip()
		local work_tool
		while self.inst:IsValid() do
			--获取最近的目标前先进行无尽选取
			if self.endless_repeat then
				self:SelectEndlessEnt(oldactive_item)
			end
			--获取最近的目标
			local target = self:GetClosestTarget()
			--无目标结束排队论，但是如果开了无尽会重新启动排队论
			if not target then break end
			--一般来说没有item，这个特殊选取的时候加的item
			update_item = ActionQueuer:IsHoldingItem(update_item, true) and
				update_item or
				update_item and
				INV_util:FindInInv(nil, nil, nil, function(inst)
					if inst.prefab == update_item.prefab then
						return true
					end
				end)
				or self.selected_ents[target].item
			local act, acttab = self:GetAction(target, self.selected_ents[target], nil, update_item)
			local time, deselect = 0, true
			local busytime = 0
			if acttab then
				--一些动作可能需要选择用于完成动作的物品（暂时没动作有这个函数）
				if acttab.selectupdateitem then
					update_item = acttab.selectupdateitem()
				end
				--对于控制器rpc,需要返回鼠标物品到库存
				if acttab.controllertable and ENT_util:FnOrNum(acttab.controllertable.needreturnactiveitem,
						{ target = target, item = update_item, time = 0, }) and not ENT_util:FnOrNum(acttab.controllertable.cancelcontroller,
						{ target = target, item = update_item, time = 0, }) then
					local returnitem = acttab.controllertable.returnfn and acttab.controllertable.returnfn() or
						returnfunction()
				end
				--在进入循环前可以执行的函数 举例：装上勋章
				if acttab.act_pre_fn then
					acttab.act_pre_fn({ target = target, item = update_item, time = 0, }, self)
				end
				--判断是否应该切手杖
				local speeditem
				if self:ShouldEquipSpeeditem() and MOD_util:GetMOption("aq_equipcane", default_aq_equipcane)
					and ENT_util:FnOrNum(acttab.equipspeeditem, { target = target, item = update_item, time = 0, })
					and not ENT_util:isOnWater(ThePlayer) then
					speeditem = self:HasAddSpeedEquipment()
					if speeditem then
						author_print('装备', speeditem)
					end
				end

				--记录物品数目 后面判断dirty
				local laststacknum = ENT_util:GetStacksize(update_item)

				self.waiting_for_break = false
				self.no_act_time = nil

				self.performaction = nil
				while acttab do
					do
						if self.mem.not_unique_target == nil then
							local num = GetTableSize(self.selected_ents)
							if num > 1 then
								self.mem.not_unique_target = true
							end
						end
					end
					--如果被玩家删除了就退出循环
					if not self:IsSelectedEntity(target) then
						author_print('break_by_delete_ent')
						break
					end
					--物品数目
					local nowstacknum = ENT_util:GetStacksize(update_item)
					local lookfor_new_inv_item
					--如果是控制器动作就更新物品update_item
					if acttab.controllertable and not ENT_util:FnOrNum(acttab.controllertable.cancelcontroller,
							{ target = target, item = update_item, time = 0, }) and oldactive_item then
						local function updatestacknumdirty()
							lookfor_new_inv_item = true
							return true
						end
						local active = ThePlayer.replica.inventory:GetActiveItem()
						local function checkitem(inst)
							if update_item and inst.prefab == update_item.prefab and (not acttab.selectitemfn or acttab.selectitemfn(inst))
								or (acttab.selectitemfn_force and acttab.selectitemfn_force({ item = inst, oldprefab = update_item.prefab })) then
								return true
							end
						end
						update_item = ActionQueuer:IsHoldingItem(update_item, true) and
							(not acttab.selectitemfn or acttab.selectitemfn(update_item)) and update_item or
							update_item and updatestacknumdirty() and
							INV_util:FindInInv(nil, nil, nil, checkitem) or active and checkitem(active) and active
						if not update_item then
							author_print('break_by_noitem')
							break
						end
					end
					--如果不是有效的目标，退出循环
					if not ENT_util:IsValid(target) then
						author_print('break_by_notvalident')
						break
					end
					--stacknumdirty break测试
					local stacknumdirty = lookfor_new_inv_item or (laststacknum ~= nowstacknum)
					if stacknumdirty and acttab.stacknumdirtyezsylisten and self:HaveAnotherSelectedEnt(target) then
						author_print('break_by_stacknumdirtyezsylisten')
						break
					end
					do --ez_listenperformaction
						if acttab.ez_listenperformaction and self.performaction and self:HaveAnotherSelectedEnt(target) then
							author_print('break_by_ez_listenperformaction')
							break
						end
					end
					--如果满足breakfn 退出循环
					if acttab.breakfn and acttab.breakfn({ target = target, item = update_item, time = time,
							stacknumdirty = stacknumdirty,
							busytime = busytime, }) then
						author_print('break_by_breakfn')
						break
					end
					--对于加速道具，尝试装备
					local speedflag = nil
					if speeditem then
						--距离较远则可以穿戴加速物品
						if math.sqrt(distsq(target:GetPosition(), ThePlayer:GetPosition())) > math.max((target:GetPhysicsRadius(0) or 0.5) + 2, 5) then
							self:EquipItem(speeditem)
							POS_util:GoToPoint(target:GetPosition().x,
								target:GetPosition().z)
							--POS_util:GoToPoint(x, z)
							speedflag = true
						end
					end
					--对于需要工具的应该尝试装备工具  如何平衡加速道具和工具之间的关系？
					if not self.waiting_for_break and not speedflag and acttab.tool and not acttab.tool(INV_util:GetHandsEquip(), hand_item) then
						work_tool = INV_util:FindInInv(nil, nil, nil, function(inst)
							return acttab.tool(inst, hand_item)
						end)
						--没工具，尝试制作
						if not work_tool and ENT_util:FnOrNum(acttab.maketool) and not self:GetAction(target, act, nil, update_item) then
							if not self:MakeTool(acttab.tool, hand_item, true) then
								author_print('break_by_notool')
								break
							end
						end
						if work_tool then
							SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, work_tool)
							--如果我的点击切装备，那么这里将不会睡眠
							MOD_util:repeatsleepuntil(function()
								return self:GetAction(target, act, nil, update_item)
							end, 15)
						end --直接发rpc防止shift按住的时候无法装备
					end
					--没动作的目标会判断是否退出循环。满足notbreakfn的时候，即使没动作也不会退出循环
					if not speedflag and (not acttab.notbreakfn or not acttab.notbreakfn(
							{ target = target, item = update_item, time = time, })) --有些操作暂时导致没动作，但是我不希望它退出排队论
						and not self:GetAction(target, act, nil, update_item) then
						--不是控制器动作会尝试拿起物品
						if ENT_util:FnOrNum(not acttab.controllertable or acttab.controllertable.cancelcontroller,
								{ target = target, item = update_item, time = 0, }) and oldactive_item then
							local active = INV_util:GetActiveItem()
							local a, b, c = INV_util:FindInInventory(nil, nil, function(inst)
								if inst.prefab == oldactive_item.prefab and (not acttab.selectitemfn or acttab.selectitemfn(inst))
									or (acttab.selectitemfn_force and acttab.selectitemfn_force({ item = inst, oldprefab = oldactive_item.prefab })) then
									return true
								end
							end)
							if a and not active then
								SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, b, c, nil)
								MOD_util:repeatsleepuntil(function(ticks)
									return self:GetAction(target, act, nil, update_item)
										or ticks > 5 and INV_util:GetActiveItem()
								end, 90)
								update_item = a
							end
							--这里是装备新的工具
						elseif acttab.tool and not acttab.tool(INV_util:GetHandsEquip(), hand_item) then --对于需要工具的应该尝试装备工具
							work_tool = INV_util:FindInInv(nil, nil, nil, function(inst)
								return acttab.tool(inst, hand_item)
							end)
							if not work_tool and ENT_util:FnOrNum(acttab.maketool) then
								if not self:MakeTool(acttab.tool, hand_item) then
									author_print('break_by_cantmaketool')
									break
								end
								work_tool = INV_util:FindInInv(nil, nil, nil, function(inst)
									return acttab.tool(inst, hand_item)
								end)
							end
							--SendRPCToServer(RPC.EquipActionItem,103991 - axe)	
							SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, work_tool) --直接发rpc防止shift按住的时候无法装备
							MOD_util:repeatsleepuntil(function(ticks)
								if ticks > 45 then
									SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, work_tool)
								end
								return work_tool == INV_util:GetHandsEquip()
							end, 90)
						end
						--如果还是没动作就退出循环
						if acttab.max_noact_time then
							self.no_act_time = (self.no_act_time or 0) + 1
							if self.no_act_time > acttab.max_noact_time then
								author_print('break_by_maxnoacttime')
								break
							end
						elseif not self:GetAction(target, act, nil, update_item) then
							author_print('break_by_noaction')
							break
						end
					end
					--这是为了无尽重复模式设置的判断walk按键是否按下
					if not speedflag and not self:IsWalkButtonDown() and not TUNING.Cheatthread then
						acttab.rpc({
							target = target,
							item = update_item,
							time = time,
							tool = work_tool,
						})
					elseif speedflag then
					else
						deselect = false
						author_print('break_by_move')
						break
					end
					--可以自定义睡眠时间 addtimefn用于增加act.time
					Sleep(acttab.sleeptime or 0)
					local addtime = not acttab.addtimefn or
						acttab.addtimefn({ target = target, item = update_item, time = time, })
					if addtime == 'resettime' then
						time = 0
					elseif addtime then
						time = time + (acttab.sleeptime or FRAMES) --部分rpc需要时间判断
					end
					if ENT_util:FnOrNum(acttab.addbusytime, { target = target, item = update_item, time = time, })
					then
						busytime = busytime + (acttab.sleeptime or FRAMES)
					end
				end
			else
				author_print('break_by_notfindact')
				local id = self.selected_ents[target] and self.selected_ents[target].id
				local actiontab = id and self:GetActionTable(id)
				if actiontab and actiontab.noactfn then
					deselect = false
					actiontab.noactfn({
						target = target,
						item = update_item,
						time = 0,
						hand =
							hand_item
					})
				end
			end
			if mem.need_clear_controls then
				mem.need_clear_controls = false
				SendRPCToServer(RPC.StopControl, CONTROL_PRIMARY)
				SendRPCToServer(RPC.StopControl, CONTROL_ACTION)
			end
			if deselect then
				--删除选择实体 deselect控制是否进入这个环节，同时影响reselectfn allowautocollect
				self:DeselectEntity(target)

				if acttab and acttab.reselectfn then
					acttab.reselectfn({ target = target, item = update_item, time = time, })
				end
				if acttab and ENT_util:FnOrNum(acttab.allowautocollect, target, self) then
					for _, ent in pairs(TheSim:FindEntities(ThePlayer:GetPosition().x, 0, ThePlayer:GetPosition().z, 4)) do
						if ent.spawntime and GetTime() - ent.spawntime < 0.5 and self:GetAction(ent, 'PICKUP') then
							self:SelectEntity(ent, 'PICKUP')
							if acttab and acttab.markfn then
								acttab.markfn(ent, target)
							end
						end
					end
				end
			end
			if acttab and acttab.exit_loop_fn then
				acttab.exit_loop_fn({ target = target, item = update_item, time = time, })
			end
			Sleep(0)
		end
		self:ClearActionThread(self.endless_repeat)
		if self.endless_repeat then
			self.inst:DoTaskInTime(0.1, function() self:ApplyToSelection(true) end)
		end
	end, "actionqueue_action_thread")
end

-- 部署器:部署函数,间距,物体
-- 这代码是我能看的？
function ActionQueuer:DeployToSelection(deploy_fn, spacing, item, preview_mode)
	if not self.TL then return end
	self:MovementPredict()
	-- 210116 null: cases for snapping positions to farm grid (Tilling, Wormwood planting on soil tiles, etc)
	--[[local snap_farm = false
	if deploy_fn == self.TillAtPoint or deploy_fn == self.WormwoodPlantAtPoint then snap_farm = true end
]]
	local data = redir_valid_pos(self, deploy_fn, spacing, item)
	local deploy_hint_limit = GetDeployHintLimit(self, deploy_fn, item)
	self:RefreshDeployHint(deploy_fn, spacing, item, nil, data, deploy_hint_limit)
	local height = data.height
	local start_x = data.start_x
	local start_z = data.start_z
	local terraforming = data.terraforming
	local width = data.width
	local spacing_x = data.spacing_x
	local spacing_z = data.spacing_z
	local X, Z = data.X, data.Z
	local diagonal = data.diagonal

	local cur_pos = Point()
	local count = { x = 0, y = 0, z = 0 }
	local row_swap = 1

	-- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
	local step = 1
	local countz2 = 0
	local countStep = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { 1, 0 } }
	if height < 1 then countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } } end -- 210130 null: bliz fix (210127)
	local deployed_pos = {}
	self.action_thread = StartThread(function()
		self.inst:ClearBufferedAction()

		while self.inst:IsValid() do
			cur_pos.x = start_x + spacing_x * count.x
			cur_pos.z = start_z + spacing_z * count.z
			if diagonal then
				if width < 1 then
					if count[Z] > height then break end
					count[X] = count[X] - 1
					count[Z] = count[Z] + 1
				else
					local row = math.floor(count.y / 2)
					if count[X] + row > width or count[X] + row < 0 then
						count.y = count.y + 1
						if count.y > height then break end
						row_swap = -row_swap
						count[X] = count[X] + row_swap - 1
						count[Z] = count[Z] + row_swap
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count.x = count.x + row_swap
					count.z = count.z + row_swap
				end
			else
				if double_snake then -- 210127 null: snake within snake deployment (thanks to blizstorm)
					if count[X] > width or count[X] < 0 then
						countz2 = countz2 +
							2 -- assume first that next major row can be progressed since this is the case most of the time (blizstorm)

						-- if countz2 > height then -- old bliz code (210115)
						if countz2 + 1 > height then -- 210130 null: bliz fix (210127)
							-- if countz2 - 1 > height then -- old bliz code (210115)
							-- if countz2 - 1 <= height then -- old bliz code (210122)
							if countz2 <= height then -- 210130 null: bliz fix (210127)
								-- countz2 = countz2 - 1 -- old bliz code (210115)
								countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } }
							else
								break
							end
						end

						step = 1
						row_swap = -row_swap
						count[X] = count[X] + row_swap
						count[Z] = countz2
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count[X] = count[X] + countStep[step][1] * row_swap
					count[Z] = count[Z] + countStep[step][2]
					step = step % 4 + 1
				else -- Regular snaking deployment
					if count[X] > width or count[X] < 0 then
						count[Z] = count[Z] + 1
						if count[Z] > height then break end
						row_swap = -row_swap
						count[X] = count[X] + row_swap
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count[X] = count[X] + row_swap
				end
			end

			local accessible_pos = cur_pos
			if terraforming then
				accessible_pos = GetAccessibleTilePosition(cur_pos)
			elseif deploy_fn == self.TillAtPoint then -- 210117 null: check if pos already Tilled
				for _, ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.005, { "soil" })) do
					if not ent:HasTag("NOCLICK") then
						accessible_pos = false
						break
					end -- Skip Tilling this position
				end
			end
			--if preview_mode then
			if accessible_pos then
				deployed_pos[accessible_pos.x .. "p" .. accessible_pos.z] = true
				if not deploy_fn(self, accessible_pos, item) then break end
			end
			self:RefreshDeployHint(deploy_fn, spacing, item, deployed_pos, data, deploy_hint_limit)
		end
		self:ClearActionThread(next(self.selected_ents))
		self.inst:DoTaskInTime(0, function() if next(self.selected_ents) then self:ApplyToSelection() end end)
	end, "actionqueue_action_thread")
end

local minitable = {}
local count = 0
local function creatminimapatpoint(pos, prefab)
	local X = SpawnPrefab(prefab or "minisign")
	X.Transform:SetPosition(pos.x, 0, pos.z)
	X.AnimState:PlayAnimation("idle", true)
	X:AddTag("DECOR")
	X:AddTag("CLASSIFIED")
	X:AddTag("NOCLICK")
	minitable[count] = X
	count = count + 1
end
function ActionQueuer:killminisign()
	for k, v in pairs(minitable) do
		if v and v.Remove then
			v:Remove()
		end
	end
	count = 0
end

function ActionQueuer:selectallpos(actid, spacing, item)
	if not self.TL then return end
	local heading, dir = GetHeadingDir()
	local diagonal = heading % 2 ~= 0
	local X, Z = "x", "z"
	if dir then X, Z = Z, X end
	local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
	local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
	local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
	local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
	local width = math.floor((self.TL:Dist(self.TR) / adjusted_spacing_x))
	local height = math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))

	local start_x, _, start_z = self.TL:Get()
	local terraforming = false

	if actid == 'TERRAFORM' or actid == 'POUR_WATER_GROUNDTILE' or
		item and item:HasTag("groundtile") then
		start_x, _, start_z = TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)
		terraforming = true
	elseif actid == 'TILL' then
		-- 210709 null: fix for 3x3 alignment on medium/huge servers (different tile offsets)
		local tilecenter = _G.Point(_G.TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)) -- center of tile
		if tilecenter.x % 4 == 0 then                                                  -- if center of tile is divisible by 4, then it's a medium/huge server
			farm3x3_offset =
				farm_spacing                                                           -- adjust offset for medium/huge servers for 3x3 grid
		end
		start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
			math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
	elseif actid == 'DROP' or item and (item:HasTag("wallbuilder") or item:HasTag("fencebuilder")) then
		start_x, start_z = math.floor(start_x) + 0.5, math.floor(start_z) + 0.5
	elseif false then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
		start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5
	end

	local cur_pos = Point()
	local count = { x = 0, y = 0, z = 0 }
	local row_swap = 1

	self.select_pos_thread = StartThread(function()
		while self.inst:IsValid() do
			cur_pos.x = start_x + spacing_x * count.x
			cur_pos.z = start_z + spacing_z * count.z
			if diagonal then
				if width < 1 then
					if count[Z] > height then break end
					count[X] = count[X] - 1
					count[Z] = count[Z] + 1
				else
					local row = math.floor(count.y / 2)
					if count[X] + row > width or count[X] + row < 0 then
						count.y = count.y + 1
						if count.y > height then break end
						row_swap = -row_swap
						count[X] = count[X] + row_swap - 1
						count[Z] = count[Z] + row_swap
						cur_pos.x = start_x + spacing_x * count.x
						cur_pos.z = start_z + spacing_z * count.z
					end
					count.x = count.x + row_swap
					count.z = count.z + row_swap
				end
			else
				if count[X] > width or count[X] < 0 then
					count[Z] = count[Z] + 1
					if count[Z] > height then break end
					row_swap = -row_swap
					count[X] = count[X] + row_swap
					cur_pos.x = start_x + spacing_x * count.x
					cur_pos.z = start_z + spacing_z * count.z
				end
				count[X] = count[X] + row_swap
			end

			local accessible_pos = Point(cur_pos.x, 0, cur_pos.z)
			if terraforming then
				accessible_pos = GetAccessibleTilePosition(cur_pos)
			elseif actid == 'TILL' then -- 210117 null: check if pos already Tilled
				for _, ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.005, { "soil" })) do
					if not ent:HasTag("NOCLICK") then
						accessible_pos = false
						break
					end -- Skip Tilling this position
				end
			end

			if accessible_pos and self:GetAction(nil, actid, nil, nil, accessible_pos) then
				posaction_postab[accessible_pos] = actid
				if authormode then
					creatminimapatpoint(accessible_pos, item and item.prefab)
				end
			end
		end
		if self.select_pos_thread then
			KillThreadsWithID(self.select_pos_thread.id)
			self.select_pos_thread:SetList(nil)
			self.select_pos_thread = nil
			self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
		end
	end, "select_pos_thread")
end

-- 农场施肥
function ActionQueuer:FertilizeTile(pos, item)
	-- 确保位置存在而且是农场地皮
	if not pos or not item or not TheWorld.Map:IsFarmableSoilAtPoint(pos.x, 0, pos.z) then return end
	self.action_thread = StartThread(function()
		self.inst:ClearBufferedAction()
		local item = INV_util:GetActiveItem()
		SendRPCToServer(RPC.ReturnActiveItem)
		while self.inst:IsValid() do -- 玩家存在且鼠标有东西
			item = item and item:IsValid() and item or item and INV_util:FindInInventory(item.prefab)
			if not item then break end
			SendRPCToServer(RPC.ControllerActionButtonDeploy, item, pos.x, pos.z)
			Sleep(0)
		end
		self:ClearActionThread()
	end, "actionqueue_action_thread")
end

--装备一个道具
function ActionQueuer:EquipItem(item)
	if not item then return end
	if not item:IsValid() then return end
	if item.replica.equippable and not item.replica.equippable:IsEquipped() then
		if not INV_util:GetActiveItem() then
			SendRPCToServer(RPC.UseItemFromInvTile, ACTIONS.EQUIP.code, item)
		else
			SendRPCToServer(RPC.ControllerUseItemOnSelfFromInvTile, ACTIONS.EQUIP.code, item)
		end
	end
end

--重复制作
function ActionQueuer:RepeatRecipe(builder, recipe, skin)
	self.action_thread = StartThread(function()
		self.inst:ClearBufferedAction()
		--act_pre_fn
		if EQUIPSLOTS.MEDAL and not ThePlayer.replica.inventory:EquipHasTag('handy_certificate')
			and ActionQueuer:CanEquipMedal() then
			local now = ThePlayer.replica.inventory:GetEquippedItem(EQUIPSLOTS.MEDAL)
			self.oldmedal = self.oldmedal or now
			local medal, k, backpack = INV_util:FindInInventory(nil, 'handy_certificate')
			if medal then --multivariate_certificate
				if now and now:HasTag('multivariate_certificate') and not medal:HasTag('multivariate_certificate') then
					SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, k, backpack)
					SendRPCToServer(RPC.SwapEquipWithActiveItem)
					SendRPCToServer(RPC.ReturnActiveItem)
				else
					self:EquipItem(medal)
				end
			end
		end
		while self.inst:IsValid() --[[ and builder:CanBuild(recipe.name) ]] do --不需要canbuild
			builder:MakeRecipeFromMenu(recipe, skin)
			Sleep(self.action_delay)
		end
		self:ClearActionThread()
	end, "actionqueue_action_thread")
end

--判断选中实体
function ActionQueuer:IsSelectedEntity(ent)
	--nil check because boolean value
	return self.selected_ents[ent] ~= nil
end

--高亮
function ActionQueuer:HighlightEntity(ent)
	if not MOD_util:GetMOption("aq_highlight", default_aq_highlight) then
		return
	end
	if not ent.components.highlight then
		ent:AddComponent("highlight")
	end
	local highlight = ent.components.highlight
	highlight.highlight_add_colour_red = nil
	highlight.highlight_add_colour_green = nil
	highlight.highlight_add_colour_blue = nil
	highlight:SetAddColour(self.color)
	highlight.highlit = true
end

--取消高亮
function ActionQueuer:UnHighlightEntity(ent)
	if ent:IsValid() and ent.components.highlight then
		ent.components.highlight:UnHighlight()
	end
end

--
function ActionQueuer:isEndLessRepeat()
	return self.endless_repeat
end

--ActionQueuer.action_thread
function ActionQueuer:hasActionThread()
	return self.action_thread
end

function ActionQueuer:hasSelectThread()
	return self.selection_thread
end

--获得动作表
function ActionQueuer:GetActionTable(actionid)
	actionid = type(actionid) == "table" and actionid.id or actionid
	return allowed_actions[actionid]
end

-- 选中实体
function ActionQueuer:SelectEntity(ent, actid, item, specialtag, rightclick)
	if self:IsSelectedEntity(ent) then return end
	self.selected_ents[ent] = { id = actid, item = item, specialtag = specialtag, rightclick = rightclick }
	--部分动作可自定义是否需要高亮
	local acttab = self:GetActionTable(actid)
	if acttab and acttab.dontneedhighlight then return end
	self:HighlightEntity(ent)
end

-- 清除选择的实体
function ActionQueuer:DeselectEntity(ent)
	if self:IsSelectedEntity(ent) then
		self.selected_ents[ent] = nil
		self:UnHighlightEntity(ent)
	end
end

-- 反转实体选中状态
function ActionQueuer:ToggleEntitySelection(ent, act, rightclick)
	if self:IsSelectedEntity(ent) then
		self:DeselectEntity(ent)
	else
		self:SelectEntity(ent, act.action.id, nil, nil, rightclick)
	end
end

-- 清除全部选择的实体
function ActionQueuer:ClearSelectedEntities()
	for ent in pairs(self.selected_ents) do
		self:DeselectEntity(ent)
	end
end

-- 清除选中线程
function ActionQueuer:ClearSelectionThread()
	self.control_click_range = self.double_click_range
	if self.selection_thread then
		KillThreadsWithID(self.selection_thread.id)
		self.selection_thread:SetList(nil)
		self.selection_thread = nil

		self:hideSelectionWidget()
	end
	self:ClearDeployHint()
	--
	if authormode then
		self:killminisign()
	end
end

function ActionQueuer:ClearActionThread(notclosemovement)
	if self.action_thread then
		KillThreadsWithID(self.action_thread.id)
		self.action_thread:SetList(nil)
		self.action_thread = nil
		self.TL, self.TR, self.BL, self.BR = nil, nil, nil, nil
		if self.posaction then
			self.posaction.endlessaction = nil
		end
		if self.oldmedal then
			self:EquipItem(self.oldmedal)
			self.oldmedal = nil
		end
		posaction_postab = {}
		if mem.need_clear_controls then
			mem.need_clear_controls = false
			SendRPCToServer(RPC.StopControl, CONTROL_PRIMARY)
			SendRPCToServer(RPC.StopControl, CONTROL_ACTION)
		end
		--[[SendRPCToServer(RPC.StopControl, CONTROL_PRIMARY)]]
	end
	--
	self:ClearDeployHint(true)
	if authormode then
		self:killminisign()
	end
	if not notclosemovement then
		self:MovementPredict(true)
	end
end

-- 这个数组用来控制什么操作可以打断排队论
local interrupt_controls = {}

-- 上下左右、攻击、检查、空格都会打断排队论
for control = CONTROL_ATTACK, CONTROL_MOVE_RIGHT do
	interrupt_controls[control] = true
end

-- 左键False右键true
local mouse_controls = { [CONTROL_PRIMARY] = false, [CONTROL_SECONDARY] = true }

-- 排队键，LSHIFT

AddComponentPostInit("playercontroller", function(self, inst)
	if inst ~= ThePlayer then return end

	ActionQueuer:InitFn(inst)
	--

	ActionQueuer:UpdateSelectionColor()

	--if MOD_util:GetMOption("aq_selectwidget", default_aq_selectwidget) then


	local PlayerControllerOnControl = self.OnControl
	self.OnControl = function(self, control, down)
		-- 左键false，右键true
		local mouse_control = mouse_controls[control]
		if mouse_control ~= nil then
			if down then
				local queuekey = MOD_util:GetMOption("aq_queuekey", default_aq_queuekey)
				if queuekey and TheInput:IsKeyDown(queuekey)
					and not TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then
					ActionQueuer:OnDown(mouse_control)
					return
				end
			else
				ActionQueuer:OnUp(mouse_control) -- 鼠标抬起该干啥干啥
			end
		end
		local result = PlayerControllerOnControl(self, control, down) -- 该干啥干啥
		if down then
			if not ActionQueuer:isEndLessRepeat() and ActionQueuer:hasActionThread()
				and not ActionQueuer:hasSelectThread() and GAME_util:InGame()
				and (interrupt_controls[control] or mouse_control == false and not TheInput:GetHUDEntityUnderMouse()) then
				ActionQueuer:ClearActionThread()
				ActionQueuer:ClearSelectedEntities()
			end
		end
		return result
	end
end)
--修改使得按着shift的时候对着人物用东西是使用
AddComponentPostInit("playeractionpicker", function(self, inst)
	local oldGetInventoryActions = self.GetInventoryActions
	function self:GetInventoryActions(useitem, right)
		local oldIsControlPressed = self.inst.components.playercontroller.IsControlPressed
		if TheInput:GetWorldEntityUnderMouse() == ThePlayer then
			self.inst.components.playercontroller.IsControlPressed = function(a, control, ...)
				if control == CONTROL_FORCE_TRADE then
					return false
				else
					return oldIsControlPressed(a, control, ...)
				end
			end
		end
		local sorted_acts = oldGetInventoryActions(self, useitem, right)

		self.inst.components.playercontroller.IsControlPressed = oldIsControlPressed
		return sorted_acts
	end
end)

-- 修改制作组件
AddClassPostConstruct("components/builder_replica", function(self)
	-- 制作物品
	local BuilderReplicaMakeRecipeFromMenu = self.MakeRecipeFromMenu
	self.MakeRecipeFromMenu = function(self, recipe, skin)
		local queuekey = MOD_util:GetMOption("aq_queuekey", default_aq_queuekey)
		if not ActionQueuer.action_thread and queuekey and TheInput:IsKeyDown(queuekey)
			and not recipe.placer --[[ and self:CanBuild(recipe.name) ]] then
			ActionQueuer:RepeatRecipe(self, recipe, skin)
		else
			return BuilderReplicaMakeRecipeFromMenu(self, recipe, skin)
		end
	end
end)
--高亮组件
AddComponentPostInit("highlight", function(self, inst)
	local HighlightHighlight = self.Highlight
	self.Highlight = function(self, ...)
		if ActionQueuer.selection_thread or ActionQueuer:IsSelectedEntity(inst) then return end
		return HighlightHighlight(self, ...)
	end
	local HighlightUnHighlight = self.UnHighlight
	self.UnHighlight = function(self)
		if ActionQueuer:IsSelectedEntity(inst) then return end
		return HighlightUnHighlight(self)
	end
end)
--网格
local turf_grid_visible = false
local turf_grid = {}
local turf_size = 4

MOD_util:AddKeyUpHandler("aq_gridkey", default_aq_gridkey, function()
	if not GAME_util:InGame() then return end
	if turf_grid_visible then
		for _, grid in pairs(turf_grid) do
			grid:Hide()
		end
		turf_grid_visible = false
		return
	end
	local center_x, _, center_z = TheWorld.Map:GetTileCenterPoint(ThePlayer.Transform:GetWorldPosition())
	local radius = 10 * turf_size
	local count = 1
	for x = center_x - radius, center_x + radius, turf_size do
		for z = center_z - radius, center_z + radius, turf_size do
			if not turf_grid[count] then
				turf_grid[count] = SpawnPrefab("gridplacer")
				turf_grid[count].AnimState:SetAddColour(unpack(PLAYERCOLOURS['FIREBRICK']))
			end
			turf_grid[count].Transform:SetPosition(x, 0, z)
			turf_grid[count]:Show()
			count = count + 1
		end
	end
	turf_grid_visible = true
end)
--c解控
local data = RW_util:LoadData('lastcraft') or {}
local last_recipe, last_skin = data.recipe, data.skin

MOD_util:AddKeyUpHandler("aq_recipekey", default_aq_recipekey, function()
	if not GAME_util:InGame() then return end
	--然后尝试解控和制作
	local recipe, skin = last_recipe, last_skin
	if not recipe then return end
	local last_recipe_name = STRINGS.NAMES[recipe.name:upper()] or "未知"
	if recipe and recipe.placer == nil then
		local can_build = ThePlayer.replica.builder:CanBuild(recipe.name)
		if can_build then
			ThePlayer.replica.builder:MakeRecipeFromMenu(recipe, skin)
		else
			PLAYER_util:TryCraft(true)
		end
	elseif recipe and recipe.placer and ThePlayer.replica.builder:HasIngredients(recipe.name) then
		ThePlayer.replica.builder:BufferBuild(recipe.name)
		ThePlayer.components.playercontroller:StartBuildPlacementMode(recipe, skin)
	else
		PLAYER_util:TryCraft(true)
	end
	return PLAYER_util:Say("尝试制作:" .. last_recipe_name)
end)
-- 修改制作组件
AddClassPostConstruct("components/builder_replica", function(self)
	-- 制作物品
	local BuilderReplicaMakeRecipeFromMenu = self.MakeRecipeFromMenu
	function self:MakeRecipeFromMenu(recipe, skin, ...)
		-- 记录上次制作的物品和皮肤
		last_recipe, last_skin = recipe, skin
		data.recipe, data.skin = recipe, skin
		RW_util:SaveData(data, 'lastcraft')
		return BuilderReplicaMakeRecipeFromMenu(self, recipe, skin, ...)
	end

	-- 制作建筑
	local BuilderReplicaMakeRecipeAtPoint = self.MakeRecipeAtPoint
	function self:MakeRecipeAtPoint(recipe, pt, rot, skin, ...)
		last_recipe, last_skin = recipe, skin
		data.recipe, data.skin = recipe, skin
		RW_util:SaveData(data, 'lastcraft')
		return BuilderReplicaMakeRecipeAtPoint(self, recipe, pt, rot, skin, ...)
	end
end)

-- 修改高亮组件
--[[ AddComponentPostInit("highlight", function(self, inst)
    local HighlightHighlight = self.Highlight
    self.Highlight = function(self, ...)
        if ActionQueuer.selection_thread or ActionQueuer:IsSelectedEntity(inst) then return end
        HighlightHighlight(self, ...)
    end
    local HighlightUnHighlight = self.UnHighlight
    self.UnHighlight = function(self, ...)
        if ActionQueuer:IsSelectedEntity(inst) then return end
        HighlightUnHighlight(self, ...)
    end
end) ]]
--for minimizing the memory leak in geo
--hides the geo grid during an action queue
-- 隐藏网格 mmdx--dont want to hide placer
--[[ AddComponentPostInit("placer", function(self, inst)
    local PlacerOnUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        self.disabled = ActionQueuer.action_thread ~= nil
        PlacerOnUpdate(self, ...)
    end
end) ]]

--优先进打包，双击移动掉落优化
local lasttrade, lastdrop = { time = -100 }, { time = -100 }
local banitem = {
	['wortox_soul'] = true,
}
AddClassPostConstruct("widgets/invslot", function(self)
	function self:FindBestContainer(item, containers, exclude_containers)
		if item == nil or containers == nil then
			return
		end
		--Construction containers
		--NOTE: reusing containerwithsameitem variable
		local containerwithsameitem = self.owner ~= nil and self.owner.components.constructionbuilderuidata ~= nil and
			self.owner.components.constructionbuilderuidata:GetContainer() or nil
		if containerwithsameitem ~= nil then
			if containers[containerwithsameitem] ~= nil and (exclude_containers == nil or not exclude_containers[containerwithsameitem]) then
				local slot = self.owner.components.constructionbuilderuidata:GetSlotForIngredient(item.prefab)
				if slot ~= nil then
					local container = containerwithsameitem.replica.container
					if container ~= nil and container:CanTakeItemInSlot(item, slot) then
						local existingitem = container:GetItemInSlot(slot)
						if existingitem == nil or (container:AcceptsStacks() and existingitem.replica.stackable ~= nil and not existingitem.replica.stackable:IsFull()) then
							return containerwithsameitem
						end
					end
				end
			end
			containerwithsameitem = nil
		end

		--local containerwithsameitem = nil --reused with construction containers code above
		local containerwithemptyslot = nil
		local containerwithnonstackableslot = nil
		local containerwithlowpirority = nil
		for k, v in pairs(containers) do
			if exclude_containers == nil or not exclude_containers[k] then
				local container = k.replica.container or k.replica.inventory
				if container ~= nil and container:CanTakeItemInSlot(item) then
					local isfull = container:IsFull()
					if k and (k.prefab == 'bundle_container' or k.prefab == 'cookpot') then
						if not isfull then
							return k
						elseif isfull and not container:AcceptsStacks() then

						else
							for k1, v1 in pairs(container:GetItems()) do
								if v1.prefab == item.prefab and v1.skinname == item.skinname then
									if isfull and v1.replica.stackable ~= nil and not v1.replica.stackable:IsFull() then
										return k
									end
								end
							end
						end
					end
					if container:AcceptsStacks() then
						if not isfull and containerwithemptyslot == nil then
							if container.lowpriorityselection then
								containerwithlowpirority = k
							else
								containerwithemptyslot = k
							end
						end
						if item.replica.equippable ~= nil and container == k.replica.inventory then
							local equip = container:GetEquippedItem(item.replica.equippable:EquipSlot())
							if equip ~= nil and equip.prefab == item.prefab and equip.skinname == item.skinname then
								if equip.replica.stackable ~= nil and not equip.replica.stackable:IsFull() then
									return k
								elseif not isfull and containerwithsameitem == nil then
									containerwithsameitem = k
								end
							end
						end
						for k1, v1 in pairs(container:GetItems()) do
							if v1.prefab == item.prefab and v1.skinname == item.skinname then
								if not isfull or v1.replica.stackable ~= nil and not v1.replica.stackable:IsFull() then
									containerwithsameitem = k
								end
								--[[ if v1.replica.stackable ~= nil and not v1.replica.stackable:IsFull() then
                                        if container.lowpriorityselection then
                                            containerwithlowpirority = k
                                        else
                                            return k
                                        end
                                    elseif not isfull and containerwithsameitem == nil then
                                        containerwithsameitem = k
                                    end ]]
							end
						end
					elseif not isfull and containerwithnonstackableslot == nil then
						containerwithnonstackableslot = k
					end
				end
			end
		end
		return containerwithsameitem or containerwithemptyslot or containerwithnonstackableslot or
			containerwithlowpirority
	end

	local oldOnControl = self.OnControl
	function self:OnControl(control, down)
		if down and control == CONTROL_ACCEPT then
			if TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then
			elseif TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
				local stack_mod = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
				local slot_number = self.num
				local character = ThePlayer
				local inventory = character and character.replica.inventory or nil
				local container = self.container
				local container_item = container and container:GetItemInSlot(slot_number) or nil
				if GetTime() - lasttrade.time < 0.5 and slot_number == lasttrade.slot and lasttrade.container == container
					and TheInput:IsControlPressed(CONTROL_FORCE_ATTACK) then
					--k.prefab == 'cookpot'
					local replica = container.inst and container.inst.replica
					local a = replica and replica.container or
						replica and replica.inventory
					if a then
						if lasttrade.dest_inst.Network:GetNetworkID() ~= ThePlayer.Network:GetNetworkID() then
							for k, v in pairs(ThePlayer.replica.inventory:GetItems()) do
								if lasttrade.container_item and (v.prefab == lasttrade.container_item.prefab
										or ActionQueuer and ActionQueuer.RegardAsSame and ActionQueuer:RegardAsSame(v.prefab, lasttrade.container_item.prefab)) then
									SendRPCToServer(RPC.MoveInvItemFromAllOfSlot, k, lasttrade.dest_inst)
								end
							end
						end
						for k, v in pairs(ThePlayer.replica.inventory:GetOpenContainers() or {}) do
							if k and k.replica and k.replica.container and (lasttrade.dest_inst.Network:GetNetworkID() ~= k.Network:GetNetworkID()) then --如果是空表不知道k是不是nil??以防万一还是判定空
								for kkk, vvv in pairs(k.replica.container:GetItems()) do
									local stackable = vvv.replica and vvv.replica.stackable
									if lasttrade.container_item and (vvv.prefab == lasttrade.container_item.prefab
											or ActionQueuer and ActionQueuer.RegardAsSame and ActionQueuer:RegardAsSame(vvv.prefab, lasttrade.container_item.prefab)) then
										if stackable and stackable:MaxSize() == math.huge then
											for i = 1, 15 do
												SendRPCToServer(RPC.MoveItemFromAllOfSlot, kkk, k,
													lasttrade.dest_inst)
											end
										else
											SendRPCToServer(RPC.MoveItemFromAllOfSlot, kkk, k,
												lasttrade.dest_inst) --目标是ThePlayer写nil
										end
									end
								end
							end
						end
					end
					lasttrade = { time = -100 }
					return
				end
				if character ~= nil and inventory ~= nil and container_item ~= nil then
					local opencontainers = inventory:GetOpenContainers()
					if next(opencontainers) == nil then
						return
					end
					local overflow = inventory:GetOverflowContainer()
					local backpack = nil
					if overflow ~= nil and overflow:IsOpenedBy(character) then
						backpack = overflow.inst
						overflow = backpack.replica.container
						if overflow == nil then
							backpack = nil
						end
					else
						overflow = nil
					end
					--find our destination container
					local dest_inst = nil
					if container == inventory then --如果是人物的物品栏
						local playercontainers = backpack ~= nil and { [backpack] = true } or nil
						dest_inst = self:FindBestContainer(container_item, opencontainers, playercontainers)
							or self:FindBestContainer(container_item, playercontainers)
					elseif container == overflow then --如果是人物的背包
						dest_inst = self:FindBestContainer(container_item, opencontainers, { [backpack] = true })
							or (inventory:IsOpenedBy(character)
								and self:FindBestContainer(container_item, { [character] = true })
								or nil)
					else
						local exclude_containers = { [container.inst] = true }
						if backpack ~= nil then
							exclude_containers[backpack] = true
						end
						dest_inst = self:FindBestContainer(container_item, opencontainers, exclude_containers) or
							(inventory:IsOpenedBy(character) and character or backpack)
					end
					if dest_inst ~= nil then
						if stack_mod and
							container_item.replica.stackable ~= nil and
							container_item.replica.stackable:IsStack() then
							lasttrade.slot = slot_number
							lasttrade.dest_inst = dest_inst
							lasttrade.time = GetTime()
							lasttrade.container = container
							lasttrade.container_item = container_item
							--container:MoveItemFromHalfOfSlot(slot_number, dest_inst)
						else
							lasttrade.slot = slot_number
							lasttrade.dest_inst = dest_inst
							lasttrade.time = GetTime()
							lasttrade.container = container
							lasttrade.container_item = container_item
							--container:MoveItemFromAllOfSlot(slot_number, dest_inst)
						end
						--TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
					else
						--TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
					end
				end
			end
		end
		return oldOnControl(self, control, down)
	end

	local olddrop = self.DropItem
	local task
	function self:DropItem(wholestack)
		if self.owner == lastdrop.owner and self.tile == lastdrop.tile and GetTime() - lastdrop.time < default_dropcheck_internal then
			if task then task:Cancel() end
			if lastdrop.item and banitem[lastdrop.item.prefab] then
			else
				local item = INV_util:FindInInv(nil, nil, nil, function(inst)
					if inst.prefab == lastdrop.item.prefab or ActionQueuer and ActionQueuer.RegardAsSame
						and ActionQueuer.RegardAsSame(ActionQueuer, lastdrop.item.prefab, inst) then
						return true
					end
				end)
				--banitem
				task = ThePlayer:DoPeriodicTask(FRAMES, function()
					if item and item:IsValid() and ThePlayer.replica.inventory:IsHolding(item, true) then
					else
						item = lastdrop.item and INV_util:FindInInv(nil, nil, nil, function(inst)
							if inst.prefab == lastdrop.item.prefab or ActionQueuer and ActionQueuer.RegardAsSame
								and ActionQueuer.RegardAsSame(ActionQueuer, lastdrop.item.prefab, inst) then
								return true
							end
						end)
					end
					if not item or KEY_util:MoveKeyDown() then
						task:Cancel()
						task = nil
					end

					SendRPCToServer(RPC.DropItemFromInvTile, item, wholestack or nil)
				end)
				return
			end
		end
		if self.owner and self.owner.replica.inventory and self.tile and self.tile.item then
			lastdrop.owner = self.owner
			lastdrop.tile = self.tile
			lastdrop.item = self.tile.item
			lastdrop.time = GetTime()
		end
		return olddrop(self, wholestack)
	end
end)


MOD_util:AddKeyUpHandler("aq_endlesskey", default_aq_endlesskey, function()
	if not GAME_util:InGame() then return end
	local self = ActionQueuer
	if self.endless_repeat then
		ThePlayer.components.talker:Say("无尽重复模式关闭")
		self.endless_repeat_target = {} --记录
		self.endless_repeat = false
	else
		ThePlayer.components.talker:Say("无尽重复模式开启")
		self.endless_repeat_target = {} --记录
		self.endless_repeat = true
	end
end)

MOD_util:AddKeyUpHandler("aq_autocollectkey", default_aq_autocollectkey, function()
	if not GAME_util:InGame() then return end

	local self = ActionQueuer

	if self.autocollect == 1 then
		ThePlayer.components.talker:Say("排队论:挖树根模式")
		self.autocollect = 2
	elseif self.autocollect == 2 then
		ThePlayer.components.talker:Say("排队论:挖树根且收集模式")
		self.autocollect = 3
	elseif self.autocollect == 3 then
		ThePlayer.components.talker:Say("排队论:收集模式")
		self.autocollect = 4
	else
		ThePlayer.components.talker:Say("排队论:收集模式关闭")
		self.autocollect = 1
	end
end)
--------------------模组设置界面-------------------
if MOD_util:CanAddSetting() then
	local pagename = "黑化排队论"
	local pageorder = 1
	local buttonname = pagename
	local pagetitle = pagename .. "设置"
	local enabledisableoption = { { text = "禁用", data = false }, { text = "启用", data = true } }
	local function MakeOption(key, describe, default, options)
		if default == nil then default = true end
		return {
			description = describe,
			key = key,
			default = default,
			options = options or enabledisableoption,
		}
	end
	local option_colour = {}
	for i = 0, 255, 5 do
		table.insert(option_colour, { text = tostring(i), data = i })
	end
	local option_opacity = {}
	for i = 0, 1, 0.1 do
		table.insert(option_opacity, { text = tostring(i), data = i })
	end
	local opt_1_80 = {}
	for i = 0, 80, 5 do
		table.insert(opt_1_80, { text = tostring(i), data = i })
	end
	local updatecolor = function()
		ActionQueuer:UpdateSelectionColor()
	end
	MOD_util:CreatePage(pagename, {
		title = pagetitle,
		buttondata = { name = buttonname },
		order = pageorder,
		all_options = {
			{
				description = "排队论框选提示框",
				key = "aq_selectwidget",
				options = enabledisableoption,
				default = default_aq_selectwidget,
			},
			{
				description = "框选提示框颜色修改\n(默认红色r 255,g 89,b 46)",
			},
			--ActionQueuer:UpdateSelectionColor()
			{
				description = "修改r(默认255)",
				key = "aq_selectwidget_r",
				options = option_colour,
				default = default_aq_selectwidget_r,
				onapplyfn = updatecolor,
			},
			{
				description = "修改g(默认89)",
				key = "aq_selectwidget_g",
				options = option_colour,
				default = default_aq_selectwidget_g,
				onapplyfn = updatecolor,
			},
			{
				description = "修改b(默认46)",
				key = "aq_selectwidget_b",
				options = option_colour,
				default = default_aq_selectwidget_b,
				onapplyfn = updatecolor,
			},
			{
				description = "透明度",
				key = "aq_selectwidget_opacity",
				options = option_opacity,
				default = default_aq_selectwidget_opacity,
				onapplyfn = updatecolor,
			},
			{
				description = "按键绑定",
			},
			--default_aq_selectwidget_opacity
			{
				description = "排队论启动按键",
				MapKey = true,
				key = "aq_queuekey",
				default = default_aq_queuekey,
			},
			MakeOption("aq_highlight", "高亮显示选中目标", default_aq_highlight, enabledisableoption),
			{
				description = "网格显示按键",
				MapKey = true,
				key = "aq_gridkey",
				default = default_aq_gridkey,
			}, {
			description = "重复制作按键",
			MapKey = true,
			key = "aq_recipekey",
			default = default_aq_recipekey,
		},

			{
				description = "无尽重复模式",
				MapKey = true,
				key = "aq_endlesskey",
				default = default_aq_endlesskey,
			},
			{
				description = "无尽部署模式",
				key = "aq_endless_deploy",
				default = default_aq_endless_deploy,
				options = enabledisableoption,
			},
			{
				description = "默认收集模式",
				key = "aq_autocollect",
				default = default_aq_autocollect,
				options = {
					{ text = "关闭", data = 1 },
					{ text = "挖树根模式", data = 2 },
					{ text = "挖树根且收集", data = 3 },
					{ text = "收集模式", data = 4 },
				},
			}, {
			description = "切换收集模式",
			MapKey = true,
			key = "aq_autocollectkey",
			default = default_aq_autocollectkey,
		},
			{
				description = "功能开关",
			},
			--[[  {
                description = "提灯砍树",
                options = enabledisableoption,
                key = "aq_lantern_chop",
                default = default_aq_lantern_chop,
            }, ]] {
			description = "部分动作自动切手杖",
			options = enabledisableoption,
			key = "aq_equipcane",
			default = default_aq_equipcane,
		}, {
			description = "双击选取的范围",
			wait_input = true,
			key = "aq_double_click_range",
			default = default_aq_double_click_range,
		},
			{
				description = "自动制作工具",
				key = "aq_automaketool",
				options = enabledisableoption,
				default = default_aq_automaketool,
			},
			{
				description = "显示部署预览",
				key = "aq_showdeploy",
				options = enabledisableoption,
				default = default_aq_showdeploy,
			},
			{
				description = "自动装备勋章",
				key = "aq_autoequipmedal",
				options = enabledisableoption,
				default = default_aq_autoequipmedal,
			},
		}
	})
end
