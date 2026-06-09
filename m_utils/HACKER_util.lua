local HACKER_util = {}
function HACKER_util:ReadFileStr(path, modname)
    if modname then
        path = "../mods/" .. modname .. "/" .. path
    end
    local file = io.open(path, "r")
    if not file then return end;
    local str = file:read("*a")
    --print(str)
    file:close()
    return str
end

function HACKER_util:WriteStrToFile(str, path, modname)
    if modname then
        path = "mods/" .. modname .. "/" .. path
    end
    RW_util:SaveData(str, path)
end

function HACKER_util:HackerStr_math(str)
    do
        local start_pos = 1
        while true do
            local work = false
            --是否用括号判断括住算式
            local pattern = "%b()" -- %b() 匹配成对的括号
            local mathstr = str:sub(start_pos)
            local equation = mathstr:match(pattern)
            print(equation) -- 输出: (295 * 339 + 472 + 394 - 58 == 100815)

            local result = equation
            if result then
                local symbol_pos = string.find(str, result, start_pos, true)
                local callfn = loadstring("return " .. result)
                if callfn then
                    local success, retval = pcall(callfn)
                    if success then
                        -- 如果返回值是字符串，用引号括起来
                        local nextright = symbol_pos + #equation
                        if type(retval) == "string" then
                            str = string.sub(str, start_pos, symbol_pos - 1) .. "(" ..
                                '"' .. retval .. '"' .. ")" .. string.sub(str, nextright, #str)
                        else
                            str = string.sub(str, start_pos, symbol_pos - 1) .. "(" ..
                                tostring(retval) .. ")" .. string.sub(str, nextright, #str)
                        end
                        work = true
                        start_pos = symbol_pos + #retval + 2
                    else
                        work = true
                        start_pos = symbol_pos + 1
                    end
                end
            end
            if not work then
                break
            end
        end
    end
    do
        local start_pos = 1
        while true do
            local work = false
            --是否用括号判断括住算式
            local pattern = "%b[]"
            local mathstr = str:sub(start_pos)
            local equation = mathstr:match(pattern)
            print(equation) -- 输出: (295 * 339 + 472 + 394 - 58 == 100815)

            local result = equation
            if result then
                local symbol_pos = string.find(str, result, start_pos, true)
                local a = string.gsub(result, "%[", "(")
                a = string.gsub(a, "%]", ")")
                local callfn = loadstring("return " .. a)
                if callfn then
                    local success, retval = pcall(callfn)
                    if success then
                        -- 如果返回值是字符串，用引号括起来
                        local nextright = symbol_pos + #equation
                        if type(retval) == "string" then
                            str = string.sub(str, start_pos, symbol_pos - 1) .. "[" ..
                                '"' .. retval .. '"' .. "]" .. string.sub(str, nextright, #str)
                        else
                            str = string.sub(str, start_pos, symbol_pos - 1) .. "[" ..
                                tostring(retval) .. "]" .. string.sub(str, nextright, #str)
                        end
                        work = true
                        retval = tostring(retval)
                        start_pos = symbol_pos + #retval + 2
                    else
                        work = true
                        start_pos = symbol_pos + 1
                    end
                end
            end
            if not work then
                break
            end
        end
    end
    return str
end

function HACKER_util:HackerStr_main(str)
    str = self:HackerStr_math(str)
end

function HACKER_util:Init()
    local function find_function_calls(str)
        local start_pos = 1
        while true do
            local functions = { "I1lIl1Il1I1l", "I1lI1lIl1Il1", "I1lIl1I1lIl1", }
            local work = false
            for _, func in ipairs(functions) do
                -- 查找函数名出现的位置
                local func_start = str:find(func, start_pos, true)
                if func_start then
                    local nextright = str:find(")", func_start, true)
                    local result = string.sub(str, func_start, nextright)

                    local callfn = loadstring("return " .. result)
                    if callfn then
                        local success, retval = pcall(callfn)
                        if success then
                            -- 如果返回值是字符串，用引号括起来
                            if type(retval) == "string" then
                                str = string.sub(str, start_pos, func_start - 1) ..
                                    '"' .. retval .. '"' .. string.sub(str, nextright + 1, #str)
                            else
                                str = string.sub(str, start_pos, func_start - 1) ..
                                    retval .. string.sub(str, nextright + 1, #str)
                            end
                            work = true
                            break
                        end
                    end
                end
            end
            if not work then
                break
            end
        end


        return str
    end

    --替换一个文件内的满足条件的字符为自己想要的
    local function replaceStrInFile(filePath, output)
        --read
        local pre = "../mods/workshop-2979177306/"
        local file1 = io.open(pre .. filePath, "r")
        if not file1 then return end;
        local str = file1:read()
        --print(str)
        file1:close()
        --replace
        str = find_function_calls(str)
        --print(str)

        do
            local aa = string.gsub(output or filePath, ".lua", ".txt")
            local file2 = io.open("unsafedata/" .. aa, "w")
            if not file2 then return end;
            file2:write(str)
            file2:close()
        end
    end
    replaceStrInFile("main/lg_skin_ownership.lua", "lg_skin_ownership.lua")
end

return HACKER_util
