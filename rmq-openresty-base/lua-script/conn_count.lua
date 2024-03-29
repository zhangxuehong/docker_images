---
--- Generated by Luanalysis
--- Created by jiang.
--- DateTime: 2020/12/28 14:29
---

-- 调试接口
-- local breakSocketHandle,debugXpCall = require("LuaDebugOpenrestyJit")("localhost",7003)

--- 忽略字符串头部的空白字符
local function ltrim(input)
    return (string.gsub(input, "^[ \t\n\r]+", ""))
end

--- 忽略字符串尾部的空白字符
local function rtrim(input)
    return (string.gsub(input, "[ \t\n\r]+$", ""))
end

--- 忽略字符串首尾的空白字符
local function trim(input)
    return (string.gsub(input, "^%s*(.-)%s*$", "%1"))
end

--- 格式化ss命令输出格式,eg., "nginx_lua_client_connect_total {host="192.168.61.1",status="connect"} 4"
local function connFormat(cli_addr, conn_count)
    return string.format('nginx_lua_client_connect_total {host="%s",status="connect"} %d\n', tostring(cli_addr), tonumber(conn_count))
end

-- local args = {"8672", "8080"}

--- function 接受table类型, 多个值将以or进行拼接, 以便ss命令执行条件操作 
--- 拼接脚本后参数,参数为 "9145 8080 5678 ..." 拼接为 "sport = :9145 or sport = :8080 or sport = :5678 or ..."
--- @param arg table<number, V>|V[]
--- @return string
local function argFormat(arg)
    local sportTable = {}
    for index, value in ipairs(arg) do
        if (tonumber(index) == 1) then
            table.insert(sportTable, string.format("sport = :%d", tonumber(value)))
        else
            table.insert(sportTable, string.format(" or sport = :%d", tonumber(value)))
        end
    end
    return table.concat(sportTable)
end

local function outP(args)
    local _res = io.popen('PATH=$PATH:/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin && ss -n -o state established ' .. argFormat(args) .. ' | awk \'NR>1{print $5}\' | awk -F : \'{print $1}\' | sort -nr | uniq -c')
    local outTable = {}
    -- for cnt in io.lines("test1") do
    for cnt in _res:lines() do
        local conn_count, cli_addr = string.match(cnt, '(%d+)%s+(%d+.%d+.%d+.%d+)')
        -- print(connFormat(cli_addr, conn_count))
        table.insert(outTable, connFormat(cli_addr, conn_count))
        -- ngx.say(connFormat(cli_addr, conn_count))
        -- return connFormat(cli_addr, conn_count)
    end
    _res:close()
    return outTable
end

function ConnCount(portTable)
    ngx.header.content_type = "text/plain"
    ngx.print(outP(portTable))
end

-- ConnCount({"8672", "8080"})
