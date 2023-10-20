-- LuaSDK
local socket = require("socket")
local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local cjson = require("cjson")
local Util = {}
local TDLog = {}

local function class(base, _ctor)
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

local function startWith(str, substr)
    if str == nil or substr == nil then
        return nil, "the string or the sub-stirng parameter is nil"
    end
    if string.find(str, substr) ~= 1 then
        return false
    else
        return true
    end
end

local function fileExists(path)
    local retTable = { os.execute("cd " .. path) }
    local code = retTable[3] or retTable[1]
    return code == 0
end

local function isWindows()
    local separator = package.config:sub(1, 1)
    local osName = os.getenv("OS")
    local result = (separator == '\\' or (osName ~= nil and startWith(string.lower(osName), "windows")))
    return result
end

local function urlEncode(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(s, " ", "+")
end

local function checkKV(properties, eventName)
    -- check K/V
    local userAdd = "user_add"
    local userUnset = "user_unset"
    for key, value in pairs(properties) do
        if (string.len(key) == 0) then
            TDLog.error("The property key is empty")
        end
        if (type(value) ~= "string" and
                type(value) ~= "number" and
                type(value) ~= "boolean" and
                type(value) ~= "table") then
            TDLog.error("The property " .. key .. " is not number, string, boolean, table.")
        end
        if (type(value) == "table") then
            for k, v in pairs(value) do
                if (type(v) ~= "string" and type(v) ~= "number" and type(v) ~= "boolean" and type(v) ~= "table") then
                    TDLog.error("The table property " .. k .. " is not number, string, boolean, table.")
                end
            end
        end
        if (type(value) == "string" and string.len(value) == 0 and not (userUnset == eventName)) then
            TDLog.error("The property " .. key .. " string value is null or empty")
        end

        if (userAdd == eventName and type(value) ~= "number") then
            TDLog.error("The property value of " .. key .. " should be a number ")
        end
    end
end

local function divide(properties)
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

local function check(distinctId, accountId, eventType, eventName, eventId, properties, dynamicSuperProperties, checkKeyAndValue)
    if checkKeyAndValue == nil or checkKeyAndValue == false then
        return
    end
    assert(distinctId == nil or type(distinctId) == "string" or type(distinctId) == "number", "distinctId must be string or number type")
    assert(accountId == nil or type(accountId) == "string" or type(accountId) == "number", "accountId must be string or number type")
    assert(type(eventType) == "string", "type must be string type")
    assert(eventName == nil or type(eventName) == "string", "eventName must be string type")
    assert(type(properties) == "table", "properties must be Table type")
    if dynamicSuperProperties ~= nil then
        assert(type(dynamicSuperProperties) == "table", "dynamicSuperProperties must be Table type")
        checkKV(dynamicSuperProperties, eventName)
    end
    -- check name
    if ((distinctId == nil or string.len(distinctId) == 0) and (accountId == nil or string.len(accountId) == 0)) then
        TDLog.error("distinctId, accountId can't both be empty")
    end
    if (Util.startWith(eventType, "track") and (eventName == nil or string.len(eventName) == 0)) then
        TDLog.error("eventName can't be empty when the type is track or track_update or track_overwrite")
    end
    if (Util.startWith(eventType, "track_")  and (eventId == nil or string.len(eventId) == 0)) then
        TDLog.error("eventId can't be empty when the type is track_update or track_overwrite")
    end
    checkKV(properties, eventName)
end

---
---@param consumer any
---@param distinctId string
---@param accountId string
---@param eventType string
---@param eventName string
---@param eventId string
---@param properties table
---@param superProperties table
---@param dynamicSuperPropertiesTracker function
---@param checkKeyAndValue boolean
local function upload(consumer, distinctId, accountId, eventType, eventName, eventId, properties, superProperties, dynamicSuperPropertiesTracker, checkKeyAndValue)
    local finalProperties, presetProperties = divide(properties)
    local dynamicSuperProperties = {}
    if dynamicSuperPropertiesTracker ~= nil and type(dynamicSuperPropertiesTracker) == "function" then
        dynamicSuperProperties = dynamicSuperPropertiesTracker()
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
    -- preset properties
    for key, value in pairs(presetProperties) do
        eventJson[key] = value
    end
    if presetProperties["#time"] == nil then
        local millTime = socket.gettime()
        local prefixStr = os.date("%Y-%m-%d %H:%M:%S", math.floor(millTime))
        local millStr = string.sub(string.format("%.3f", millTime%1), 2)
        eventJson["#time"] = prefixStr .. millStr
    end
    local mergeProperties = {}
    if eventType == "track" or eventType == "track_update" or eventType == "track_overwrite" then
        mergeProperties = Util.mergeTables(mergeProperties, superProperties)
        mergeProperties = Util.mergeTables(mergeProperties, dynamicSuperProperties)
        mergeProperties["#lib"] = TDAnalytics.platForm
        mergeProperties["#lib_version"] = TDAnalytics.version
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

--- 
--- Init analytics instance
---@param self any
---@param consumer any logConsuemr/batchConsumer/debugConsumer
---@param strictMode boolean enable properties check
---@param enableLog boolean deprecated. please use TDAnalytics.enableLog(enable)
TDAnalytics = class(function(self, consumer, strictMode, enableLog)
    if consumer == nil or type(consumer) ~= "table" then
        TDLog.error("consumer params is invalidate.")
        return
    end
    self.consumer = consumer
    self.checkKeyAndValue = strictMode or TDAnalytics.strictMode
    self.superProperties = {}
    self.dynamicSuperPropertiesTracker = nil
    TDLog.info("SDK init success")
end)

--- Enable log or not
---@param enable boolean
function TDAnalytics.enableLog(enable)
    TDLog.enable = enable
end

--- Construct debug consumer
---@param self any
---@param url string Project url
---@param appid string Project app id
---@param debugOnly boolean false: write data. true: No write data
---@param deviceId string Debug deviceId
TDAnalytics.TDDebugConsumer = class(function(self, url, appid, debugOnly, deviceId)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        TDLog.error("appid can't be empty.")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        TDLog.error("server url can't be empty.")
    end
    self.url = (url or "") .. "/data_debug"
    self.appid = appid
    self.debugOnly = debugOnly
    self.deviceId = deviceId
    TDAnalytics.strictMode = true
    TDLog.info("Mode: debug consumer. AppId: " .. appid .. ". ReceiverUrl: " .. url)
end)

function TDAnalytics.TDDebugConsumer:add(msg)
    local returnCode, code = Util.post(self.url, self.appid, msg, true, self.debugOnly, self.deviceId)
    if (returnCode == 0) then
        return true
    end
    return false
end
function TDAnalytics.TDDebugConsumer:flush()
end
function TDAnalytics.TDDebugConsumer:close()
    TDLog.info("Close debug consumer")
end

--- Construct batch consumer
---@param self any
---@param url string
---@param appid string
---@param batchNum number
---@param cacheCapacity number
TDAnalytics.TDBatchConsumer = class(function(self, url, appid, batchNum, cacheCapacity)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        TDLog.error("appid can't be empty")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        TDLog.error("url can't be empty")
    end
    if batchNum ~= nil and type(batchNum) ~= "number" then
        TDLog.error("batchNum must be nummber type")
    end
    self.url = url .. "/sync_server"
    self.appid = appid
    self.batchNum = batchNum or TDAnalytics.batchNumber
    self.eventArrayJson = {}
    self.cacheCapacity = cacheCapacity or TDAnalytics.cacheCapacity
    self.cacheTable = {}
    TDLog.info("Mode: batch consumer. AppId: " .. appid .. ". ReceiverUrl: " .. url)
end)
function TDAnalytics.TDBatchConsumer:add(msg)
    local num = #self.eventArrayJson + 1
    self.eventArrayJson[num] = msg
    TDLog.info("Enqueue data to buffer. data =" .. msg)
    if (num >= self.batchNum or #self.cacheTable > 0) then
        return self:flush()
    end
    return true
end
function TDAnalytics.TDBatchConsumer:flush(flag)
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
        -- retry 3 times
        local number = 3
        local success = false
        local returnCode
        local code
        while number > 0 and success == false do
            returnCode, code = Util.post(self.url, self.appid, events)
            if (code == 200) then
                success = true
            else
                success = false
                number = number - 1
            end
        end

        if (success) then
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
function TDAnalytics.TDBatchConsumer:close()
    self:flush(true)
    TDLog.info("Close batch consumer")
end

--- Construct logConsumer
---@param self any
---@param logPath string
---@param rule string
---@param batchNum number
---@param fileSize number
---@param fileNamePrefix string
TDAnalytics.TDLogConsumer = class(function(self, logPath, rule, batchNum, fileSize, fileNamePrefix)
    if logPath == nil or type(logPath) ~= "string" or string.len(logPath) == 0 then
        TDLog.error("logPath can't be empty.")
    end
    if rule ~= nil and type(rule) ~= "string" then
        TDLog.error("rule is invalidate.")
    end

    if batchNum ~= nil and type(batchNum) ~= "number" then
        TDLog.error("batchNum is must be Number type.")
    end
    self.rule = rule or TDAnalytics.LOG_RULE.DAY
    self.logPath = Util.mkdirFolder(logPath)
    self.fileNamePrefix = fileNamePrefix
    self.fileSize = fileSize
    self.count = 0;
    self.file = nil;
    self.batchNum = batchNum or TDAnalytics.batchNumber
    self.currentFileTime = os.date("%Y-%m-%d %H")
    self.fileName = Util.getFileName(logPath, fileNamePrefix, self.rule)
    self.eventArrayJson = {}
    TDLog.info("Mode: log consumer. File path: " .. logPath)
end)

-- Retain file handler
TDAnalytics.TDLogConsumer.fileHandler = nil

function TDAnalytics.TDLogConsumer:add(msg)
    local num = #self.eventArrayJson + 1
    self.eventArrayJson[num] = msg

    TDLog.info("Enqueue data to buffer")

    if (num >= self.batchNum) then
        self:flush()
    end
    return num
end

function TDAnalytics.TDLogConsumer:flush()
    if #self.eventArrayJson == 0 then
        return true
    end
    local isFileNameChange = false
    if self.rule == TDAnalytics.LOG_RULE.HOUR then
        isFileNameChange = Util.getDateFromDateTime(self.currentFileTime) ~= os.date("%Y-%m-%d")
                or Util.getHourFromDate(self.currentFileTime) ~= Util.getCurrentHour()
    else
        isFileNameChange = Util.getDateFromDateTime(self.currentFileTime) ~= os.date("%Y-%m-%d")
    end

    if isFileNameChange or self.fileHandler == nil then
        self.currentFileTime = os.date("%Y-%m-%d %H:%M:%S")
        self.fileName = Util.getFileName(self.logPath, self.fileNamePrefix, self.rule)
        self.count = 0
        -- close old file handler and create new file handler
        if self.fileHandler then
            self.fileHandler:close()
        end
        local logFileName = self.fileName .. "_" .. self.count
        self.fileHandler = assert(io.open(logFileName, "a"))
    else
        if self.fileSize > 0 then
            self.count, self.fileHandler = Util.getFileHandlerAndCount(self.fileHandler, self.fileName, self.fileSize, self.count)
        end
    end

    local data = ""
    for key, value in pairs(self.eventArrayJson) do
        local json = Util.toJson(value)
        data = data .. json .. "\n"
    end

    TDLog.info("Flush data, count: [" .. #self.eventArrayJson .. "]\n" .. data)

    local result = self.fileHandler:write(data)
    if (result) then
        self.eventArrayJson = {}
    else
        TDLog.error("data write failed. count: ", #self.eventArrayJson)
    end

    self.fileHandler:flush()
    self.fileHandler:seek("end", 0)      

    return true
end

function TDAnalytics.TDLogConsumer:close()
    self:flush()
    -- close old file handler
    if self.fileHandler then
        self.fileHandler:close()
    end
    TDLog.info("Close log consumer")
end

--- Set dynamic common properties
---@param callback function
function TDAnalytics:setDynamicSuperProperties(callback)
    if callback ~= nil then
        self.dynamicSuperPropertiesTracker = callback
    end
end

--- Set common properties
---@param params table
function TDAnalytics:setSuperProperties(params)
    if self.checkKeyAndValue == true then
        local ok, ret = pcall(checkKV, params)
        if not ok then
            TDLog.error("common properties error: ", ret)
            return
        end
    end

    if (type(params) == "table") then
        self.superProperties = Util.mergeTables(self.superProperties, params)
    end
end

--- Set common property
---@param key string
---@param value any
function TDAnalytics:setSuperProperty(key, value)
    if (key ~= nil) then
        local params = {}
        params[key] = value
        TDLog.info(params[key])
        self:setSuperProperties(params)
    end
end

--- Remove common properties with key
---@param key any
function TDAnalytics:removeSuperProperty(key)
    if key == nil then
        return nil
    end
    self.superProperties[key] = nil
end

--- Find common properties with key
---@param key string
function TDAnalytics:getSuperProperty(key)
    if key == nil then
        return nil
    end
    return self.superProperties[key]
end

--- Get all properties
---@return table
function TDAnalytics:getSuperProperties()
    return self.superProperties
end

--- Clear common properties
function TDAnalytics:clearSuperProperties()
    self.superProperties = {}
end

--- Set user properties. Would overwrite existing names
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userSet(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_set", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Set user properties, if such property had been set before, this message would be neglected.
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userSetOnce(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_setOnce", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- To accumulate operations against the property
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userAdd(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_add", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- To add user properties of array type
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Append user properties to array type by unique.
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userUniqueAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_uniq_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Clear the user properties of users
---@param accountId string
---@param distinctId string
---@param properties table
function TDAnalytics:userUnset(accountId, distinctId, properties)
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
        return ret
    end
end

--- Delete a user, This operation cannot be undone
---@param accountId string
---@param distinctId string
function TDAnalytics:userDel(accountId, distinctId)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_del", nil, nil, {}, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Report ordinary event
---@param accountId string
---@param distinctId string
---@param eventName string
---@param properties table
function TDAnalytics:track(accountId, distinctId, eventName, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track", eventName, "", properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Report first event.
---@param accountId string
---@param distinctId string
---@param eventName string
---@param firstCheckId string It is flag of the first event
---@param properties table
function TDAnalytics:trackFirst(accountId, distinctId, eventName, firstCheckId, properties)
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
        return ret
    end
end

--- Updatable event.
---@param accountId string
---@param distinctId string
---@param eventName string
---@param eventId string
---@param properties table
function TDAnalytics:trackUpdate(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_update", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Report overridable event.
---@param accountId string
---@param distinctId string
---@param eventName string
---@param eventId string
---@param properties table
function TDAnalytics:trackOverwrite(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_overwrite", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        return ret
    end
end

--- Flush data
function TDAnalytics:flush()
    self.consumer:flush()
end

--- Close SDK
function TDAnalytics:close()
    self.consumer:close()
    TDLog.info("SDK closed.")
end

function TDAnalytics:toString()
    return self.consumer:toString()
end

TDAnalytics.platForm = "Lua"
TDAnalytics.version = "2.0.0-beta.1"
TDAnalytics.batchNumber = 20
TDAnalytics.strictMode = false
TDAnalytics.cacheCapacity = 50
TDAnalytics.logModePath = "."

--- Log file rotate type
TDAnalytics.LOG_RULE = {}
--- Log file rotate type: By hour
TDAnalytics.LOG_RULE.HOUR = "%Y-%m-%d-%H"
--- Log file rotate type: By Day
TDAnalytics.LOG_RULE.DAY = "%Y-%m-%d"

function Util.post(url, appid, eventArrayJson, isDebug, debugOnly, deviceId)
    if not isDebug and #eventArrayJson == 0 then
        return "", ""
    end
    local request_body = Util.toJson(eventArrayJson)
    local contentType = "application/json"
    if isDebug then
        local dryRun = 0
        if debugOnly then
            dryRun = 1
        end
        request_body = urlEncode(request_body)
        request_body = "data=" .. request_body .. "&source=server&appid=" .. (appid or "") .. "&dryRun=" .. dryRun
        if deviceId then
           request_body = request_body .. "&deviceId=" .. deviceId 
        end
        contentType = "application/x-www-form-urlencoded"
    end

    TDLog.info("Send data, request = " .. request_body)

    local response_body = {}
    local count = 0
    local res, code
    while (count < 3)
    do
        local params = {
            url = url,
            method = "POST",
            headers = {
                ["appid"] = appid;
                ["TA-Integration-Type"] = TDAnalytics.platForm;
                ["TA-Integration-Version"] = TDAnalytics.version;
                ["TA-Integration-Count"] = #eventArrayJson;
                ["Content-Type"] = contentType;
                ["Content-Length"] = #request_body;
            },
            ssl_params = {
                verify = "none"
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
        }

        local httpLen = string.len("http")
        local httpsLen = string.len("https")
        if url ~= nil and string.len(url) >= httpsLen and string.sub(url, 1, httpsLen) == "https" then
            res, code = https.request(params)
        elseif url ~= nil and string.len(url) >= httpLen and string.sub(url, 1, httpLen) == "http" then
            res, code = http.request(params)
        else
            TDLog.error("url format is wrong.")
            return
        end        
        res = table.concat(response_body)
        TDLog.info("Send data, response = " .. (res or ""))
        if code ~= nil and type(code) == "number" and tonumber(code) == 200 then
            break
        end
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
            TDLog.error("Up failed, result: " .. res)
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
            TDLog.error("Up failed:" .. resultCode .. ", msg:" .. msg)
        end
    end

    return resultCode, code
end

function Util.toJson(eventArrayJson)
    return cjson.encode(eventArrayJson)
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

function Util.writeFile(fileName, eventArrayJson)
    if #eventArrayJson == 0 then
        return false
    end
    if Util.fileHandler == nil then
        Util.fileHandler = assert(io.open(fileName, 'a'))
    end
    local file = Util.fileHandler
    -- local file = assert(io.open(fileName, 'a'))
    local data = ""
    for i = 1, #eventArrayJson do
        local json = Util.toJson(eventArrayJson[i])
        data = data .. json .. "\n"
    end
    file:write(data)
    -- file:close()
    -- file = nil
    return true
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

--- func desc
---@param currentFile file*
---@param fileName string
---@param fileSize number
---@param count number
---@return number file count
---@return file* effective handler
function Util.getFileHandlerAndCount(currentFile, fileName, fileSize, count)
    if not count then
        count = 0
    end

    local finalFileName = nil
    local file = currentFile

    while file
    do
        local len = assert(file:seek("end"))
        if len < (fileSize * 1024 * 1024) then
            -- get effective file handler
            break
        else
            count = count + 1
            finalFileName = fileName .. "_" .. count
            -- close old file
            file:close()
            -- create new file
            file = assert(io.open(finalFileName, "a"))
        end
    end
    return count, file
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
    local uuidLib = require("uuid")
    return uuidLib()
end

function Util.getHourFromDate(dateString)
    return string.sub(dateString, 12, 13)
end

function Util.getDateFromDateTime(dateTime)
    return string.sub(dateTime, 1, 10)
end
function Util.getCurrentHour()
    local t = os.date("%Y-%m-%d %H:%M:%S")
    if type(t) == "string" then
        return string.sub(t, 12, 13)
    end
end
Util.enableLog = false

TDLog.enable = false
function TDLog.info(...)
    if TDLog.enable then
        io.write("[ThinkingData][" .. os.date("%Y-%m-%d %H:%M:%S") .. "][Info] ")
        print(...)
    end
end

function TDLog.error(...)
    if TDLog.enable then
        io.write("[ThinkingData][" .. os.date("%Y-%m-%d %H:%M:%S") .. "][Error] ")
        print(...)
    end
end

return TDAnalytics
