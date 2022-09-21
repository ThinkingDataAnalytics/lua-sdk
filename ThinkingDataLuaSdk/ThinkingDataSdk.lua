-- LuaSDK
function class(base, _ctor)
    local c = {}
    if not _ctor and type(base) == 'function' then
        _ctor = base
        base = nil
    elseif type(base) == 'table' then
        for i, v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end
    c.__index = c
    local mt = {}
    mt.__call = function(_, ...)
        local obj = {}
        setmetatable(obj, c)
        if _ctor then
            _ctor(obj, ...) 
        end
        return obj
    end
    c._ctor = _ctor
    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do
            if m == klass then
                return true
            end
            m = m._base
        end
        return false
    end
    setmetatable(c, mt)
    return c
end


--SDK
TdSDK = class(function(self, consumer, strictMode, enableLog)
    if consumer == nil or type(consumer) ~= "table" then
        error("consumer参数不正确.")
    end
    self.consumer = consumer
    self.checkKeyAndValue = strictMode or TdSDK.strictMode
    self.superProperties = {}
    self.dynamicSuperPropertiesTracker = nil
    Util.enableLog = enableLog
end)


--TADynamicSuperPropertiesTracker
TdSDK.TADynamicSuperPropertiesTracker = class()

function TdSDK.TADynamicSuperPropertiesTracker:getProperties()
end

--DebugConsumer
TdSDK.DebugConsumer = class(function(self, url, appid, debugOnly)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        error("appid不能为空.")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        error("上报地址不能为空.")
    end
    self.url = url .. "/data_debug"
    self.appid = appid
    self.debugOnly = debugOnly
    TdSDK.strictMode = true
end)
function TdSDK.DebugConsumer:add(msg)
    local returnCode, code = Util.post(self.url, self.appid, msg, true, self.debugOnly)
    Util.log("Info: ", "同步发送到: " .. self.url .. " 返回Code:[" .. code .. "]\nBody: " .. Util.toJson(msg) .. "\n返回: " .. returnCode)
    if (returnCode == 0) then
        return true
    end
    return false
end
function TdSDK.DebugConsumer:flush()
end
function TdSDK.DebugConsumer:close()
end
function TdSDK.DebugConsumer:toString()
    return "\n--Consumer: DebugConsumer" ..
            "\n--Consumer.Url: " .. self.url ..
            "\n--Consumer.Appid: " .. self.appid
end

--BatchConsumer
TdSDK.BatchConsumer = class(function(self, url, appid, batchNum, cacheCapacity)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        error("appid不能为空。")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        error("上报地址不能为空。")
    end
    if batchNum ~= nil and type(batchNum) ~= "number" then
        error("批量条数应该为Number类型。")
    end
    self.url = url .. "/sync_server"
    self.appid = appid
    self.batchNum = batchNum or TdSDK.batchNumber
    self.eventArrayJson = {}
    self.cacheCapacity = cacheCapacity or TdSDK.cacheCapacity
    self.cacheTable = {}
end)
function TdSDK.BatchConsumer:add(msg)
    local num = #self.eventArrayJson + 1
    self.eventArrayJson[num] = msg
    if (num >= self.batchNum or #self.cacheTable > 0) then
        return self:flush()
    end
    return true
end
function TdSDK.BatchConsumer:flush(flag)
    if #self.eventArrayJson == 0 and #self.cacheTable == 0 then
        return true
    end
    if (flag or #self.eventArrayJson >= self.batchNum or #self.cacheTable == 0) then
        local events = self.eventArrayJson
        self.eventArrayJson = {}
        table.insert(self.cacheTable, events)
    end
    while (#self.cacheTable > 0)
    do
        local events = self.cacheTable[1]
        local returnCode, code = Util.post(self.url, self.appid, events)
        if (code == 200) then
            table.remove(self.cacheTable, 1)
        else
            if (#self.cacheTable > self.cacheCapacity) then
                table.remove(self.cacheTable, 1)
            end
            return false
        end
        if (not flag) then
            if (returnCode ~= 0) then
                return false
            else
                return true
            end
        end
    end

    return true
end
function TdSDK.BatchConsumer:close()
    return self:flush(true)
end
function TdSDK.BatchConsumer:toString()
    return "\n--Consumer: BatchConsumer" ..
            "\n--Consumer.Url: " .. self.url ..
            "\n--Consumer.Appid: " .. self.appid ..
            "\n--Consumer.BatchNum: " .. self.batchNum
end

--LogConsumer
TdSDK.LogConsumer = class(function(self, logPath, rule, batchNum, fileSize, fileNamePrefix)
    if logPath == nil or type(logPath) ~= "string" or string.len(logPath) == 0 then
        error("日志目录不能为空.")
    end
    if rule ~= nil and type(rule) ~= "string" then
        error("文件名规则参数错误.")
    end

    if batchNum ~= nil and type(batchNum) ~= "number" then
        error("批量条数应该为Number类型.")
    end
    self.rule = rule or TdSDK.LOG_RULE.DAY
    self.logPath = Util.mkdirFolder(logPath)
    self.fileNamePrefix = fileNamePrefix
    self.fileSize = fileSize
    self.count = 0;
    self.file = nil;
    self.batchNum = batchNum or TdSDK.batchNumber
    self.currentFileTime = os.date("%Y-%m-%d %H")
    self.fileName = Util.getFileName(logPath, fileNamePrefix, self.rule)
    self.eventArrayJson = {}
    Util.log("Info: ", "LogConsumer生效, 日志目录为: " .. self.logPath .. " 文件切分方式: " .. self.rule)
end)
function TdSDK.LogConsumer:add(msg)
    local num = #self.eventArrayJson + 1
    self.eventArrayJson[num] = msg
    if (num >= self.batchNum) then
        self:flush()
    end
    return num
end
function TdSDK.LogConsumer:flush()
    if #self.eventArrayJson == 0 then
        return true
    end
    local isFileNameChange = false
    if self.rule == TdSDK.LOG_RULE.HOUR then
        isFileNameChange = self.currentFileTime ~= os.date("%Y-%m-%d %H")
    else
        isFileNameChange = string.sub(self.currentFileTime, 1, 11) ~= os.date("%Y-%m-%d")
    end

    if isFileNameChange then
        self.currentFileTime = os.date("%Y-%m-%d %H")
        self.fileName = Util.getFileName(self.logPath, self.fileNamePrefix, self.rule)
        self.count = 0
    end
    local result, cCount, file = Util.writeFile(self.fileName, self.eventArrayJson, self.count, self.fileSize, isFileNameChange, self.file)
    if (result) then
        self.count = cCount
        self.file = file
        self.eventArrayJson = {}
    end
    return true
end
function TdSDK.LogConsumer:close()
    self:flush()
end
function TdSDK.LogConsumer:toString()
    return "\n--Consumer: LogConsumer" ..
            "\n--Consumer.LogPath: " .. self.logPath ..
            "\n--Consumer.Rule: " .. self.rule ..
            "\n--Consumer.BatchNum: " .. self.batchNum
end

--[[
     * 设置动态公共属性,之后每次发送的消息体中都获取该属性值
     * @param params 属性
--]]
function TdSDK:setDynamicSuperProperties(callback)
    if callback ~= nil then
        self.dynamicSuperPropertiesTracker = callback
    end
end
--[[
     * 注册公共属性,注册后每次发送的消息体中都包含该属性值
     * @param params 属性
--]]
function TdSDK:setSuperProperties(params)
    if self.checkKeyAndValue == true then
        local ok, ret = pcall(checkKV, params)
        if not ok then
            Util.log("Error: ", "注册公共属性错误: ", ret)
            return
        end
    end

    if (type(params) == "table") then
        self.superProperties = Util.mergeTables(self.superProperties, params)
    end
end
function TdSDK:setSuperProperty(key, value)
    if (key ~= nil) then
        local params = {}
        params[key] = value
        print(params[key])
        self:setSuperProperties(params)
    end
end
--[[
     * 移除公共属性
     * @param key 属性Key
--]]
function TdSDK:removeSuperProperty(key)
    self.superProperties[key] = nil
end
--[[
     * 获取公共属性
     * @param key 属性Key
     * @return 该KEY的公共属性值
--]]
function TdSDK:getSuperProperty(key)
    Util.log("", "获取公共属性" .. key .. "值为: " .. self.superProperties[key])
    return self.superProperties[key]
end
--[[
     * 获取公共属性
     * @return 所有公共属性
--]]
function TdSDK:getSuperProperties()
    return self.superProperties
end
--清除公共属性
function TdSDK:clearSuperProperties()
    self.superProperties = {}
end

--[[
     * 设置用户的属性
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userSet(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_set", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userSet方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userSet方法错误: ", ret)
    end
end
--[[
     * 首次设置用户的属性,该属性只在首次设置时有效
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userSetOnce(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_setOnce", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userSetOnce方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userSetOnce方法错误: ", ret)
    end
end
--[[
     * 为用户的一个或多个数值类型的属性累加一个数值
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userAdd(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_add", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userAdd方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userAdd方法错误: ", ret)
    end
end
--[[
     * 追加用户列表类型的属性
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userAppend方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userAppend方法错误: ", ret)
    end
end
--[[
     * 追加用户列表类型的属性 去重
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userUniqueAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_uniq_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userUniqueAppend方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userUniqueAppend方法错误: ", ret)
    end
end
--[[
     * 删除用户属性
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param properties 事件属性
--]]
function TdSDK:userUnset(accountId, distinctId, properties)
    local unSetProperties = {}
    for key, value in pairs(properties) do
        if Util.startWith(key, '#')then
            unSetProperties[key] = value
        else
            unSetProperties[key] = 0
        end
    end
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_unset", nil, nil, unSetProperties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userUnSet方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userUnSet方法错误: ", ret)
    end
end
--[[
     * 删除用户
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
--]]
function TdSDK:userDel(accountId, distinctId)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_del", nil, nil, {}, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用userDelete方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用userDelete方法错误: ", ret)
    end
end

--[[
     * 事件数据
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param eventName 事件名称
     * @param properties 事件属性
--]]
function TdSDK:track(accountId, distinctId, eventName, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track", eventName, "", properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用track方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用track方法错误: ", ret)
    end
end
--[[
     * 首次事件
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param eventName 事件名称
     * @param firstCheckId 首次事件维度ID
     * @param properties 事件属性
--]]
function TdSDK:trackFirst(accountId, distinctId, eventName, firstCheckId, properties)
    local mProperties = {}
    for i,v in ipairs(properties) do
        print(v)
        mProperties[i] = v
    end
    Util.tablecopy(properties,mProperties)   
    if firstCheckId ~= nil and string.len(firstCheckId) ~= 0 then
        mProperties["#first_check_id"] = tostring(firstCheckId)
    else
        mProperties["#first_check_id"] = tostring(distinctId)
    end
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track", eventName, nil, mProperties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用trackFirst方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用trackFirst方法错误: ", ret)
    end
end
--[[
     * 更新旧属性值
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param eventName 事件名称
     * @param eventId 事件ID
     * @param properties 事件属性
--]]
function TdSDK:trackUpdate(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_update", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用track_update方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用track_update方法错误: ", ret)
    end
end
--[[
     * 覆盖所有旧属性
     * @param distinctId 未登录用户ID
     * @param accountId 登录用户ID
     * @param eventName 事件名称
     * @param eventId 事件ID
     * @param properties 事件属性
--]]
function TdSDK:trackOverwrite(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_overwrite", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "调用track_overwrite方法: 成功")
        return ret
    else
        Util.log("Error: ", "调用track_overwrite方法错误: ", ret)
    end
end

--[[
     * 上传数据,首先校验相关KEY和VALUE,符合规则才可以上传
     * @param consumer 收集器
     * @param distinctId 用户标识
     * @param isLogin 是否登陆
     * @param eventName 事件名称
     * @param eventId 事件ID，结合eventName用于track_update和track_overwrite
     * @param properties 属性
     * @param super 公共属性
--]]
function upload(consumer, distinctId, accountId, eventType, eventName, eventId, properties, superProperties, dynamicSuperPropertiesTracker, checkKeyAndValue)
    local finalProperties, presetProperties = divide(properties)
    local dynamicSuperProperties = {}
    if dynamicSuperPropertiesTracker ~= nil then
        dynamicSuperProperties = dynamicSuperPropertiesTracker:getProperties()
        check(distinctId, accountId, eventType, eventName, eventId, finalProperties, dynamicSuperProperties, checkKeyAndValue)
    else
        check(distinctId, accountId, eventType, eventName, eventId, finalProperties, checkKeyAndValue)
    end
    local eventJson = {}
    if accountId ~= nil and string.len(accountId) ~= 0 then
        eventJson["#account_id"] = tostring(accountId)
    end
    if distinctId ~= nil and string.len(distinctId) ~= 0 then
        eventJson["#distinct_id"] = tostring(distinctId)
    end
    eventJson["#type"] = eventType
    if eventName ~= nil and string.len(eventName) ~= 0 then
        eventJson["#event_name"] = tostring(eventName)
    end
    if eventId ~= nil and string.len(eventId) ~= 0 then
        eventJson["#event_id"] = tostring(eventId)
    end
    --预置属性
    for key, value in pairs(presetProperties) do
        eventJson[key] = value
    end
    if presetProperties["#time"] == nil then
        eventJson["#time"] = os.date("%Y-%m-%d %H:%M:%S")
    end
    local mergeProperties = {}
    if eventType == "track" or eventType == "track_update" or eventType == "track_overwrite" then
        mergeProperties = Util.mergeTables(mergeProperties, superProperties)
        mergeProperties = Util.mergeTables(mergeProperties, dynamicSuperProperties)
        mergeProperties["#lib"] = TdSDK.platForm
        mergeProperties["#lib_version"] = TdSDK.version
    end
    mergeProperties = Util.mergeTables(mergeProperties, finalProperties)
    eventJson["properties"] = mergeProperties
    local ret = consumer:add(eventJson)
    presetProperties = nil
    finalProperties = nil
    mergeProperties = nil
    eventJson = nil
    return ret
end

function divide(properties)
    local presetProperties = {}
    local finalProperties = {}
    for key, value in pairs(properties) do
        if (key == "#ip" or key == "#uuid" or key == "#first_check_id" or key == "#time" or key == "#app_id") then
            presetProperties[key] = value
        else
            finalProperties[key] = value
        end
    end
    if (presetProperties["#uuid"] == nil) then
        presetProperties["#uuid"] = Util.create_uuid()
    end
    return finalProperties, presetProperties
end

function check(distinctId, accountId, eventType, eventName, eventId, properties, dynamicSuperProperties, checkKeyAndValue)
    if checkKeyAndValue == nil or checkKeyAndValue == false then
        return
    end
    assert(distinctId == nil or type(distinctId) == "string" or type(distinctId) == "number", "distinctId参数应该为数字或字符串")
    assert(accountId == nil or type(accountId) == "string" or type(accountId) == "number", "accountId参数应该为数字或字符串")
    assert(type(eventType) == "string", "type参数应该为字符串类型")
    assert(eventName == nil or type(eventName) == "string", "eventName应该为字符串类型")
    assert(type(properties) == "table", "properties应该为Table类型")
    if dynamicSuperProperties ~= nil then
        assert(type(dynamicSuperProperties) == "table", "dynamicSuperProperties应该为Table类型")
        checkKV(dynamicSuperProperties, eventName)
    end
    --校验字段
    if ((distinctId == nil or string.len(distinctId) == 0) and (accountId == nil or string.len(accountId) == 0)) then
        error("distinctId和accountId不能同时为空！")
    end
    if (Util.startWith(eventType, "track") and (eventName == nil or string.len(eventName) == 0)) then
        error("type为track、track_update或track_overwrite时，eventName不能为空！")
    end
    if (Util.startWith(eventType, "track_")  and (eventId == nil or string.len(eventId) == 0)) then
        error("type为track_update或track_overwrite时，eventId不能为空！")
    end
    checkKV(properties, eventName)
end

function checkKV(properties, eventName)
    --校验K/V
    local userAdd = "user_add"
    local userUnset = "user_unset"
    for key, value in pairs(properties) do
        if (string.len(key) == 0) then
            Util.log("Warn: ", "The property key is empty")
        end
        if (type(value) ~= "string" and
                type(value) ~= "number" and
                type(value) ~= "boolean" and
                type(value) ~= "table") then
            Util.log("Warn: ", "The property " .. key .. " is not number, string, boolean, table.")
        end
        if (type(value) == "table") then
            for k, v in pairs(value) do
                if (type(v) ~= "string" and type(v) ~= "number" and type(v) ~= "boolean" and type(v) ~= "table") then
                    Util.log("Warn: ", "The table property " .. k .. " is not number, string, boolean, table.")
                end
            end
        end
        if (type(value) == "string" and string.len(value) == 0 and not (userUnset == eventName)) then
            Util.log("Warn: ", "The property " .. key .. " string value is null or empty")
        end

        if (userAdd == eventName and type(value) ~= "number") then
            Util.log("Warn: ", "The property value of " .. key .. " should be a number ")
        end
    end
end

function TdSDK:flush()
    self.consumer:flush()
end

function TdSDK:close()
    self.consumer:close()
end

function TdSDK:toString()
    return self.consumer:toString()
end

TdSDK.platForm = "Lua"
TdSDK.version = "1.5.1"
TdSDK.batchNumber = 20
TdSDK.strictMode = false
TdSDK.cacheCapacity = 50
TdSDK.logModePath = "."

TdSDK.LOG_RULE = {}
TdSDK.LOG_RULE.HOUR = "%Y-%m-%d-%H"
TdSDK.LOG_RULE.DAY = "%Y-%m-%d"

Util = {}
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")
function Util.post(url, appid, eventArrayJson, isDebug, debugOnly)
    if not isDebug and #eventArrayJson == 0 then
        return "", ""
    end
    local request_body = toJson(eventArrayJson)
    print(request_body)
    local contentType = "application/json"
    if isDebug then
        local dryRun = 0
        if debugOnly then
            dryRun = 1
        end
        data =  urlEncode(request_body);
        request_body = urlEncode(request_body)
        request_body = "data=" .. request_body .. "&source=server&appid=" .. appid .. "&dryRun=" .. dryRun
        contentType = "application/x-www-form-urlencoded"
    end
    local response_body = {}
    local count = 0
    local res, code
    while (count < 3)
    do
        res, code = http.request {
            url = url,
            create = function()
                local req_sock = socket.tcp()
                req_sock:settimeout(30, 't')
                return req_sock
            end,
            method = "POST",
            headers = {
                ["appid"] = appid;
                ["TA-Integration-Type"] = TdSDK.platForm;
                ["TA-Integration-Version"] = TdSDK.version;
                ["TA-Integration-Count"] = #eventArrayJson;
                ["Content-Type"] = contentType;
                ["Content-Length"] = #request_body;
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
        }
        res = table.concat(response_body)
        if code ~= nil and type(code) == "number" and tonumber(code) == 200 then
            break
        end
        print("requestUrl"..url)
        print("Error: Up failed,code: " .. code .. ",res: " .. res .. " data: " .. request_body)
        count = count + 1
    end
    if count >= 3 then
        return -1, code
    end
    local resultCode
    local resultJson = cjson.decode(res)
    if isDebug then
        resultCode = tonumber(resultJson["errorLevel"])
        if resultCode ~= 0 then
            print("Error: Up failed, result: " .. res)
        end
    else
        resultCode = tonumber(resultJson["code"])
        if resultCode ~= 0 then
            local msg = resultJson["msg"]
            if msg == nil or #msg == 0 then
                if resultCode == -1 then
                    msg = "invalid data format"
                elseif resultCode == -2 then
                    msg = "APP ID doesn't exist"
                elseif resultCode == -3 then
                    msg = "invalid ip transmission"
                else
                    msg = "Unexpected response return code"
                end
            end
            print("Error:up failed:" .. resultCode .. "，msg:" .. msg)
        end
    end

    return resultCode, code
end

function isWindows()
    local separator = package.config:sub(1, 1)
    local osName = os.getenv("OS")
    local isWindows = (separator == '\\' or (osName ~= nil and startWith(string.lower(osName), "windows")))
    return isWindows
end

function Util.toJson(eventArrayJson)
    return cjson.encode(eventArrayJson)
end

function toJson(eventArrayJson)
    return cjson.encode(eventArrayJson)
end

function urlEncode(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(s, " ", "+")
end

function Util.mergeTables(...)
    local tabs = { ... }
    if not tabs then
        return {}
    end
    local origin = tabs[1]
    for i = 2, #tabs do
        if origin then
            if tabs[i] then
                for k, v in pairs(tabs[i]) do
                    if (v ~= nil) then
                        origin[k] = v
                    end
                end
            end
        else
            origin = tabs[i]
        end
    end
    return origin
end

function fileExists(path)
    local retTable = { os.execute("cd " .. path) }
    local code = retTable[3] or retTable[1]
    return code == 0
end

function Util.mkdirFolder(path)
    if (fileExists(path)) then
        return path
    end
    local isWindows = isWindows()
    local cmd = "mkdir -p " .. path
    if (isWindows) then
        cmd = "mkdir " .. path
    end
    local retTable = { os.execute(cmd) }
    local code = retTable[3] or retTable[1]
    if (code ~= 0) then
        if (isWindows) then
            return os.getenv("TEMP")
        else
            return "/tmp"
        end
    end
    return path
end

function Util.writeFile(fileName, eventArrayJson, count, fileSize, close, file)
    if #eventArrayJson == 0 then
        return false, count, file
    end
    local cCount = count
    local cFile = file
    if close and cFile then
        cFile:close()
        cFile = nil
        cCount = cCount + 1
    end

    if not cFile then
        cFile = assert(io.open(fileName .. "_" .. cCount, 'a'))
    end
    if cFile:seek("end") < fileSize * 1024 * 1024 then
        local data = ""
        for i = 1, #eventArrayJson do
            local json = toJson(eventArrayJson[i])
            data = data .. json .. "\n"
        end
        cFile:write(data)
        return true, cCount, cFile
    else
        return _Util.writeFile(fileName, eventArrayJson, cCount, fileSize, true, cFile)
    end
end

function Util.getFileName(filePath, fileNamePrefix, rule)
    local isWindows = isWindows()
    local separator = "/"
    if (isWindows) then
        separator = "\\"
    end
    local fileName
    if not fileNamePrefix or #fileNamePrefix == 0 then
        fileName = filePath .. separator .. "log." .. os.date(rule)
    else
        fileName = filePath .. separator .. fileNamePrefix .. ".log." .. os.date(rule)
    end

    return fileName
end

function Util.getFileCount(fileName, fileSize, count)
    if not fileSize or fileSize <= 0 then
        return nil
    end

    if not count then
        count = 0
    end

    local result = fileName .. "_" .. count
    local file = assert(io.open(result, "a"))
    while file
    do
        local len = assert(file:seek("end"))
        if len < (fileSize * 1024 * 1024) then
            file:close()
            file = nil
        else
            count = count + 1
            result = fileName .. "_" .. count
            file = assert(io.open(result, "a"))
        end
    end
    return count
end


function Util.startWith(str, substr)
    if str == nil or substr == nil then
        return false
    end
    if string.find(str, substr) ~= 1 then
        return false
    else
        return true
    end
end
--日志打印
function Util.log(level, key, msg)
    if Util.enableLog then
        print(level .. (key or "") .. (msg or ""))
    end
end
function Util.tablecopy(src, dest)
    for k, v in pairs(src) do
      if type(v) == "table" then
        dest[k] = {}
        Util.tablecopy(v, dest[k])
      else
        dest[k] =  v
      end
    end
  
  end

function Util.create_uuid()
    local seed = {'e','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
    local sid = ""
    for i=1,32 do
        -- table.insert(tb,seed[math.random(1,16)])
        sid = sid .. seed[math.random(1,16)]
    end
    -- local sid=table.concat(tb)
    return string.format('%s-%s-%s-%s-%s',
        string.sub(sid,1,8),
        string.sub(sid,9,12),
        string.sub(sid,13,16),
        string.sub(sid,17,20),
        string.sub(sid,21,32)
    )
end
Util.enableLog = false

return TdSDK
