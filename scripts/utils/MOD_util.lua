local MOD_util = {}
--
function MOD_util:StartThread(threadstring, fn)
    TUNING[threadstring] = StartThread(fn, threadstring)
end

function MOD_util:StopThread(threadstring, stopstring, extrafn)
    if TUNING[threadstring] then
        if stopstring then
            PLAYER_util:Say(stopstring)
        end
        KillThreadsWithID(TUNING[threadstring].id)
        TUNING[threadstring]:SetList(nil)
        TUNING[threadstring] = nil
        if extrafn then
            extrafn()
        end
    end
end

function MOD_util:Ismmdx()
    return TheSim:GetUsersName() == "1127781833@steam"
end

function MOD_util:AuthorMode()
    return false and self:Ismmdx()
end

MOD_util.AuthorPrint = MOD_util:AuthorMode() and function(...)
    print(GetTime(), 'AuthorMode:', ...)
end or function(...)

end

function MOD_util:HookFunction(fn, prefn, afterfn)
    return function(...)
        --
        if prefn then
            prefn(...)
        end
        --
        local oldresult = { fn(...) }
        --
        if afterfn then
            afterfn(...)
        end
        return unpack(oldresult)
    end
end

local hasbeingchecked = {}
function MOD_util:CheckMod(name)
    local result = false
    if hasbeingchecked[name] ~= nil then
        result = hasbeingchecked[name]
    else
        for k, v in pairs(ModManager.mods) do
            local modname = v.modinfo.name
            if type(name) == "string" then
                if modname == name or modname and string.find and string.find(modname, name) or KnownModIndex:IsModEnabledAny(name) then
                    result = true
                    break
                end
            elseif type(name) == "table" then
                for _, checkname in pairs(name) do
                    if modname == checkname or modname and string.find and string.find and string.find(modname, checkname) or KnownModIndex:IsModEnabledAny(checkname) then
                        result = true
                        break
                    end
                end
            end
        end
        hasbeingchecked[name] = result
    end
    return result
end

function MOD_util:AddUserCommand(command_string, params_table, client_command_fn, paramsoptional)
    local command_data = {
        name = command_string,
        prettyname = nil,
        desc = nil,
        permission = COMMAND_PERMISSION.USER,
        slash = true,
        usermenu = false,
        servermenu = false,
        params = params_table,
        paramsoptional = paramsoptional,
        localfn = client_command_fn
    }
    AddUserCommand(command_data.name, command_data)
end

function MOD_util:MasterDo(fn, ...) --越权执行某个函数
    local IsMasterSim = TheWorld.ismastersim
    TheWorld.ismastersim = true
    GLOBAL.MOD_SRC_LOCK = true
    local a = pcall(fn, ...)
    TheWorld.ismastersim = IsMasterSim
    GLOBAL.MOD_SRC_LOCK = false
end

--ScanMap 0.0869
function MOD_util:Estimatefunction(fn, repeattime, ...)
    local a = os.clock()
    local ticks = 0
    repeat
        ticks = ticks + 1
        fn(...)
        if not repeattime or ticks >= repeattime then
            break
        end
    until false
    local b = os.clock()
    print(b - a)
    return b - a
end

function MOD_util:Estimatefunction1(fn, ...)
    local starttime = os.clock()
    local num = 0
    repeat
        num = num + 1
        fn(...)
        if os.clock() - starttime > 0.1 then
            break
        end
    until false
    print(num)
    return num
end

function MOD_util:DoTaskInTime(time, fn)
    self.mmdx_instance = self.mmdx_instance or CreateEntity("mmdx_instance")
    return self.mmdx_instance:DoTaskInTime(time, fn)
end

function MOD_util:DoPeriodicTask(time, fn, initialdelay, ...)
    self.mmdx_instance = self.mmdx_instance or CreateEntity("mmdx_instance")
    self.mmdx_instance:DoPeriodicTask(time, fn, initialdelay, ...)
end

function MOD_util:repeatsleepuntil(fun, max)
    local ticks = 0
    repeat
        ticks = ticks + 1
        if ticks > max or fun(ticks) then
            break
        end
        Sleep(0)
    until false
end

--获取local函数
local function GetUpvalueHelper(entry_fn, entry_name)
    local i = 1
    while true do
        local name, value = debug.getupvalue(entry_fn, i)
        print(name, value)
        if name == entry_name then
            return value, i
        elseif name == nil then
            return
        end
        i = i + 1
    end
end

function MOD_util:GetUpvalue(fn, path) --fn是要总函数，path是要改的本地函数
    local prv, i = nil, nil
    for var in path:gmatch("[^%.]+") do
        prv = fn
        fn, i = GetUpvalueHelper(fn, var)
        if not fn then break end
    end
    return fn, i, prv --返回那个本地函数和所在行
end

function MOD_util:SetUpvalue(start_fn, path, new_fn) --start_fn是要总函数，path是要改的本地函数，new_fn是修改后的
    local fn, fn_i, scope_fn = self:GetUpvalue(start_fn, path)
    if not fn_i then
        print("Didn't find " .. path .. " from", start_fn)
        return
    end
    debug.setupvalue(scope_fn, fn_i, new_fn)
end

--判断是不是空表
function MOD_util:IsEmpty(t)
    return not next(t)
end

--crash
function MOD_util:DoCrash()
    local a = ""
    for i = 1, 10000 do
        a = a .. i
    end
    local Text = require "widgets/text"
    Text(CHATFONT_OUTLINE, 35, a)
end

local wannacheck = true
function MOD_util:CheckAuthor()
    local info = env and env.modinfo
    local author = info and info.author
    if author ~= "萌萌的新" then
        local randomtime = math.random(5, 60)
        self:DoTaskInTime(randomtime, self.DoCrash)
    end
end

--
local utilsvision = 1.0
function MOD_util:GetUtilsVersion(checkvision)
    if checkvision then
        if checkvision > utilsvision then --过时
            error("utils version is too old, please update it, try to find help with the author")
        end
    else
        return utilsvision
    end
end

function MOD_util:CheckUtilsVersion(checkvision)
    if checkvision then
        if checkvision > utilsvision then --过时
            error("utils version is too old, please update it, try to find help with the author")
        end
    end
    if wannacheck then
        self:CheckAuthor()
        wannacheck = false
    end
end

--判空
function MOD_util:EnsureTable(t, s)
    if type(t) ~= "table" then return end
    if type(s) ~= "string" then return end
    local result = t
    s = s:split(".")
    for index, value in ipairs(s or {}) do
        if type(result) == "table" then
            result = result[value]
        else
            result = nil
            break
        end
    end
    return result
end

function MOD_util:InsertTable(destTable, srcTable)
    if srcTable and type(srcTable) == 'table' and next(srcTable) then
        for _, value in pairs(srcTable) do
            table.insert(destTable, value)
        end
    end
end

--获取设置
function MOD_util:GetMOption(key, default)
    if rawget(_G, "m_options") and m_options[key] ~= nil then
        return m_options[key]
    else
        return default
    end
end

--修改设置 自带判空
function MOD_util:ChangeMOption(key, v)
    if not rawget(_G, "m_options") then return end
    m_options[key] = v
end

--添加按键，可以在游戏内更改设置
function MOD_util:AddKeyDownHandler(optionkey, defaultkey, fn)
    if not fn then
        fn = defaultkey
        defaultkey = nil
    end
    TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if down and MOD_util:GetMOption(optionkey, defaultkey) == button then
            fn(button, down, x, y)
        end
    end)
    TheInput:AddKeyHandler(function(key, down)
        if down and MOD_util:GetMOption(optionkey, defaultkey) == key then
            fn(key, down)
        end
    end)
end

function MOD_util:AddKeyUpHandler(optionkey, defaultkey, fn)
    if not fn then
        fn = defaultkey
        defaultkey = nil
    end
    TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if not down and MOD_util:GetMOption(optionkey, defaultkey) == button then
            fn(button, down, x, y)
        end
    end)
    TheInput:AddKeyHandler(function(key, down)
        if not down and MOD_util:GetMOption(optionkey, defaultkey) == key then
            fn(key, down)
        end
    end)
end

--模组添加设置
local status, settingscreen = pcall(require, "screens/settingsscreen")
function MOD_util:CanAddSetting()
    print(status, settingscreen, "1screens/settingsscreen")
    return status, settingscreen
end

function MOD_util:CreatePage(pagename, pagedata, forcecreate)
    if not MOD_util:CanAddSetting() then
        return
    end
    settingscreen:CreatePage(pagename, pagedata, forcecreate)
end

--
function MOD_util:StandardPage(pagename, buttonname, order, pagetitle)
    if not MOD_util:CanAddSetting() then
        return
    end
    settingscreen:StandardPage(pagename, buttonname, order, pagetitle)
end

function MOD_util:AddEnableDisableOption(pagename, key, default, description, hover)
    if not MOD_util:CanAddSetting() then
        return
    end
    if default == nil then
        default = true
    end
    settingscreen:AddEnableDisableOption(pagename, key, default, description, hover)
end

function MOD_util:AddKeyBinds(pagename, key, default, description, hover)
    if not MOD_util:CanAddSetting() then
        return
    end
    if default == nil then
        default = true
    end
    settingscreen:AddKeyBinds(pagename, key, default, description, hover)
end

function MOD_util:AddOption(pagename, key, options, default, description, hover)
    if not MOD_util:CanAddSetting() then
        return
    end
    if default == nil then
        default = true
    end
    settingscreen:AddOption(pagename, key, options, default, description, hover)
end

function MOD_util:GetKeyFromConfig(name)
    local a = GetModConfigData(name)
    return a and rawget(GLOBAL, a)
end

--addclickfunction

return MOD_util
