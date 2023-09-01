-- LuaSDK
local socket = require("socket")
local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local cjson = require("cjson")
local Util = {}

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
        Util.log("[Error]", "distinctId, accountId can't both be empty")
    end
    if (Util.startWith(eventType, "track") and (eventName == nil or string.len(eventName) == 0)) then
        Util.log("[Error]", "eventName can't be empty when the type is track or track_update or track_overwrite")
    end
    if (Util.startWith(eventType, "track_")  and (eventId == nil or string.len(eventId) == 0)) then
        Util.log("[Error]", "eventId can't be empty when the type is track_update or track_overwrite")
    end
    checkKV(properties, eventName)
end

--- uoload data
---@param consumer any
---@param distinctId any
---@param accountId any
---@param eventType any
---@param eventName any
---@param eventId any
---@param properties any
---@param superProperties any
---@param dynamicSuperPropertiesTracker any
---@param checkKeyAndValue any
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

--- Construct SDK
---@param self any
---@param consumer any logConsuemr/batchConsumer/debugConsumer
---@param strictMode boolean enable properties check
---@param enableLog boolean enable log
TdSDK = class(function(self, consumer, strictMode, enableLog)
    Util.enableLog = enableLog
    if consumer == nil or type(consumer) ~= "table" then
        Util.log("[Error]", "consumer params is invalidate.")
        return
    end
    self.consumer = consumer
    self.checkKeyAndValue = strictMode or TdSDK.strictMode
    self.superProperties = {}
    self.dynamicSuperPropertiesTracker = nil
end)

--- Construct debug consumer
---@param self any
---@param url string project url
---@param appid string project app id
---@param debugOnly boolean false: write data. true: No write data
---@param deviceId string debug deviceId
TdSDK.DebugConsumer = class(function(self, url, appid, debugOnly, deviceId)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        print("[ThinkingData][Error]" .. "appid can't be empty.")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        print("[ThinkingData][Error]" .. "server url can't be empty.")
    end
    self.url = (url or "") .. "/data_debug"
    self.appid = appid
    self.debugOnly = debugOnly
    self.deviceId = deviceId
    TdSDK.strictMode = true
end)

function TdSDK.DebugConsumer:add(msg)
    local returnCode, code = Util.post(self.url, self.appid, msg, true, self.debugOnly, self.deviceId)
    Util.log("Info: ", "send to: " .. self.url .. " return Code:[" .. (code or "") .. "]\nBody: " .. Util.toJson(msg) .. "\nreturn: " .. (returnCode or ""))
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

--- Construct BatchConsumer
---@param self any
---@param url any
---@param appid any
---@param batchNum any
---@param cacheCapacity any
TdSDK.BatchConsumer = class(function(self, url, appid, batchNum, cacheCapacity)
    if appid == nil or type(appid) ~= "string" or string.len(appid) == 0 then
        print("[ThinkingData][Error]" .. "appid can't be empty")
    end
    if url == nil or type(url) ~= "string" or string.len(url) == 0 then
        print("[ThinkingData][Error]" .. "server url can't be empty")
    end
    if batchNum ~= nil and type(batchNum) ~= "number" then
        print("[ThinkingData][Error]" .. "must be nummber type")
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
    else
        Util.log("info: ", "add event to buffer")
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
        -- retry 3 times
        local number = 3
        local success = false
        local returnCode
        local code
        while number > 0 and success == false do
            returnCode, code = Util.post(self.url, self.appid, events)
            Util.log("Info: ", "sent to: " .. self.url .. " Code:[" .. (code or "") .. "]\nBody: " .. Util.toJson(events) .. "\nreturn: " .. (returnCode or ""))
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
function TdSDK.BatchConsumer:close()
    return self:flush(true)
end
function TdSDK.BatchConsumer:toString()
    return "\n--Consumer: BatchConsumer" ..
            "\n--Consumer.Url: " .. self.url ..
            "\n--Consumer.Appid: " .. self.appid ..
            "\n--Consumer.BatchNum: " .. self.batchNum
end

--- Construct logConsumer
---@param self any
---@param logPath any
---@param rule any
---@param batchNum any
---@param fileSize any
---@param fileNamePrefix any
TdSDK.LogConsumer = class(function(self, logPath, rule, batchNum, fileSize, fileNamePrefix)
    if logPath == nil or type(logPath) ~= "string" or string.len(logPath) == 0 then
        print("[ThinkingData][Error]" .. "directory can't be empty.")
    end
    if rule ~= nil and type(rule) ~= "string" then
        print("[ThinkingData][Error]" .. "file name is invalidate.")
    end

    if batchNum ~= nil and type(batchNum) ~= "number" then
        print("[ThinkingData][Error]" .. "data is must be Number type.")
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
end)

-- retain file handler
TdSDK.LogConsumer.fileHandler = nil

function TdSDK.LogConsumer:add(msg)
    local num = #self.eventArrayJson + 1
    self.eventArrayJson[num] = msg
    if (num >= self.batchNum) then
        self:flush()
    else
        Util.log("info: ", "add event to buffer")
    end
    return num
end
function TdSDK.LogConsumer:flush()
    if #self.eventArrayJson == 0 then
        return true
    end
    Util.log("info: ", "flush data, count: ", #self.eventArrayJson)
    local isFileNameChange = false
    if self.rule == TdSDK.LOG_RULE.HOUR then
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

    local result = self.fileHandler:write(data)
    if (result) then
        self.eventArrayJson = {}
    else
        Util.log("[Error]", "data write failed. count: ", #self.eventArrayJson)
    end

    self.fileHandler:flush()
    self.fileHandler:seek("end", 0)      

    return true
end
function TdSDK.LogConsumer:close()
    self:flush()
    -- close old file handler
    if self.fileHandler then
        self.fileHandler:close()
    end
end
function TdSDK.LogConsumer:toString()
    return "\n--Consumer: LogConsumer" ..
            "\n--Consumer.LogPath: " .. self.logPath ..
            "\n--Consumer.Rule: " .. self.rule ..
            "\n--Consumer.BatchNum: " .. self.batchNum
end

--- set dynamic common properties
---@param callback any
function TdSDK:setDynamicSuperProperties(callback)
    if callback ~= nil then
        self.dynamicSuperPropertiesTracker = callback
    end
end

--- set common properties
---@param params any
function TdSDK:setSuperProperties(params)
    if self.checkKeyAndValue == true then
        local ok, ret = pcall(checkKV, params)
        if not ok then
            Util.log("[Error]", "common properties error: ", ret)
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

--- remove common properties with key
---@param key any
function TdSDK:removeSuperProperty(key)
    if key == nil then
        return nil
    end
    self.superProperties[key] = nil
end

--- find common properties with key
---@param key any
function TdSDK:getSuperProperty(key)
    if key == nil then
        return nil
    end
    return self.superProperties[key]
end

--- get all properties
function TdSDK:getSuperProperties()
    return self.superProperties
end

--- clear common properties
function TdSDK:clearSuperProperties()
    self.superProperties = {}
end

--- set user properties. would overwrite existing names
---@param accountId any
---@param distinctId any
---@param properties any
function TdSDK:userSet(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_set", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userSet: success")
        return ret
    else
        Util.log("Error: ", "userSet failed: ", ret)
    end
end

--- set user properties, If such property had been set before, this message would be neglected.
---@param accountId any
---@param distinctId any
---@param properties any
function TdSDK:userSetOnce(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_setOnce", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userSetOnce: success")
        return ret
    else
        Util.log("Error: ", "userSetOnce failed: ", ret)
    end
end

--- to accumulate operations against the property
---@param accountId any
---@param distinctId any
---@param properties any
function TdSDK:userAdd(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_add", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userAdd: success")
        return ret
    else
        Util.log("Error: ", "userAdd failed: ", ret)
    end
end

--- to add user properties of array type
---@param accountId any
---@param distinctId any
---@param properties any
function TdSDK:userAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userAppend: success")
        return ret
    else
        Util.log("Error: ", "userAppend failed: ", ret)
    end
end

--- append user properties to array type by unique.
---@param accountId any
---@param distinctId any
---@param properties any
function TdSDK:userUniqueAppend(accountId, distinctId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_uniq_append", nil, nil, properties, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userUniqueAppend: success")
        return ret
    else
        Util.log("Error: ", "userUniqueAppend failed: ", ret)
    end
end

--- clear the user properties of users
---@param accountId any
---@param distinctId any
---@param properties any
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
        Util.log("Info: ", "userUnSet: success")
        return ret
    else
        Util.log("Error: ", "userUnSet failed: ", ret)
    end
end

--- delete a user, This operation cannot be undone
---@param accountId any
---@param distinctId any
function TdSDK:userDel(accountId, distinctId)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "user_del", nil, nil, {}, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "userDelete: success")
        return ret
    else
        Util.log("Error: ", "userDelete failed: ", ret)
    end
end

--- report ordinary event
---@param accountId any
---@param distinctId any
---@param eventName any
---@param properties any
function TdSDK:track(accountId, distinctId, eventName, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track", eventName, "", properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        return ret
    else
        Util.log("[Error]", "track failed: ", ret)
    end
end

--- report first event.
---@param accountId any
---@param distinctId any
---@param eventName any
---@param firstCheckId string it is flag of the first event
---@param properties any
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
        Util.log("Info: ", "trackFirst: success")
        return ret
    else
        Util.log("Error: ", "trackFirst failed: ", ret)
    end
end

--- updatable event.
---@param accountId any
---@param distinctId any
---@param eventName any
---@param eventId any
---@param properties any
function TdSDK:trackUpdate(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_update", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "track_update: success")
        return ret
    else
        Util.log("Error: ", "track_update failed: ", ret)
    end
end

--- report overridable event.
---@param accountId any
---@param distinctId any
---@param eventName any
---@param eventId any
---@param properties any
function TdSDK:trackOverwrite(accountId, distinctId, eventName, eventId, properties)
    local ok, ret = pcall(upload, self.consumer, distinctId, accountId, "track_overwrite", eventName, eventId, properties, self.superProperties, self.dynamicSuperPropertiesTracker, self.checkKeyAndValue)
    if ok then
        Util.log("Info: ", "track_overwrite: success")
        return ret
    else
        Util.log("Error: ", "track_overwrite failed: ", ret)
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
TdSDK.version = "1.5.4"
TdSDK.batchNumber = 20
TdSDK.strictMode = false
TdSDK.cacheCapacity = 50
TdSDK.logModePath = "."

TdSDK.LOG_RULE = {}
TdSDK.LOG_RULE.HOUR = "%Y-%m-%d-%H"
TdSDK.LOG_RULE.DAY = "%Y-%m-%d"

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
                ["TA-Integration-Type"] = TdSDK.platForm;
                ["TA-Integration-Version"] = TdSDK.version;
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
            print("[ThinkingData] url format is wrong.")
            return
        end

        res = table.concat(response_body)
        if code ~= nil and type(code) == "number" and tonumber(code) == 200 then
            break
        end
        print("[ThinkingData] [url]: ".. url .. " [info]: " .. (code or ""))
        print("[ThinkingData] [request]: " .. request_body .. " [response]: " .. (res or ""))
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
            print("[ThinkingData] Error: Up failed, result: " .. res)
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
            print("[ThinkingData] Error:up failed:" .. resultCode .. ", msg:" .. msg)
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
-- log 
function Util.log(level, key, msg)
    if Util.enableLog then
        print("[ThinkingData]" .. level .. (key or "") .. (msg or ""))
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

return TdSDK
