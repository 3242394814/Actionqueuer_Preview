GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})
local function getval(fn, path)
	if fn == nil or type(fn)~="function" then return end
	local val = fn
	local i
	for entry in path:gmatch("[^%.]+") do
		i = 1
		while true do
			local name, value = debug.getupvalue(val, i)
			if name == entry then
				val = value
				break
			elseif name == nil then
				return
			end
			i = i + 1
		end
	end
	return val, i
end

local function setval(fn, path, new)
	if fn == nil or type(fn)~="function" then return end
	local val = fn
	local prev = nil
	local i
	for entry in path:gmatch("[^%.]+") do
		i = 1
		prev = val
		while true do
			local name, value = debug.getupvalue(val, i)
			if name == entry then
				val = value
				break
			elseif name == nil then
				return
			end
			i = i + 1
		end
	end
	debug.setupvalue(prev, i, new)
end

local GetAQConfigData = function(name)
    return KnownModIndex:IsModEnabledAny("workshop-3018652965") and GLOBAL.GetModConfigData(name, "workshop-3018652965") or
            KnownModIndex:IsModEnabledAny("workshop-2873533916") and GLOBAL.GetModConfigData(name, "workshop-2873533916")
end

AQ_preview_max = GetModConfigData("number") or 80
AQ_preview_color = PLAYERCOLOURS[GetModConfigData("color")] or PLAYERCOLOURS["GREEN"] -- 颜色
AQ_preview_dont = GetModConfigData("dont_color") or false -- 不要变色
AQ_highlight = GetModConfigData("highlight") or 0.3

-- 基本定义（来自行为学模组）
local GeoUtil = require("utils/geoutil")
local headings = {[0] = true, [45] = false, [90] = false, [135] = true, [180] = true, [225] = false, [270] = false, [315] = true, [360] = true}
local easy_stack = {minisign_item = "structure", minisign_drawn = "structure", spidereggsack = "spiderden"}
local deploy_spacing = {wall = 1, fence = 1, trap = GetAQConfigData("tooth_trap_spacing") or 2, mine = 2, turf = 4, moonbutterfly = 4}
local drop_spacing = {trap = 2}
local action_thread_id = "actionqueue_action_thread"

-- 估计是刨地用的点位
local offsets = {}
for i, offset in pairs({{0,0},{0,1},{1,1},{1,0},{1,-1},{0,-1},{-1,-1},{-1,0},{-1,1}}) do
    offsets[i] = Point(offset[1] * 1.5, 0, offset[2] * 1.5)
end

local unselectable_tags = {"DECOR", "FX", "INLIMBO", "NOCLICK", "player"}
local selection_thread_id = "actionqueue_selection_thread"


-- 201221 null: added support for snapping Tills to different farm tile grids
local farm_grid = GetAQConfigData("farm_grid") or "3x3"
-- local farm_spacing = 1.333 -- 210116 null: 1.333 (4/3) = selection box spacing for Tilling, Wormwood planting, etc

-- 210202 null: selection box spacing / offset for Tilling, Wormwood planting, etc
local farm_spacing = 4/3 -- 210202 null: use 4/3 higher precision to prevent alignment issues at edge of maps
local farm3x3_offset = farm_spacing / 2 -- 210202 null: 3x3 grid offset, use 4/3/2 to prevent alignment issues at edge of maps

local double_snake = GetAQConfigData("double_snake") or  false -- 210127 null: support for snaking within snaking in DeployToSelection()

-- 210116 null: 4x4 grid offsets for each heading
local offsets_4x4 = { -- these are basically margin/offset multipliers, selection box often starts from adjacent tile
    [0] = {x = 3, z = 3}, -- heading of 0 and 360 are the same
    [45] = {x = 1, z = 3}, 
    [90] = {x = -1, z = 3}, 
    [135] = {x = -1, z = 1}, 
    [180] = {x = -1, z = -1}, 
    [225] = {x = 1, z = -1}, 
    [270] = {x = 3, z = -1}, 
    [315] = {x = 3, z = 1}, 
    [360] = {x = 3, z = 3}}

local DebugPrint = GetModConfigData("debug_mode") and function(...)
    print("[行为学预览] ",...)
end or function() --[[disabled]] end

local function GetDeploySpacing(item)
    for key, spacing in pairs(deploy_spacing) do
        if item.prefab:find(key) or item:HasTag(key) then return spacing end
    end
    local spacing = item.replica.inventoryitem:DeploySpacingRadius()
    return spacing ~= 0 and spacing or 1
end

local function GetDropSpacing(item)
    for key, spacing in pairs(drop_spacing) do
        if item.prefab:find(key) or item:HasTag(key) then return spacing end
    end
    return 1
end

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
    local ent_blockers = TheSim:FindEntities(pos.x, 0, pos.z, 4, {"blocker"})
    for _, offset in pairs(offsets) do
        local offset_pos = offset + pos
        for _, ent in pairs(ent_blockers) do
            local ent_radius = ent:GetPhysicsRadius(0) + 0.6 --character size + 0.1
            if offset_pos:DistSq(ent:GetPosition()) < ent_radius * ent_radius then
                offset_pos = nil
                break
            end
        end
        if offset_pos then return offset_pos end
    end
    return nil
end

local function GetWorldPosition(screen_x, screen_y)
    return Point(TheSim:ProjectScreenPos(screen_x, screen_y))
end

local function IsValidEntity(ent)
    return ent and ent.Transform and ent:IsValid() and not ent:HasTag("INLIMBO")
end

local last_Width_Height_String = ""

-- 兼容几何布局
local gp_mod = KnownModIndex:IsModEnabledAny("workshop-351325790")
local gp_mod_Snap = nil
local gp_mod_CTRL_setting

-- 兼容耕地对齐
local st_mode = function()
    return ThePlayer and ThePlayer.components and ThePlayer.components.snaptiller and ThePlayer.components.snaptiller.snapmode or 0
end

if gp_mod then
    AddClassPostConstruct("components/builder_replica", function(inst)
        gp_mod_Snap = getval(inst.MakeRecipeAtPoint,"Snap")
    end)
    gp_mod_CTRL_setting = function()
        return GLOBAL.GetModConfigData("CTRL","workshop-351325790")
    end
else
    print("[行为学预览] 未检测到几何布局模组开启")
end

AddComponentPostInit("actionqueuer",function(ActionQueuer)

-- 220410 null: alternative method to attempt Attack Queuing without excessive delays
function ActionQueuer:SendAttackLoop(act, pos, target) -- 给排队论加强Mod擦个屁股
    SendRPCToServer(RPC.LeftClick, act.action.code, pos.x, pos.z, target, false, 10, act.action.canforce, act.action.mod_name)
        -- Note that using this to attack causes subsequent client attack actions to always loop (even if not Attack Queuing)
    self:Wait(act.action, target) -- wait after attack to prevent freeze/crash
end

-- 这个函数不好HOOK，所以暴力覆盖
function ActionQueuer:DeployToSelection(deploy_fn, spacing, item)
    local DebugPrint = TUNING.ACTION_QUEUE_DEBUG_MODE and function(...)
        print("[行为学] ",...)
    end or function() --[[disabled]] end


    if not self.TL then return end

    -- 210116 null: cases for snapping positions to farm grid (Tilling, Wormwood planting on soil tiles, etc)
    local snap_farm = false
    if deploy_fn == self.TillAtPoint or deploy_fn == self.WormwoodPlantAtPoint then snap_farm = true end
    if snap_farm then
        if farm_grid == "4x4" then spacing = 1.26 -- 210116 null: different spacing for 4x4 grid
        elseif farm_grid == "2x2" then spacing = 2 -- 210609 null: different spacing for 2x2 grid
        end
    end 

    local heading, dir = GetHeadingDir()
    local diagonal = heading % 2 ~= 0
    DebugPrint("Heading:", heading, "Diagonal:", diagonal, "Spacing:", spacing)
    DebugPrint("TL:", self.TL, "TR:", self.TR, "BL:", self.BL, "BR:", self.BR)
    local X, Z = "x", "z"
    if dir then X, Z = Z, X end
    local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
    local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
    local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
    local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
    local width = math.floor(self.TL:Dist(self.TR) / adjusted_spacing_x)
    local height = self.endless_deploy and 100 or math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))
    DebugPrint("Width:", width + 1, "Height:", height + 1) --since counting from 0
    local start_x, _, start_z = self.TL:Get()
    local terraforming = false

    if deploy_fn == self.WaterAtPoint or -- 201217 null: added support for Watering of farming tiles
       deploy_fn == self.FertilizeAtPoint or -- 201223 null: added support for Fertilizing of farming tiles
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
        local tilepos = _G.Point(tilecenter.x - 2, 0, tilecenter.z - 2) -- corner of tile
        if tilecenter.x % 4 == 0 then -- if center of tile is divisible by 4, then it's a medium/huge server
            farm3x3_offset = farm_spacing -- adjust offset for medium/huge servers for 3x3 grid
        end

        if farm_grid == "4x4" then -- 4x4 grid
            -- 4x4 grid: spacing = 1.26, offset/margins = 0.11
            start_x, start_z = tilepos.x + math.floor((start_x - tilepos.x)/1.26 + 0.5) * 1.26 + 0.11 * offsets_4x4[heading].x, 
                               tilepos.z + math.floor((start_z - tilepos.z)/1.26 + 0.5) * 1.26 + 0.11 * offsets_4x4[heading].z 

        elseif farm_grid == "2x2" then -- 210609 null: 2x2 grid: spacing = 2 (4/2), offset = 1 (4/2/2)
            start_x, start_z = math.floor(start_x / 2) * 2 + 1, 
                               math.floor(start_z / 2) * 2 + 1

        else -- 3x3 grid: spacing = 1.333 (4/3), offset = 0.665 (4/3/2)
            -- start_x, start_z = math.floor(start_x * 0.75 + 0.5) * 1.333 + 0.665, 
            --                    math.floor(start_z * 0.75 + 0.5) * 1.333 + 0.665

            -- 210201 null: /0.75 (3/4) instead of *1.333 (4/3) to better support edge of large -1600 to 1600 maps (blizstorm)
            -- start_x, start_z = math.floor(start_x * 0.75 + 0.5) / 0.75 + 0.665, 
            --                    math.floor(start_z * 0.75 + 0.5) / 0.75 + 0.665
            start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset, 
                               math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
                               -- 210202 null: remove +0.5 floored rounding for more consistent wormwood placements (blizstorm)
                               -- 210202 null: use more precise 3x3 grid offset for better alignment at edge of maps
        end

    elseif self.deploy_on_grid then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
        start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5

    end

    local cur_pos = Point()
    local count = {x = 0, y = 0, z = 0}
    local row_swap = 1
    
    -- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
    local step = 1
    local countz2 = 0
    local countStep = {{0,1},{1,0},{0,-1},{1,0}}
    if height < 1 then countStep = {{1,0},{1,0},{1,0},{1,0}} end -- 210130 null: bliz fix (210127)

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
                        countz2 = countz2 + 2 -- assume first that next major row can be progressed since this is the case most of the time (blizstorm)

                        -- if countz2 > height then -- old bliz code (210115)
                        if countz2 + 1 > height then -- 210130 null: bliz fix (210127)

                            -- if countz2 - 1 > height then -- old bliz code (210115)
                            -- if countz2 - 1 <= height then -- old bliz code (210122)
                            if countz2 <= height then -- 210130 null: bliz fix (210127)

                                -- countz2 = countz2 - 1 -- old bliz code (210115)
                                countStep={{1,0},{1,0},{1,0},{1,0}}

                            else break end
                        end

                        step = 1
                        row_swap = -row_swap
                        count[X] = count[X] + row_swap
                        count[Z] = countz2
                        cur_pos.x = start_x + spacing_x * count.x
                        cur_pos.z = start_z + spacing_z * count.z
                    end
                    count[X] = count[X] + countStep[step][1]*row_swap
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
            -- 210116 null: not needed anymore
            -- elseif snap_farm then -- 210116 null: (Tilling, Wormwood planting on soil tile)
            --     accessible_pos = GetSnapTillPosition(cur_pos) -- Snap pos to farm grid

            elseif deploy_fn == self.TillAtPoint then -- 210117 null: 检查pos是否已耕作
                for _,ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.05, {"soil"})) do
                    if not ent:HasTag("NOCLICK") then
                        accessible_pos = false
                        break
                    end -- Skip Tilling this position
                end
            elseif ThePlayer.replica.inventory and ThePlayer.replica.inventory:GetActiveItem() and not (deploy_fn == self.DropActiveItem) and  -- 鼠标拿着物品&不要是丢弃物品状态
                    not (
                        (ThePlayer.replica.inventory:GetActiveItem()._custom_candeploy_fn and -- 如果有自定义规则，优先按自定义规则判定
                            ThePlayer.replica.inventory:GetActiveItem():_custom_candeploy_fn( -- 自定义规则说不能放在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos -- 兼容几何布局校准后的点位
                            )
                        )
                        or
                        (TheWorld.Map:CanDeployAtPoint( -- 不能放置在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                                    ThePlayer.replica.inventory:GetActiveItem()
                                )
                        )
                    )
                    or ThePlayer.components.playercontroller and ThePlayer.components.playercontroller.placer and ThePlayer.components.playercontroller.placer_recipe and not -- 鼠标上打包的建筑是否可以放置
                        TheWorld.Map:CanDeployRecipeAtPoint(
                            accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                            ThePlayer.components.playercontroller.placer_recipe,
                            ThePlayer.components.playercontroller.placer:GetRotation()
                    )
            then
                    accessible_pos = false
            end

            if accessible_pos and gp_mod_Snap and not (deploy_fn == self.DropActiveItem) then -- 如果获取到几何布局的对齐网格点函数 and 当前不为丢弃物品操作
                if gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and not snap_farm then -- 启用网格对齐&不在耕地状态(耕地的点位对齐不符合要求)
                    accessible_pos = gp_mod_Snap(accessible_pos)
                end
            end

            DebugPrint("当前位置:", accessible_pos or "跳过")
            if accessible_pos then
                if deploy_fn(self, accessible_pos, item) then
                    self:RemovePreview(accessible_pos)
                else
                    break
                end
            end
        end
        self:ClearActionThread()
        self.inst:DoTaskInTime(0, function() if next(self.selected_ents) then self:ApplyToSelection() end end)
    end, action_thread_id)
end

-- 覆盖法×2
function ActionQueuer:SelectionBox(rightclick)
    local previous_ents = {}
    local started_selection = false
    local start_x, start_y = self.screen_x, self.screen_y
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
        self.selection_widget:SetPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        self.selection_widget:SetSize(xmax - xmin + 2, ymax - ymin + 2)
        self.selection_widget:Show()
        self.TL, self.BL, self.TR, self.BR = GetWorldPosition(xmin, ymax), GetWorldPosition(xmin, ymin), GetWorldPosition(xmax, ymax), GetWorldPosition(xmax, ymin)
        --self.TL, self.BL, self.TR, self.BR = GetWorldPosition(xmin, ymin), GetWorldPosition(xmin, ymax), GetWorldPosition(xmax, ymin), GetWorldPosition(xmax, ymax)
        self:SetPreview(rightclick) -- 我只是想加上这个
        local center = GetWorldPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        local range = math.sqrt(math.max(center:DistSq(self.TL), center:DistSq(self.BL), center:DistSq(self.TR), center:DistSq(self.BR)))
        local IsBounded = GeoUtil.NewQuadrilateralTester(self.TL, self.TR, self.BR, self.BL)
        local current_ents = {}
        for _, ent in pairs(TheSim:FindEntities(center.x, 0, center.z, range, nil, unselectable_tags)) do
            if IsValidEntity(ent) then
                local pos = ent:GetPosition()
                if IsBounded(pos) then
                    if not self:IsSelectedEntity(ent) and not previous_ents[ent] then
                        local act, rightclick_ = self:GetAction(ent, rightclick, pos)
                        if act then self:SelectEntity(ent, rightclick_) end
                    end
                    current_ents[ent] = true
                end
            end
        end
        for ent in pairs(previous_ents) do
            if not current_ents[ent] then
                self:DeselectEntity(ent)
            end
        end
        previous_ents = current_ents
    end
    self.selection_thread = StartThread(function()
        while self.inst:IsValid() do
            if self.queued_movement then
                self.update_selection()
                self.queued_movement = false
            end
            Sleep(FRAMES)
        end
        self:ClearSelectionThread()
    end, selection_thread_id)
end

-- 魔改部分
ActionQueuer.preview_curs = {} -- 当前:存实体
ActionQueuer.preview_eds = {} -- 已种：存true
ActionQueuer.userid = ActionQueuer.inst.userid -- 自己的id
ActionQueuer.preview_highlight = AQ_highlight
ActionQueuer.preview_max = AQ_preview_max
ActionQueuer.preview_color = AQ_preview_color -- 颜色
ActionQueuer.preview_dont = AQ_preview_dont -- 不要变色


-- 工具
-- 返回最近的倍数
local function FindNearMulti(number, multiple)
    return multiple == 0 and number or math.floor(number / multiple + 0.5) * multiple
end

local function MergeList(...)
    local mTable = {}
    for _, v in ipairs({ ... }) do
        if type(v) == "table" then
            for _, k in pairs(v) do
                table.insert(mTable, k)
            end
        end
    end
    return mTable
end

-- 获取鼠标上的物品
function GetActiveItem(prefab)
    local item = ThePlayer.replica.inventory:GetActiveItem()
    if not prefab or not item then
        return item
    end
    local prefabs = type(prefab) == "table" and prefab or { prefab }
    return table.contains(prefabs, item.prefab) and item
end

-- 获取所有物品(物品名，标签，满足函数，获取物品的顺序) [当且仅当order=="mouse"时，才会包括鼠标上的物品]
local function GetItemsFromAll(prefab, needtags, func, order)
    local order_all = { "container", "backpack", "equip", "body", "mouse" }
    local result = {}
    local invent = ThePlayer.replica.inventory
    local items = {
        body = invent:GetItems(),
        equip = invent:GetEquips(),
        mouse = { GetActiveItem() },
        backpack = {},
        container = {}
    }

    for container_inst, _ in pairs(invent:GetOpenContainers() or {}) do
        local container = (container_inst and container_inst.replica and container_inst.replica.container) or
        (container_inst and container_inst.replica and container_inst.replica.inventory)
        if container then
            if container_inst:HasTag("INLIMBO") then
                items.backpack = MergeList(items.backpack, container:GetItems())
            else
                items.container = MergeList(items.container, container:GetItems())
            end
        end
    end

    local t = type(order)
    if order == "mouse" then
        order = order_all
    elseif t == "string" and order_all[order] then
        order = { order }
    elseif t == "table" then
        -- do nothing
    else
        order = { "container", "backpack", "equip", "body" }
    end

    local all_items = {}
    for _, o in ipairs(order) do
        if items[o] then
            all_items = MergeList(all_items, items[o])
        end
    end

    needtags = type(needtags) == "string" and { needtags } or (type(needtags) == "table" and needtags)
    for _, item in pairs(all_items) do
        if (not prefab or prefab == item.prefab or (type(prefab) == "table" and table.contains(prefab, item.prefab))) and
            (not needtags or item:HasTags(needtags)) and (not func or func(item)) then
            table.insert(result, item)
        end
    end
    return result
end

-- 获取耐久度
local function GetPercent(inst)
    local i = 100
    local classified = type(inst) == "table" and inst.replica and inst.replica.inventoryitem and
        inst.replica.inventoryitem.classified
    if classified then
        if inst:HasOneOfTags({ "fresh", "show_spoilage" }) and classified.perish then
            i = math.floor(classified.perish:value() / 0.62)
        elseif classified.percentused then
            i = classified.percentused:value()
        end
    end
    return i
end

local function GetAPrefabCount(prefab)
    local count = 0
    for _, ent in ipairs(GetItemsFromAll(prefab, nil, nil, { "container", "backpack", "body", "mouse" }) or {}) do
        count = (ent and ent.replica and (ent.replica.inst and
                (
                   ent.replica.inst.prefab == "fertilizer" and -- 便便桶
                    math.ceil(GetPercent(ent.replica.inst) / 10) -- 可使用10次，所以除以10（所以不兼容修改了物品使用次数的MOD）
                or ent.replica.inst.prefab == "soil_amender_fermented" and -- 超级催长剂
                    math.ceil(GetPercent(ent.replica.inst) / 20) -- 可使用5次，所以除以20（所以不兼容修改了物品使用次数的MOD）
                ))
            or
            ent.replica.stackable and ent.replica.stackable:StackSize() or 1) + count -- 否则按堆叠数算
    end

    return count
end

function ActionQueuer:GetStartValue(spacing, snap_farm, tile_or_wall)
    if not self.TL then
        return
    end

    if snap_farm then
        if farm_grid == "4x4" then
            spacing = 1.26 -- 210116 null: different spacing for 4x4 grid
        elseif farm_grid == "2x2" then
            spacing = 2    -- 210609 null: different spacing for 2x2 grid
        end
    end

    local heading, dir = GetHeadingDir()
    local diagonal = heading % 2 ~= 0
    DebugPrint("Heading:", heading, "Diagonal:", diagonal, "Spacing:", spacing)
    DebugPrint("TL:", self.TL, "TR:", self.TR, "BL:", self.BL, "BR:", self.BR)
    local X, Z = "x", "z"
    if dir then
        X, Z = Z, X
    end
    local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
    local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
    local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
    local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
    local width = math.floor(self.TL:Dist(self.TR) / adjusted_spacing_x)
    local height = self.endless_deploy and 100 or
        math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))
    DebugPrint("Width:", width + 1, "Height:", height + 1) -- since counting from 0

    local talker_string = (width + 1).."×"..(height + 1)
    if last_Width_Height_String ~= talker_string then -- 如果长宽有变化
        ThePlayer.components.talker:Say(talker_string) -- 玩家读出预计放置长宽
        last_Width_Height_String = talker_string
    end
    local start_x, _, start_z = self.TL:Get()
    local terraforming = false

    if tile_or_wall == "tile" then
        start_x, _, start_z = TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)
        terraforming = true
    elseif tile_or_wall == "wall" then
        start_x, start_z = math.floor(start_x) + 0.5, math.floor(start_z) + 0.5
    elseif snap_farm then
        local tilecenter = Point(TheWorld.Map:GetTileCenterPoint(start_x, 0, start_z)) -- center of tile
        local tilepos = Point(tilecenter.x - 2, 0, tilecenter.z - 2)                   -- corner of tile
        if tilecenter.x % 4 == 0 then                                                  -- if center of tile is divisible by 4, then it's a medium/huge server
            farm3x3_offset = farm_spacing                                              -- adjust offset for medium/huge servers for 3x3 grid
        end

        if farm_grid == "4x4" then -- 4x4 grid
            -- 4x4 grid: spacing = 1.26, offset/margins = 0.11
            start_x, start_z = tilepos.x + math.floor((start_x - tilepos.x) / 1.26 + 0.5) * 1.26 + 0.11 *
                offsets_4x4[heading].x, tilepos.z + math.floor((start_z - tilepos.z) / 1.26 + 0.5) *
                1.26 + 0.11 * offsets_4x4[heading].z
        elseif farm_grid == "2x2" then -- 210609 null: 2x2 grid: spacing = 2 (4/2), offset = 1 (4/2/2)
            start_x, start_z = math.floor(start_x / 2) * 2 + 1, math.floor(start_z / 2) * 2 + 1
        else
            start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
                math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
        end
    elseif type(self.deploy_on_grid) == "number" then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
        start_x, start_z = FindNearMulti(start_x, self.deploy_on_grid),
            FindNearMulti(start_z, self.deploy_on_grid)
    end

    local cur_pos = Point()
    local count = {
        x = 0,
        y = 0,
        z = 0
    }
    local row_swap = 1

    -- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
    local step = 1
    local countz2 = 0
    local countStep = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { 1, 0 } }
    if height < 1 then
        countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } }
    end -- 210130 null: bliz fix (210127)

    return start_x, start_z, terraforming, width, height, spacing_x, spacing_z, X, Z, diagonal, cur_pos, count,
        row_swap, step, countz2, countStep
end

function ActionQueuer:GetPosList(spacing, snap_farm, tow, istill, maxsize, meta, compat_gp_mod)
    local ent = meta.ent
    local func = meta.func_pos
    local ret = {}
    local i = 0
    maxsize = type(maxsize) == "number" and maxsize or self.preview_max
    maxsize = maxsize > self.preview_max and self.preview_max or maxsize
    local start_x, start_z, terraforming, width, height, spacing_x, spacing_z, X, Z, diagonal, cur_pos, count, row_swap,
    step, countz2, countStep = self:GetStartValue(spacing, snap_farm, tow)
    if not start_x then
        return ret
    end
    while self.inst:IsValid() do
        cur_pos.x = start_x + spacing_x * count.x
        cur_pos.z = start_z + spacing_z * count.z
        if diagonal then
            if width < 1 then
                if count[Z] > height then
                    break
                end
                count[X] = count[X] - 1
                count[Z] = count[Z] + 1
            else
                local row = math.floor(count.y / 2)
                if count[X] + row > width or count[X] + row < 0 then
                    count.y = count.y + 1
                    if count.y > height then
                        break
                    end
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
            if double_snake then
                if count[X] > width or count[X] < 0 then
                    countz2 = countz2 + 2
                    if countz2 + 1 > height then
                        if countz2 <= height then
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
            else
                if count[X] > width or count[X] < 0 then
                    count[Z] = count[Z] + 1
                    if count[Z] > height then
                        break
                    end
                    row_swap = -row_swap
                    count[X] = count[X] + row_swap
                    cur_pos.x = start_x + spacing_x * count.x
                    cur_pos.z = start_z + spacing_z * count.z
                end
                count[X] = count[X] + row_swap
            end
        end

        if not func or func(cur_pos) then
            local accessible_pos = cur_pos
            if terraforming then -- terraforming 指的是当前行为位置是否为地皮中心点（比如挖地皮、放地皮、给农田浇水、给农田施肥，都是往地皮中心点操作的）
                if ent and (ent:HasTag("fertilizer") or ent.prefab == "wateringcan" or ent.prefab == "premiumwateringcan") then -- 如果在施肥、浇水
                    if not TheWorld.Map:IsFarmableSoilAtPoint(cur_pos.x, 0, cur_pos.z) then -- 如果操作的位置不是农田区
                        accessible_pos = false -- 取消预览
                    end
                elseif ent and (ent.prefab == "pitchfork" or ent.prefab == "goldenpitchfork") then -- 草叉/金草叉
                    accessible_pos = not TheWorld.Map:CanPlaceTurfAtPoint(cur_pos.x, 0, cur_pos.z) and accessible_pos or false -- 当前位置不能放新地皮则false
                elseif ent and ent:HasTag("groundtile") then -- 地皮
                    accessible_pos = TheWorld.Map:CanPlaceTurfAtPoint(cur_pos.x, 0, cur_pos.z) and accessible_pos or false -- 当前位置可以放地皮则继续
                else
                    accessible_pos = GetAccessibleTilePosition(cur_pos) -- 否则将操作位置设置为中心点
                end
            elseif istill then -- 210117 null: 检查pos是否已耕作
                for _, ent in pairs(TheSim:FindEntities(cur_pos.x, 0, cur_pos.z, 0.05, { "soil" })) do
                    if not ent:HasTag("NOCLICK") then
                        accessible_pos = false
                        break
                    end -- Skip Tilling this position
                end
            elseif ThePlayer.replica.inventory and ThePlayer.replica.inventory:GetActiveItem() and not compat_gp_mod and  -- 鼠标拿着物品&不要是丢弃物品状态
                    not ( -- 不满足可以放置在此点位的要求
                        (ThePlayer.replica.inventory:GetActiveItem()._custom_candeploy_fn and -- 如果有自定义规则，优先按自定义规则判定
                            ThePlayer.replica.inventory:GetActiveItem():_custom_candeploy_fn( -- 自定义规则说能放在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos -- 兼容几何布局校准后的点位
                            )
                        )
                        or -- 这里需要对植物进行额外判断....
                        (TheWorld.Map:CanDeployAtPoint( -- 通用规则说能放置在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                                    ThePlayer.replica.inventory:GetActiveItem()
                                )
                        )
                    )
                    or ThePlayer.components.playercontroller and ThePlayer.components.playercontroller.placer and ThePlayer.components.playercontroller.placer_recipe and not -- 鼠标上打包的建筑是否可以放置
                        TheWorld.Map:CanDeployRecipeAtPoint(
                            accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                            ThePlayer.components.playercontroller.placer_recipe,
                            ThePlayer.components.playercontroller.placer:GetRotation()
                    )
            then
                    accessible_pos = false
            end

            if accessible_pos and gp_mod_Snap and not compat_gp_mod then  -- 如果获取到几何布局的对齐网格点函数 and 当前不为丢弃物品操作
                if gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and not snap_farm then -- 启用网格对齐&不在耕地状态(耕地的点位对齐不符合要求)
                    accessible_pos = gp_mod_Snap(accessible_pos)
                end
            end

            if accessible_pos then
                i = i + 1
                local pos = Point(accessible_pos:Get())
                ret[tostring(pos)] = pos
                if i >= maxsize then
                    break
                end
            end
        end
    end
    return ret
end

function ActionQueuer:SpawnPreview(pos, meta)
    -- 不在不可种 和 已经种的表
    local id = tostring(pos)
    if not self.preview_eds[id] and not self.preview_curs[id] then
        local ent
        local me = meta.ent
        if me then
            print("DEBUGmeta", me.prefab, me.skinname, me.skin_id)
            meta.prefab, meta.skin, meta.skin_id = me.prefab, me.skinname, me.skin_id
        end
        if not ent then
            if table.contains({ "abigail_flower" }, meta.prefab) then
                return
            end
            ent = SpawnPrefab(meta.prefab, meta.skin, meta.skin_id, self.userid)
            ent.persists = false
            ent:AddTag("fx")
            ent:AddTag("NOBLOCK")
            ent:AddTag("NOCLICK")
        end
        if ent and ent.Transform then
            ent.Transform:SetPosition(pos:Get())
            if meta.rotation then
                ent.Transform:SetRotation(meta.rotation)
            end
            local scale = meta.scale
            if type(scale) == "number" then
                ent.Transform:SetScale(scale, scale, scale)
            end
            self.preview_curs[id] = ent
            -- 处理变色逻辑
            local anim = ent.AnimState
            if anim then
                anim:SetLightOverride(self.preview_highlight)
                if not self.preview_dont then
                    local r, g, b, t = unpack(self.preview_color)
                    anim:OverrideMultColour(r, g, b, t)
                    anim:SetAddColour(r, g, b, t)
                end
            end
        end
    end
end

function ActionQueuer:DeployToPreview(meta, spacing, snap, tow, istill, maxsize, compat_gp_mod)
    local ret = self:GetPosList(spacing, snap, tow, istill, maxsize, meta, compat_gp_mod)

    for id, pos in pairs(ret or {}) do
        self:SpawnPreview(pos, meta)
    end

    for id, ent in pairs(self.preview_curs or {}) do
        if not ret[id] then
            ent:Remove()
            self.preview_curs[id] = nil
        end
    end
end

function ActionQueuer:SetPreview(rightclick)
    -- 初始位置, 最终位置, 间隔，上限-》预览
    if next(self.selected_ents) then
        return ActionQueuer:ClearPreview()
    end
    if rightclick then
        local active_item = self:GetActiveItem()
        if active_item then
            if easy_stack[active_item.prefab] then -- 种植小木牌的
                local ent = TheInput:GetWorldEntityUnderMouse()
                if ent and ent:HasTag(easy_stack[active_item.prefab]) then
                    return ActionQueuer:ClearPreview()
                end
            end

            if active_item:HasTag("fertilizer") then -- 手里拿的是肥料
                -- 最好是贴图
                self:DeployToPreview({
                    ent = active_item
                }, 4, false, "tile", false, GetAPrefabCount(active_item.prefab))
                return
            end
            if ThePlayer:HasTag("plantkin") and active_item:HasTag("deployedfarmplant") then -- 沃姆伍德种植
                local placer = self.inst.components.playercontroller.deployplacer
                if not self.TL then
                    return
                end
                local cx, cz = (self.TL.x + self.BR.x) / 2,
                    (self.TR.z + self.BL.z) / 2                                         -- Get SelectionBox() center coords
                if (cx and cz) and TheWorld.Map:IsFarmableSoilAtPoint(cx, 0, cz) then   -- if center = soil tile
                    -- 最好是贴图
                    self:DeployToPreview({
                        prefab = placer.prefab,
                        skin = placer.skinname,
                        skin_id = placer.skin_id,
                        rotation = placer.Transform:GetRotation()
                    }, farm_spacing, true, false, false, GetAPrefabCount(active_item.prefab))
                else -- 最好是贴图
                    self:DeployToPreview({
                        prefab = placer.prefab,
                        skin = placer.skinname,
                        skin_id = placer.skin_id,
                        rotation = placer.Transform:GetRotation()
                    }, farm_spacing, false, false, false, GetAPrefabCount(active_item.prefab))
                end
                return
            end

            if active_item:HasTag("groundtile") then -- 手里拿的是地皮
                self:DeployToPreview({
                    ent = active_item
                }, 4, false, "tile", false, GetAPrefabCount(active_item.prefab))
                return
            end

            if active_item.replica.inventoryitem and active_item.replica.inventoryitem:IsDeployable(self.inst) then -- 如果鼠标上是允许放置的则放置
                local placer = self.inst.components.playercontroller.deployplacer
                if placer then
                    local tile_or_wall
                    if active_item:HasOneOfTags({ "groundtile", "tile_deploy" }) then
                        tile_or_wall = "tile"
                    elseif (active_item:HasTag("wallbuilder") or active_item:HasTag("fencebuilder")) then
                        tile_or_wall = "wall"
                    end
                    self:DeployToPreview({
                        prefab = placer.prefab,
                        skin = placer.skinname,
                        skin_id = placer.skin_id,
                        rotation = placer.Transform:GetRotation()
                    }, GetDeploySpacing(active_item), false, tile_or_wall, false, GetAPrefabCount(active_item.prefab))
                end
            else -- 否则丢弃
                -- 最好是贴图
                self:DeployToPreview({
                    ent = active_item
                }, GetDropSpacing(active_item), false, "wall", false, GetAPrefabCount(active_item.prefab), true)
            end
            return
        end
        local equip_item = self:GetEquippedItemInHand()
        if equip_item and equip_item:HasActionComponent("terraformer") then -- 可以影响地形的...比如草叉
            return self:DeployToPreview({
                ent = equip_item,
                scale = 2
            }, 4, false, "tile", false)
        elseif equip_item and (equip_item.prefab == "wateringcan" or equip_item.prefab == "premiumwateringcan") then -- 装备着浇水壶/鸟嘴壶
            -- 210202 null: first check if selection box is being used
            if not self.TL or (math.abs(self.TL.x - self.BR.x) + math.abs(self.TR.z - self.BL.z) < 1) then -- if single click
            else
                return self:DeployToPreview({
                    ent = equip_item,
                    scale = 2
                }, 4, false, "tile", false)
            end
        elseif equip_item and equip_item:HasActionComponent("farmtiller") then
            if not (st_mode() == 0) then
            else
            return self:DeployToPreview({
                prefab = "farm_soil",
                func_pos = function(pos)
                    return TheWorld.Map:CanTillSoilAtPoint(pos:Get())
                end
            }, farm_spacing, true, false, true)
            end
        end
    elseif self.inst.components.playercontroller.placer then
        local playercontroller = self.inst.components.playercontroller
        local recipe = playercontroller.placer_recipe
        local spacing = recipe.min_spacing > 2 and 4 or 2
        local placer = playercontroller.placer
        return self:DeployToPreview({
            prefab = placer.prefab,
            skin = placer.skinname,
            skin_id = placer.skin_id,
            rotation = placer:GetRotation()
        }, spacing, false, false, false)
    end
end

function ActionQueuer:ClearPreview()
    for _, ent in pairs(self.preview_curs or {}) do
        if type(ent) == "table" and ent.entity and ent:IsValid() and ent.Transform then
            ent:Remove()
        end
    end
    self.preview_curs = {}
    self.preview_eds = {}
end


function ActionQueuer:RemovePreview(pos)
    -- 预览相关
    local id = tostring(pos)
    self.preview_eds[id] = true
    local ent = self.preview_curs[id]
    if type(ent) == "table" and ent.entity and ent:IsValid() and ent.Transform then
        ent:Remove()
    end
    self.preview_curs[id] = nil
end


-- 修改原函数

-- local old_SelectionBox = ActionQueuer.SelectionBox
-- ActionQueuer.SelectionBox = function(rightclick, ...)
--     old_SelectionBox(rightclick, ...)
--     local old_SelectionBox_update_selection = ActionQueuer.update_selection
--     if not old_SelectionBox_update_selection then
--         print("[行为学预览] 警告：ActionQueuer.SelectionBox函数中的self.update_selection函数get失败")
--         return
--     end
--     ActionQueuer.update_selection = function()
--         ActionQueuer:SetPreview(rightclick)
--         old_SelectionBox_update_selection()
--     end
-- end

local old_ActionQueuer_ClearSelectedEntities = ActionQueuer.ClearSelectedEntities
ActionQueuer.ClearSelectedEntities = function(...)
    ActionQueuer:ClearPreview()
    old_ActionQueuer_ClearSelectedEntities(...)
end

local old_ActionQueuer_ClearActionThread = ActionQueuer.ClearActionThread
ActionQueuer.ClearActionThread = function(...)
    ActionQueuer:ClearPreview()
    old_ActionQueuer_ClearActionThread(...)
end

end)