require("busted")
local TdSDK = require "ThinkingDataSdk"

local APP_ID = "1b1c1fef65e3482bad5c9d0e6a823356"
local PUSH_URL = "https://receiver.ta.thinkingdata.cn/"
local ta_msg = {}
MockConsumer = class(function(self)

end)

consumer = MockConsumer() 
sdk = TdSDK(consumer, false, true)
-- SDKTest = {cases={},verifies={}}
-- function SDKTest.addCase(_case)
--   table.insert(SDKTest['cases'], _case)
-- end
-- function SDKTest.addVerify(_verify)
--   table.insert(SDKTest.verifies, _verify)
-- end

-- function SDKTest.run()
--   print(#SDKTest.cases)
--   for i, _case in pairs(SDKTest.cases) do  
--     print (#_case)
--     -- result = _case();
--     --  for i, _verify in pairs(SDKTest.verifies) do
--     --     _verify(result)
--     --  end
--   end 
-- end
-- function SDKTest:reset()
--   SDKTest.cases = {};
--   SDKTest.verifies = {};
-- end
-- SDKTest.addCase('XXX')
-- SDKTest.addCase('YYY')

function MockConsumer:add(msg)
  -- print(Util.toJson(msg))
  ta_msg = msg
end
function MockConsumer:flush()
end
function MockConsumer:close()
end


function assertTrackCase(accountId,distinctId,eventName,properties)
   sdk:track(accountId, distinctId,eventName, properties)
   assert.are.equal(ta_msg["#type"],"track");
   assert.are.equal(ta_msg["#event_name"],"test");
   assertTrackProperties();
   assertSDKProperties();
   

   sdk:trackUpdate(accountId, distinctId,eventName,'user_id',properties)
   assert.are.equal(ta_msg["#type"],"track_update");
   assert.are.equal(ta_msg["#event_name"],"test");
   assertTrackProperties();
   assertSDKProperties();

   sdk:trackOverwrite(accountId, distinctId,eventName,'userid', properties)
   assert.are.equal(ta_msg["#type"],"track_overwrite");
   assert.are.equal(ta_msg["#event_name"],"test");
   assertTrackProperties();
   assertSDKProperties();

   sdk:trackFirst(accountId, distinctId,eventName,"userid",properties)
   assert.are.equal(ta_msg["#type"],"track");
   assert.are.equal(ta_msg["#event_name"],"test");
   assertTrackProperties();
   assertSDKProperties();
end

function assertTrackProperties()
   assertId();
   assert.are.same(ta_msg["properties"]["productNames"],{ "Lua入门"});
   assert.are.equal(ta_msg["properties"]["productType"],"Lua书籍");
   assert.are.equal(ta_msg["properties"]["producePrice"],80);
   assert.are.equal(ta_msg["properties"]["shop"],"网上书城");
   assert.are.same(ta_msg["properties"]["dic"],{key="value"});
   assert.are.same(ta_msg["properties"]["arr"],{{key="value"}});
end

function assertSDKProperties()
  assert.are.same(ta_msg["properties"]["#lib"],'Lua');
  assert.are.same(ta_msg["properties"]["#lib_version"],'1.5.0');
end

function assertPresetProperties()
  assert.are.same(ta_msg["#ip"],"127.0.0.1");
  assert.are.same(ta_msg["#uuid"],'XXXX');
  assert.are.same(ta_msg["#time"],'2021-09-20 17:00:00.000');
  assert.are.same(ta_msg["#app_id"],'appid');
end

function assertUserPropertyCase()
   sdk:userSet(accountId,distinctId,properties)
   assert.are.equal(ta_msg["#type"],"user_set");
   assertTrackProperties();
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);

   sdk:userSetOnce(accountId,distinctId,properties)
   assert.are.equal(ta_msg["#type"],"user_setOnce");
   assertTrackProperties();
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);

   sdk:userAppend(accountId,distinctId,properties)
   assert.are.equal(ta_msg["#type"],"user_append");
   assertTrackProperties();
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);

   sdk:userUniqueAppend(accountId,distinctId,properties)
   assert.are.equal(ta_msg["#type"],"user_uniq_append");
   assertTrackProperties();
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);


   sdk:userDel(accountId,distinctId)
   assert.are.equal(ta_msg["#type"],"user_del");
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);
  
   sdk:userUnset(accountId,distinctId,{productNames='',arr=''})
   assert.are.equal(ta_msg["#type"],"user_unset");
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);
   assert.are.same(ta_msg["properties"]["arr"],0);
   assert.are.same(ta_msg["properties"]["productNames"],0);


   sdk:userAdd(accountId,distinctId,{a=1})
   assert.are.equal(ta_msg["#type"],"user_add");
   assert.are.same(ta_msg["properties"]["#lib"],nil);
   assert.are.same(ta_msg["properties"]["#lib_version"],nil);
   assert.are.same(ta_msg["properties"]["a"],1);


end



function assertId()
  assert.are.equal(ta_msg["#distinct_id"],"1234567890987654321");
  assert.are.equal(ta_msg["#account_id"],"Test");
end 



describe("Unit Test", function()
  
  setup(function()
  end)

  teardown(function()
    
  end)

  before_each(function()
    
  end)

  it("Track Data Correct", function()
    distinctId = "1234567890987654321"
    accountId = 'Test'
    properties = {}
    properties["productNames"] = { "Lua入门"}
    properties["productType"] = "Lua书籍"
    properties["producePrice"] = 80
    properties["shop"] = "网上书城"
    dic = {}
    dic['key'] = 'value'
    properties['dic']=dic
    properties['arr']={dic}
    assertTrackCase(accountId,distinctId,"test",properties)
  end)

  it("User Data Correct", function()
    distinctId = "1234567890987654321"
    accountId = 'Test'
    properties = {}
    properties["productNames"] = { "Lua入门"}
    properties["productType"] = "Lua书籍"
    properties["producePrice"] = 80
    properties["shop"] = "网上书城"
    dic = {}
    dic['key'] = 'value'
    properties['dic']=dic
    properties['arr']={dic}
    assertUserPropertyCase(accountId,distinctId,properties)
  end)

  it("Preset Data Correct", function()
    distinctId = "1234567890987654321"
    accountId = 'Test'
    properties = {}
    properties["productNames"] = { "Lua入门"}
    properties["productType"] = "Lua书籍"
    properties["producePrice"] = 80
    properties["shop"] = "网上书城"
    dic = {}
    dic['key'] = 'value'
    properties['dic']=dic
    properties['arr']={dic}
    properties["#ip"] = "127.0.0.1"
    properties["#uuid"] = 'XXXX'
    properties["#time"] = "2021-09-20 17:00:00.000"
    properties["#app_id"] = "appid"
    
    sdk:track(accountId, distinctId,eventName, properties)
    assertPresetProperties();
    sdk:trackUpdate(accountId, distinctId,eventName,'user_id',properties)
    assertPresetProperties();
    sdk:trackOverwrite(accountId, distinctId,eventName,'userid', properties)
    assertPresetProperties();
    sdk:trackFirst(accountId, distinctId,eventName,"userid",properties)
    assertPresetProperties();
    
    sdk:userSet(accountId,distinctId,properties)
    assertPresetProperties();
    sdk:userSetOnce(accountId,distinctId,properties)
    assertPresetProperties();
    sdk:userAppend(accountId,distinctId,properties)
    assertPresetProperties();
    sdk:userUniqueAppend(accountId,distinctId,properties)
    assertPresetProperties();
    sdk:userUnset(accountId,distinctId,properties)
    assertPresetProperties();
    sdk:userAdd(accountId,distinctId,{a=1})

  end)

end)