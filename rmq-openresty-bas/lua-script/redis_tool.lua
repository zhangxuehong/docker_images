local _M = {}

_M._VERSION = '1.0'

local mt = { __index = _M }

-- keepalive_pool: Basically if your NGINX handle n concurrent requests and your NGINX has m workers, then the connection pool size should be configured as n/m.
-- For example, if your NGINX usually handles 1000 concurrent requests and you have 10 NGINX workers, then the connection pool size should be 100.
local config = {
    server = "",
    port = 6379,
    password = "",
    timeout_connect = 1000, -- 单位 ms
    timeout_send = 1000, -- 单位 ms
    timeout_read = 1000,  -- 单位 ms
    keepalive_time = 60000,  -- 单位 ms
    keepalive_pool = 50  -- 单位 个数
}

function _M.new(self)
    -- 获取 redis 配置的环境参数 prd 或者 test
    local profiles_active = ngx.var.redis_profiles_active
    if profiles_active and profiles_active ~= ngx.null and profiles_active == "prd" then
        -- prd 即生产环境配置
        config.server = "10.134.36.28"
        config.password = "TKZ@21858!rs"
    else
        -- test 等其他环境配置或者默认配置
        config.server = "10.153.58.166"
        config.password = "zhangxh@132"
    end

    -- 连接 redis 初始化开始
    -- 导入lua redis模块
    -- 模块地址: https://github.com/openresty/lua-resty-redis
    -- ngx.exit(0) 退出说明：退出的意思是退出当前 lua 脚本。执行 ngx 的下一个指令。这里使用的是正常退出的编码，其实凡是走到这里都是异常的。但是为了不影响连接正常连接，所以使用编码 0 或者 ngx.OK
    -- 创建 red 变量
    local redis = require "resty.redis"
    local red, err = redis:new()  -- 创建redis对象, redTool 为 redis 对象
    if not red then
        ngx.log(ngx.ERR, "failed to create redis object: " .. err)
        ngx.exit(0)
    end

    red:set_timeouts(config.timeout_connect, config.timeout_send, config.timeout_read) --超时时间1秒, 分别是connect, send, read

    -- redis连接,如果连接失败,清理 red 变量。没有连接应该是执行不了 close 的
    local ok, err = red:connect(config.server, config.port)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect: " .. err)
        red = nil
        ngx.exit(0)
    end

    -- redis认证
    local ok, err = red:auth(config.password)
    if not ok then
        ngx.log(ngx.ERR, "failed to auth: "  .. err)
        if red then
            red:close()
            red = nil
        end
        ngx.exit(0)
    end
    -- 连接 redis 初始化结束
    return setmetatable({red = red, err = err}, mt)
end

-- 用于操作处理使用 redis 的执行操作的时候错误 get set 等
function _M.operationError(self, key, res, err)
    if not res then
        ngx.log(ngx.ERR, "failed to get " ..tostring(key) .. ":" .. tostring(err))
        if self.red then
            _M.redisKeepAlive(self)
        end
        ngx.exit(0)
    end
end

-- 用于操作使用 redis 的操作过程中要关闭当前连接池连接的方法
function _M.redisKeepAlive (self)
    ngx.log(ngx.ERR, "keepalive::::::::::::::::" )
    local ok, err = self.red:set_keepalive(config.keepalive_time, config.keepalive_pool)
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: " .. err)
    end
end


return _M
