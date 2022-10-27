require("busted")
local TdSDK = require "ThinkingDataSdk"

local APP_ID = "cb1b413747ac4a2386c62a2575ac7746"
local PUSH_URL = "http://receiver-ta-demo.thinkingdata.cn"
local socket = require("socket")
local ltn12 = require("ltn12")
local cjson = require("cjson")
local http=require("socket.http");

describe("LoggerConsumer Test #Log", function()
  consumer = TdSDK.LogConsumer("./", TdSDK.LOG_RULE.HOUR, 20, 20) --本地文件收集器
  sdk = TdSDK(consumer, false, false)
  distinctId = "1234567890987654321"
  accountId = 'Test'
  properties = {}
  properties["productNames"] = { "Lua入门", "Lua从精通到放弃" } 
  properties["productType"] = "Lua书籍"
  properties["producePrice"] = 80
  properties["shop"] = "xx网上书城"
  properties["date"] = os.date()
  properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
  dic = {}
  dic['key'] = 'value'
  properties['dic']=dic
  properties['arr']={dic}
  sdk:track(accountId, distinctId, "ViewProduct", properties)
  sdk:flush()
end)


-- describe("DebugConsumer Test #Debug", function()
--   consumer = TdSDK.DebugConsumer(PUSH_URL, APP_ID) 
--   sdk = TdSDK(consumer, false, true)
--   distinctId = "1234567890987654321"
--   accountId = 'Test'
--   properties = {}
--   properties["productNames"] = { "Lua入门", "Lua从精通到放弃" }
--   properties["productType"] = "Lua书籍"
--   properties["producePrice"] = 80
--   properties["shop"] = "xx网上书城"
--   properties["date"] = os.date()
--   properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
--   dic = {}
--   dic['key'] = 'value'
--   properties['dic']=dic
--   properties['arr']={dic}
--   sdk:track(accountId, distinctId, "ViewProduct", properties)
--   sdk:flush()
-- end)


-- describe("BatchConsumer Test #Batch", function()
--   consumer = TdSDK.BatchConsumer(PUSH_URL, APP_ID) 
--   sdk = TdSDK(consumer, false, false)
--   distinctId = "1234567890987654321"
--   accountId = 'Test'
--   properties = {}
--   properties["productNames"] = { "Lua入门", "Lua从精通到放弃" }
--   properties["productType"] = "Lua书籍"
--   properties["producePrice"] = 80
--   properties["shop"] = "xx网上书城"
--   properties["date"] = os.date()
--   properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
--   dic = {}
--   dic['key'] = 'value'
--   properties['dic']=dic
--   properties['arr']={dic}
--   sdk:track(accountId, distinctId, "ViewProduct", properties)
--   sdk:flush()
-- end)
