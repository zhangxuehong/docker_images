--[[
对于自定义的 lua 在 http 模块和 stream 模块都要扩展 lua_package_path
        lua_package_path "/usr/local/openresty/lua-script/?.lua;;";
        lua_package_cpath "/usr/local/openresty/lua-script/?.so;;";
]]

--[[封禁策略配置在 redis 中:
key: block_policy:rabbitmq
value: {
business: rabbitmq_backup
block_policy: grey     -- block_policy 目前定义为 2 种  grey:发送告警通知 , orange:启动封禁, red: 永久封禁(只能进行手工修改)
current_policy_period:  -- 当前封禁级别持续时长
ip_frequency_time: 30   -- 指定ip访问频率时间段(秒)
ip_max_count: 20       -- 指定ip访问频率计数最大值(个数)
ip_block_time: 300     -- 封禁IP时间(秒)
}


]]

-- 默认值 BEGIN
local BLOCK_POLICY = 1  -- 封禁策略, 默认 1, 表示符合的key就禁止
if tonumber(ngx.var.block_policy) ~= nil then
    BLOCK_POLICY = tonumber(ngx.var.block_policy)
end

local IP_BLOCK_TIME = 6000  --封禁IP时间(秒)
if tonumber(ngx.var.ip_block_time) ~= nil then
    IP_BLOCK_TIME = tonumber(ngx.var.ip_block_time)
end

local IP_FREQUENCY_TIME = 300  --指定ip访问频率时间段(秒)
if tonumber(ngx.var.ip_frequency_time) ~= nil then
    IP_FREQUENCY_TIME = tonumber(ngx.var.ip_frequency_time)
end

local IP_MAX_COUNT = 2  --指定ip访问频率计数最大值(个数)
if tonumber(ngx.var.ip_max_count) ~= nil then
    IP_MAX_COUNT = tonumber(ngx.var.ip_max_count)
end

local BUSINESS = "LuaConnectLimit"  --nginx的location中定义的业务标识符, 也可以不加, 不过加了后方便区分
if tostring(ngx.var.business) ~= "nil" then
    BUSINESS = ngx.var.business
end

-- 默认值 END


-- 开始操作 redis
local redisTool = require('redis_tool')
local rt = redisTool:new()
local red = rt.red
-- 封禁策略开始
-- 在使用的过程中 redis 的当前连接需要关闭，使用 redisKeepAlive 来关闭
-- redis 查询过程复用的 key
local block_key = BUSINESS..":BLOCK:"..ngx.var.remote_addr
local count_key = BUSINESS..":COUNT:"..ngx.var.remote_addr

--查询ip是否被禁止访问，如果存在则返回403错误代码
local is_block, err = red:get(block_key)
rt:operationError(block_key, is_block, err)
if is_block ~= ngx.null then
    if tonumber(is_block) == BLOCK_POLICY then
        redisKeepAlive()
        ngx.exit(403)
    end
end

--查询redis中保存的ip的计数器
local ip_count, err = red:get(count_key)
rt:operationError(count_key, ip_count, err)
ngx.log(ngx.ERR, "[ count_key::: " .. tostring(count_key) .. " ] ")
ngx.log(ngx.ERR, "[ ip_count::: " .. tostring(ip_count) .. " ] ")
if ip_count == ngx.null then --如果不存在, 则将该IP存入redis, 并将计数器设置为1, 该KEY的超时时间为IP_FREQUENCY_TIME
    local ok, err = red:set(count_key, 1, "ex", IP_FREQUENCY_TIME)
	-- local ok, err = red:expire(count_key, IP_FREQUENCY_TIME)
else
    ip_count = ip_count + 1 --存在则将单位时间内的访问次数加1

    if ip_count >= IP_MAX_COUNT then --如果超过单位时间限制的访问次数, 则添加限制访问标识, 限制时间为IP_BLOCK_TIME
        local ok, err = red:set(block_key, 1, "ex", IP_FREQUENCY_TIME)
        -- local ok, err = red:expire(block_key, IP_BLOCK_TIME)
	else
        local key_expire, err = red:ttl(count_key)
        local ok, err = red:set(count_key, ip_count, "ex", key_expire)
		-- local ok, err = red:expire(count_key, key_expire)
    end
end

-- 结束标记

rt:redisKeepAlive()

ngx.exit(0)
