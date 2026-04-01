GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

if not KnownModIndex:IsModEnabledAny("workshop-3136701076") then
    print("[黑化排队论 · 动作预览] 检测到黑化排队论本体未开启，停止加载！")
    return
end

local function Import(modulename, env)
	local f = GLOBAL.kleiloadlua(modulename)
	if f and type(f) == "function" then
        setfenv(f, env or GLOBAL)
        return f()
	end
end

local Upvaluehelper = Import(MODROOT .. "bbgoat_upvaluehelper.lua")
local _ActionQueuer

local MOD_util = Import(MODROOT .. "MOD_util.lua", env)

-- 基本定义（来自黑化排队论模组）
local farm_spacing
local farm3x3_offset
local GetHeadingDir
local double_snake
local GetAccessibleTilePosition
local easy_stack
local mouse_controls
local default_aq_queuekey
local IsHUDEntity -- HUD

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
        gp_mod_Snap = Upvaluehelper.GetUpvalue(inst.MakeRecipeAtPoint,"Snap")
    end)
    gp_mod_CTRL_setting = function()
        return GLOBAL.GetModConfigData("CTRL","workshop-351325790")
    end
else
    print("[行为学预览] 未检测到几何布局模组开启")
end

local ActionQueuerPreview = {}

function ActionQueuerPreview:SelectionBox(rightclick)
    self.update_selection = function()
        self:SetPreview(rightclick)
    end
    -- 框选线程
    self.selection_preview_thread = StartThread(function() -- 该线程按帧刷新
        while self.inst:IsValid() do
            if self.queued_preview_movement then
                self.update_selection()
                self.queued_preview_movement = false
            end

            Sleep(FRAMES)
        end
        self:ClearSelectionPreviewThread() -- 清除旧框选线程
    end, "actionqueue_selection_preview_thread")
end

-- 工具
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

function ActionQueuerPreview:GetEquippedItemInHand()
    return self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
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
        -- 萌萌的新的版本只会怼着一个地方施肥，所以不处理

        -- count = (ent and ent.replica and (ent.replica.inst and
        --         (
        --            ent.replica.inst.prefab == "fertilizer" and -- 便便桶
        --             math.ceil(GetPercent(ent.replica.inst) / 10) -- 可使用10次，所以除以10（所以不兼容修改了物品使用次数的MOD）
        --         or ent.replica.inst.prefab == "soil_amender_fermented" and -- 超级催长剂
        --             math.ceil(GetPercent(ent.replica.inst) / 20) -- 可使用5次，所以除以20（所以不兼容修改了物品使用次数的MOD）
        --         ))
        --     or ent.replica.stackable and ent.replica.stackable:StackSize() or 1) + count
        count = (ent.replica.stackable and ent.replica.stackable:StackSize() or 1) + count -- 否则按堆叠数算
    end

    return count
end

function ActionQueuerPreview:GetActiveItem()
    return self.inst.replica.inventory:GetActiveItem()
end

function ActionQueuerPreview:GetStartValue(spacing, snap_farm, tile_or_wall)
    if not self.TL then
        return
    end

    local heading, dir = GetHeadingDir()
    local diagonal = heading % 2 ~= 0
    local X, Z = "x", "z"
    if dir then
        X, Z = Z, X
    end
    local spacing_x = self.TL[X] > self.TR[X] and -spacing or spacing
    local spacing_z = self.TL[Z] > self.BL[Z] and -spacing or spacing
    local adjusted_spacing_x = diagonal and spacing * 1.4 or spacing
    local adjusted_spacing_z = diagonal and spacing * 0.7 or spacing
    local width = math.floor(self.TL:Dist(self.TR) / adjusted_spacing_x)
    local height = math.floor(self.TL:Dist(self.BL) / (width < 1 and adjusted_spacing_x or adjusted_spacing_z))
    if height >= 1 then
        height = self.endless_deploy and 100 or height -- 萌萌的新写的..
    end

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
        start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
            math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
    elseif type(self.deploy_on_grid) == "number" then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
        start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5
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

function ActionQueuerPreview:GetPosList(spacing, snap_farm, tow, istill, maxsize, meta, compat_gp_mod)
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
                    end -- 跳过此耕地位置
                end
            elseif ThePlayer.replica.inventory and
                    ThePlayer.replica.inventory:GetActiveItem() and
                    ThePlayer.replica.inventory:GetActiveItem().replica and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem.CanDeploy and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem:IsDeployable(self.inst) and  -- 鼠标拿着物品&是可以部署的
                    not ( -- 不满足可以放置在此点位的要求
                        (ThePlayer.replica.inventory:GetActiveItem()._custom_candeploy_fn and -- 如果有自定义规则，优先按自定义规则判定
                            ThePlayer.replica.inventory:GetActiveItem():_custom_candeploy_fn( -- 自定义规则说能放在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos -- 兼容几何布局校准后的点位
                            )
                        )
                        or
                        (ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem:CanDeploy(
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                                nil, nil,
                                meta.rotation or nil
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

function ActionQueuerPreview:SpawnPreview(pos, meta)
    if not self.preview_able then
        return
    end
    -- 不在不可种 和 已经种的表
    local id = tostring(pos)
    if not self.preview_eds[id] and not self.preview_curs[id] then
        local ent
        local me = meta.ent
        if me then
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
                if not self.preview_dont_color then
                    local r, g, b, t = unpack(self.preview_color)
                    anim:OverrideMultColour(r, g, b, t)
                    anim:SetAddColour(r, g, b, t)
                end
            end
        end
    end
end

function ActionQueuerPreview:DeployToPreview(meta, spacing, snap, tow, istill, maxsize, compat_gp_mod)
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

function ActionQueuerPreview:SetPreview(rightclick)
    -- 初始位置, 最终位置, 间隔，上限-》预览

    -- 萌萌的新的版本不能判断selected_ents，先删了
    -- if next(_ActionQueuer.selected_ents) then
    --     return ActionQueuer:ClearPreview()
    -- end
    if rightclick then
        local active_item = self:GetActiveItem()

        local Blacklist = {
            butterfly = true, -- 蝴蝶：无法预测-预测不准确 因为花朵有大有小
            minisign_item = true,  -- 小木牌：上级行为学Mod会乱放
            fertilizer = true, -- 便便桶 -- 萌萌的新的版本只会怼着一个地方施肥
            soil_amender_fermented = true, -- 超级催长剂 -- 萌萌的新的版本只会怼着一个地方施肥
            farm_plow_item = true, -- 耕地机 -- 萌萌的新的版本不能排队放置 -- ToDo: 我的预判也不大准确 横着放会少预判一个？ 20250702
        }

        if active_item then
            if Blacklist[active_item.prefab] then -- 黑名单物品
                return ActionQueuerPreview:ClearPreview()
            end

            if easy_stack[active_item.prefab] then -- 种植小木牌的
                local ent = TheInput:GetWorldEntityUnderMouse()
                if ent and ent:HasTag(easy_stack[active_item.prefab]) then
                    return ActionQueuerPreview:ClearPreview()
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
                    }, self:GetDeploySpacing(active_item), false, tile_or_wall, false, GetAPrefabCount(active_item.prefab))
                end
            else -- 否则丢弃
                -- 最好是贴图
                self:DeployToPreview({
                    ent = active_item
                }, 1 --[[GetDropSpacing(active_item)]], false, "wall", false, GetAPrefabCount(active_item.prefab), true)
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
        -- local Blacklist = {
        -- }
        -- if self.inst.components.playercontroller.placer.prefab and Blacklist[self.inst.components.playercontroller.placer.prefab] then return end

        local playercontroller = self.inst.components.playercontroller
        local recipe = playercontroller.placer_recipe
        local spacing = recipe.min_spacing or 3.2
        local placer = playercontroller.placer
        return self:DeployToPreview({
            prefab = placer.prefab,
            skin = placer.skinname,
            skin_id = placer.skin_id,
            rotation = placer:GetRotation()
        }, spacing, false, false, false)
    end
end

function ActionQueuerPreview:ClearPreview()
    for _, ent in pairs(self.preview_curs or {}) do
        if type(ent) == "table" and ent.entity and ent:IsValid() and ent.Transform then
            ent:Remove()
        end
    end
    self.preview_curs = {}
    self.preview_eds = {}
end


function ActionQueuerPreview:RemovePreview(pos)
    -- 预览相关
    local id = tostring(pos)
    self.preview_eds[id] = true
    local ent = self.preview_curs[id]
    if type(ent) == "table" and ent.entity and ent:IsValid() and ent.Transform then
        ent:Remove()
    end
    self.preview_curs[id] = nil
end

----------------------------------------------------------------------------------------------------------

-- 清除框选(预览)线程
function ActionQueuerPreview:ClearSelectionPreviewThread()
    if self.selection_preview_thread then
        if self.selection_thread then
            KillThreadsWithID(self.selection_thread.id)
        end
        self.selection_preview_thread:SetList(nil)
        self.selection_preview_thread = nil
    end
end

function ActionQueuerPreview:OnDown(rightclick) -- 按下
    self:ClearSelectionPreviewThread() -- 清除旧框选线程
    if self.inst:IsValid() and not IsHUDEntity() then
        self:SelectionBox(rightclick)
    end
end

-- 初始化
AddComponentPostInit("playercontroller", function(self, inst)
    if inst ~= ThePlayer then return end

    ActionQueuerPreview.inst = inst
    -- 本模组设置/魔改部分
    ActionQueuerPreview.preview_able = MOD_util:GetMOption("preview_able", true) -- 预览功能总开关
    ActionQueuerPreview.preview_curs = {} -- 当前:存实体
    ActionQueuerPreview.preview_eds = {} -- 已种：存true
    ActionQueuerPreview.preview_highlight = MOD_util:GetMOption("preview_highlight", 0.3)
    ActionQueuerPreview.preview_max = MOD_util:GetMOption("preview_max", 80) -- 预览最大数量
    ActionQueuerPreview.preview_color = PLAYERCOLOURS[MOD_util:GetMOption("preview_color", "GREEN")] -- 颜色
    ActionQueuerPreview.preview_dont_color = MOD_util:GetMOption("preview_dont_color", false) -- 不要变色


    TheInput:AddMoveHandler(function(x, y)
        ActionQueuerPreview.queued_preview_movement = true
    end)

    _ActionQueuer = Upvaluehelper.GetUpvalue(self.OnControl,"ActionQueuer")
    farm_spacing = Upvaluehelper.GetUpvalue(_ActionQueuer.OnUp,"farm_spacing")
    farm3x3_offset = Upvaluehelper.GetUpvalue(_ActionQueuer.DeployToSelection,"farm3x3_offset")
    GetHeadingDir = Upvaluehelper.GetUpvalue(_ActionQueuer.DeployToSelection,"GetHeadingDir")
    double_snake = Upvaluehelper.GetUpvalue(_ActionQueuer.DeployToSelection,"double_snake")
    GetAccessibleTilePosition = Upvaluehelper.GetUpvalue(_ActionQueuer.DeployToSelection,"GetAccessibleTilePosition")
    easy_stack = Upvaluehelper.GetUpvalue(_ActionQueuer.OnUp,"easy_stack")
    mouse_controls = Upvaluehelper.FindUpvalue(self.OnControl, "mouse_controls", "workshop%-3136701076/modmain.lua")
    default_aq_queuekey = Upvaluehelper.GetUpvalue(self.OnControl,"default_aq_queuekey")
    IsHUDEntity = Upvaluehelper.GetUpvalue(_ActionQueuer.OnDown,"IsHUDEntity") -- HUD

    ActionQueuerPreview.userid = _ActionQueuer.inst.userid -- 自己的id

    GLOBAL.setmetatable(ActionQueuerPreview, {
        __index = function(t, k)
            return GLOBAL.rawget(_ActionQueuer, k)
        end
    })

    local PlayerControllerOnControl = self.OnControl
    self.OnControl = function(self, control, down)
        -- 左键false，右键true
        local mouse_control = mouse_controls[control]
        if mouse_control ~= nil then
            if down then
                if TheInput:IsKeyDown(MOD_util:GetMOption("aq_queuekey", default_aq_queuekey))
                    and not TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then
                    ActionQueuerPreview:OnDown(mouse_control)
                end
            else
                ActionQueuerPreview:ClearSelectionPreviewThread() -- 清除框选线程
            end
        end

        return PlayerControllerOnControl(self, control, down) -- 该干啥干啥
    end

    local old_ActionQueuer_ClearSelectedEntities = _ActionQueuer.ClearSelectedEntities
    _ActionQueuer.ClearSelectedEntities = function(...)
        ActionQueuerPreview:ClearPreview()
        old_ActionQueuer_ClearSelectedEntities(...)
    end

    local old_ActionQueuer_ClearActionThread = _ActionQueuer.ClearActionThread
    _ActionQueuer.ClearActionThread = function(...)
        ActionQueuerPreview:ClearPreview()
        old_ActionQueuer_ClearActionThread(...)
    end

    -- 还得是覆盖法...
    function _ActionQueuer:DeployToSelection(deploy_fn, spacing, item, preview_mode)
        if not self.TL then return end
        self:MovementPredict()
        -- 210116 null: cases for snapping positions to farm grid (Tilling, Wormwood planting on soil tiles, etc)
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
            if tilecenter.x % 4 == 0 then                                                        -- if center of tile is divisible by 4, then it's a medium/huge server
                farm3x3_offset =
                    farm_spacing                                                                 -- adjust offset for medium/huge servers for 3x3 grid
            end
            start_x, start_z = math.floor(start_x / farm_spacing) * farm_spacing + farm3x3_offset,
                math.floor(start_z / farm_spacing) * farm_spacing + farm3x3_offset
        elseif self.deploy_on_grid then -- 210201 null: deploy_on_grid = last to avoid conflict with farm grids (blizstorm)
            start_x, start_z = math.floor(start_x * 2 + 0.5) * 0.5, math.floor(start_z * 2 + 0.5) * 0.5
        end

        local cur_pos = Point()
        local count = { x = 0, y = 0, z = 0 }
        local row_swap = 1

        -- 210127 null: added support for snaking within snaking for faster deployment (thanks to blizstorm)
        local step = 1
        local countz2 = 0
        local countStep = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { 1, 0 } }
        if height < 1 then countStep = { { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } } end -- 210130 null: bliz fix (210127)

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
                elseif ThePlayer.replica.inventory and -- 额外部分
                    ThePlayer.replica.inventory:GetActiveItem() and
                    ThePlayer.replica.inventory:GetActiveItem().replica and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem.CanDeploy and
                    ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem:IsDeployable(self.inst) and  -- 鼠标拿着物品&是可以部署的
                    not ( -- 不满足可以放置在此点位的要求
                        (ThePlayer.replica.inventory:GetActiveItem()._custom_candeploy_fn and -- 如果有自定义规则，优先按自定义规则判定
                            ThePlayer.replica.inventory:GetActiveItem():_custom_candeploy_fn( -- 自定义规则说能放在此点位
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos -- 兼容几何布局校准后的点位
                            )
                        )
                        or
                        (ThePlayer.replica.inventory:GetActiveItem().replica.inventoryitem:CanDeploy(
                                accessible_pos and gp_mod_Snap and gp_mod_CTRL_setting() == TheInput:IsKeyDown(KEY_CTRL) and gp_mod_Snap(cur_pos) or cur_pos, -- 兼容几何布局校准后的点位
                                nil, nil,
                                ThePlayer.components.playercontroller and ThePlayer.components.playercontroller.placer and ThePlayer.components.playercontroller.placer:GetRotation() or nil)
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

                if accessible_pos then
                    if deploy_fn(self, accessible_pos, item) then
                        ActionQueuerPreview:RemovePreview(accessible_pos)
                    else
                        break
                    end
                end
            end
            self:ClearActionThread(next(self.selected_ents))
            self.inst:DoTaskInTime(0, function() if next(self.selected_ents) then self:ApplyToSelection() end end)
        end, "actionqueue_action_thread")
    end

end)

--------------------模组设置界面-------------------
if not MOD_util:CanAddSetting() then
    return
end
local pagename = "排队论预览"
local pageorder = 1
local buttonname = pagename
local pagetitle = "黑化排队论 · 动作预览设置"
local enabledisableoption = { { text = "禁用", data = false }, { text = "启用", data = true } }
MOD_util:CreatePage(pagename, {
    title = pagetitle,
    buttondata = { name = buttonname },
    order = pageorder,
    all_options = {
        {
            description = "预览功能", -- 名称
            key = "preview_able", -- 对应设置项
            default = true, -- 默认选项
            options = enabledisableoption, -- 选项列表
            onapplyfn = function()
                ActionQueuerPreview.preview_able = MOD_util:GetMOption("preview_able", true)
            end
        },
        {
            description = "预览数量", -- 名称
            key = "preview_max", -- 对应设置项
            default = 80, -- 默认选项
            options = {
                {text = "20", data = 20},
                {text = "25", data = 25},
                {text = "30", data = 30},
                {text = "35", data = 35},
                {text = "40", data = 40},
                {text = "50", data = 50},
                {text = "60", data = 60},
                {text = "70", data = 70},
                {text = "80", data = 80},
                {text = "90", data = 90},
                {text = "100", data = 100},
                {text = "120", data = 120},
                {text = "160", data = 160},
                {text = "200", data = 200},
                {text = "250", data = 250},
                {text = "300", data = 300},
                {text = "400", data = 400},
                {text = "500", data = 500},
                {text = "1000", data = 1000},
            },
            onapplyfn = function()
                ActionQueuerPreview.preview_max = MOD_util:GetMOption("preview_max", true)
            end
        },
        {
            description = "预览亮度", -- 名称
            key = "preview_highlight", -- 对应设置项
            default = 0.3, -- 默认选项
            options = {
                {text = "10%", data = 0.1},
                {text = "20%", data = 0.2},
                {text = "30%", data = 0.3},
                {text = "40%", data = 0.4},
                {text = "50%", data = 0.5},
                {text = "60%", data = 0.6},
                {text = "70%", data = 0.7},
                {text = "80%", data = 0.8},
                {text = "90%", data = 0.9},
                {text = "100%", data = 1},
            },
            onapplyfn = function()
                ActionQueuerPreview.preview_highlight = MOD_util:GetMOption("preview_highlight", true)
            end
        },
        {
            description = "预览颜色", -- 名称
            key = "preview_color", -- 对应设置项
            default = "GREEN", -- 默认选项
            options = {
                {text = "白色", data = "WHITE"},
                {text = "红色", data = "FIREBRICK"},
                {text = "橙色", data = "TAN"},
                {text = "黄色", data = "LIGHTGOLD"},
                {text = "绿色", data = "GREEN"},
                {text = "青色", data = "TEAL"},
                {text = "蓝色", data = "OTHERBLUE"},
                {text = "紫色", data = "DARKPLUM"},
                {text = "粉色", data = "ROSYBROWN"},
                {text = "金色", data = "GOLDENROD"},
            },
            onapplyfn = function()
                ActionQueuerPreview.preview_color = PLAYERCOLOURS[MOD_util:GetMOption("preview_color", true)]
            end
        },
        {
            description = "禁用颜色", -- 名称
            key = "preview_dont_color", -- 对应设置项
            default = false, -- 默认选项
            options = {
                {text = "是", data = true},
                {text = "否", data = false},
            },
            onapplyfn = function()
                ActionQueuerPreview.preview_dont_color = MOD_util:GetMOption("preview_dont_color", true)
            end
        },
    }
}
)