--Demo
local TdSDK = require "ThinkingDataSdk"
local APP_ID = "appId"
local PUSH_URL = "serverUrl"


--初始化
-- local consumer = TdSDK.BatchConsumer(PUSH_URL, APP_ID)  --批量收集器

-- 支持在TA后台 debug 模式实时查看数据
-- local consumer = TdSDK.DebugConsumer(PUSH_URL, APP_ID, false, "DeviceId")    --调试收集器

-- 通过接口验证数据的正确性
-- local consumer = TdSDK.DebugConsumer(PUSH_URL, APP_ID, false)    --调试收集器

local consumer = TdSDK.LogConsumer("./", TdSDK.LOG_RULE.HOUR, 20, 20) --本地文件收集器
local sdk = TdSDK(consumer, false,true)

local distinctId = "1234567890987654321"
local accountId = nil

--动态公共属性
ChildTracker = class(TdSDK.TADynamicSuperPropertiesTracker)
function ChildTracker:getProperties()
	properties = {}
	properties["DynamicKey"] = "DynamicValue"
	return properties
end

sdk:setDynamicSuperProperties(ChildTracker)


--设置公共属性
local superProperties = {}
superProperties["sex"] = "male" --性别
superProperties["age"] = 23 --年龄
TdSDK:setSuperProperties(superProperties)
superProperties = nil

--浏览商品
local properties = {}
-- properties["productNames"] = { "Lua入门", "Lua从精通到放弃" }
-- properties["productType"] = "Lua书籍"
-- properties["producePrice"] = 80
-- properties["shop"] = "xx网上书城"
-- properties["#os"] = "1.1.1.1"
-- properties["date"] = os.date()
-- properties["date1"] = os.date("%Y-%m-%d %H:%M:%S")
-- properties["sex"] = 'female';
sdk:track(accountId, distinctId, "current_online", properties)
properties = nil


-- 用户信息设置
local profiles = {}
profiles["#city"] = "北京"        --城市
profiles["#province"] = "北京"  --省份
profiles["nickName"] = "昵称123"--昵称
profiles["userLevel"] = 0        --用户级别
profiles["userPoint"] = 0        --用户积分
profiles["#os"] = "1.2.3"
local interestList = { "户外活动", "足球赛事", "游戏" }
profiles["interest"] = interestList --用户兴趣爱好
sdk:userSet(accountId, distinctId, profiles)
profiles = nil

-- --用户注册时间
-- local profile_age = {}
-- profile_age["registerTime"] = "20180101101010"
-- sdk:userSetOnce(accountId, distinctId, profile_age)
-- profile_age = nil

-- profiles = {}
-- profiles["userPoint"] = 100
-- sdk:userAdd(accountId, distinctId, profiles)
-- profiles = nil

-- local profiles_append = {}
-- profiles_append["append"] = "test_append"
-- sdk:userAppend(accountId, distinctId, profiles_append)

-- --重新设置公共属性
-- sdk:clearSuperProperties()
-- superProperties = {}
-- superProperties["userLevel"] = 0 --用户级别
-- superProperties["userPoint"] = 0 --用户积分
-- sdk:setSuperProperties(superProperties)

-- --再次浏览商品
-- properties = {}
-- properties["productName"] = { "Thinking in Lua" }   --商品列表
-- properties["productType"] = "Lua书籍" --商品类别
-- properties["producePrice"] = 80            --商品价格
-- properties["shop"] = "xx网上书城"      --店铺名称
-- sdk:track(accountId, distinctId, "ViewProduct", properties)

-- --订单信息
-- properties = {}
-- properties["orderId"] = "ORDER_12345"
-- properties["price"] = 80
-- sdk:track(accountId, distinctId, "Order", properties)

-- --支付信息
-- properties = {}
-- properties["orderId"] = "ORDER_12345"
-- properties["productName"] = "Thinking in Lua"
-- properties["productType"] = "Lua书籍"
-- properties["producePrice"] = 80
-- properties["shop"] = "xx网上书城"
-- properties["productNumber"] = 1
-- properties["price"] = 80
-- properties["paymentMethod"] = "AliPay"
-- sdk:track(accountId, distinctId, "Payment", properties)

-- --user_uniq_append追加属性
-- local profiles_uniq_append = {}
-- profiles_uniq_append["append"] = {"test_append", "test_append1"}
-- sdk:userUniqueAppend(accountId, distinctId, profiles_uniq_append)

-- --首次事件
-- properties = {}
-- properties["firstKey"] = "firstValue"
-- sdk:trackFirst(accountId, distinctId, "first_event_test", "test_first_check_id", properties)

sdk:flush()