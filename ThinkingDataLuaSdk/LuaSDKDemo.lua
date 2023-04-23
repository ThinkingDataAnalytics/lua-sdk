local TeSDK = require "ThinkingDataSdk"
local cjson = require("cjson")

local function getLogConsumer()
	return TeSDK.LogConsumer("H:/log", TeSDK.LOG_RULE.HOUR, 200, 500)
end

local function getDebugConsumer()
	return TeSDK.DebugConsumer("serverUrl", "appId", false, "123456789")
end

local function getBatchConsumer()
	return TeSDK.BatchConsumer("serverUrl", "appId")
end


local consumer = getLogConsumer()
-- local consumer = getDebugConsumer()
-- local consumer = getBatchConsumer()

--- init SDK with consumer
local sdk = TeSDK(consumer, false, false)

local distinctId = "1234567890987654321"
local accountId = nil

-- set dynamic super properties
sdk:setDynamicSuperProperties(function ()
    local properties = {}
	properties["DynamicKey"] = "DynamicValue"
	return properties
end)

-- set super properties
local superProperties = {}
superProperties["super_key_sex"] = "male"
superProperties["super_key_age"] = 23
sdk:setSuperProperties(superProperties)
superProperties = nil

local properties = {}
properties["productNames"] = { "Lua", "hello" }
properties["productType"] = "Lua book"
properties["producePrice"] = 80
properties["shop"] = "xx-shop"
properties["#os"] = "1.1.1.1"
properties["date"] = os.date()
properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
properties["sex"] = 'female';

sdk:track(accountId, distinctId, "eventName", properties)

sdk:clearSuperProperties()

sdk:track(accountId, distinctId, "eventName", properties)

-- properties = {}
-- properties["productNames"] = { "Lua", "hello" }
-- properties["productType"] = "Lua book"
-- properties["producePrice"] = 80
-- properties["shop"] = "xx-shop"
-- properties["#os"] = "1.1.1.1"
-- properties["date"] = os.date()
-- properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
-- properties["sex"] = 'female';
-- sdk:track(accountId, distinctId, "current_online", properties)

-- properties = {}
-- properties["userName"] = "hong"
-- properties["productType"] = "Lua book"
-- properties["producePrice"] = 80
-- properties["date"] = os.date()
-- properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
-- sdk:trackFirst(accountId, distinctId, "register", "first_check_id_1111", properties)

-- properties = {}
-- properties["userName"] = "hong"
-- properties["productType"] = "Lua book"
-- properties["producePrice"] = 80
-- properties["date"] = os.date()
-- properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
-- sdk:trackUpdate(accountId, distinctId, "register", "eventId_update", properties)

-- properties = {}
-- properties["userName"] = "hong_update"
-- sdk:trackUpdate(accountId, distinctId, "register", "eventId_update", properties)

-- properties = {}
-- properties["userName"] = "hong"
-- properties["productType"] = "Lua book"
-- properties["producePrice"] = 80
-- properties["date"] = os.date()
-- properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
-- sdk:trackOverwrite(accountId, distinctId, "register", "eventId_overwrite", properties)

-- properties = {}
-- properties["userName"] = "hong_overwrite"
-- sdk:trackOverwrite(accountId, distinctId, "register", "eventId_overwrite", properties)

-- local profiles = {}
-- profiles["#city"] = "beijing"       
-- profiles["#province"] = "beijing"
-- profiles["nickName"] = "nick name 123"
-- profiles["userLevel"] = 0
-- profiles["userPoint"] = 0
-- profiles["#os"] = "1.2.3"
-- local interestList = { "sport", "football", "game" }
-- profiles["interest"] = interestList
-- sdk:userSet(accountId, distinctId, profiles)
-- profiles = nil

-- local profiles = {}
-- profiles["setOnceKey"] = "setOnceValue"
-- sdk:userSetOnce(accountId, distinctId, profiles)

-- profiles["setOnceKey"] = "setTwice"
-- sdk:userSetOnce(accountId, distinctId, profiles)

-- profiles = {}
-- profiles["userPoint"] = 100
-- sdk:userAdd(accountId, distinctId, profiles)

-- profiles = {}
-- profiles["append"] = { "test_append" }
-- sdk:userAppend(accountId, distinctId, profiles)

-- profiles = {}
-- profiles["append"] = {"test_append", "test_append1"}
-- sdk:userUniqueAppend(accountId, distinctId, profiles)

sdk:flush()
sdk:close()