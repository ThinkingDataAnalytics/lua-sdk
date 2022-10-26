# Lua SDK使用指南

本指南将会为您介绍如何使用Lua SDK接入您的项目。

**最新版本为：** 1.5.1

**更新时间为：** 2022-09-21


## 1. 初始化SDK

您可以通过三种方式获得SDK实例（其他Consumer构造器的重载请参考API文档）：

### a) LogConsumer

**LogConsumer：** 批量写本地文件，文件按天或小时分隔，需要搭配LogBus进行上传

```lua
--LogConsumer
local TdSDK = require "ThinkingDataSdk"
local LOG_DIRECTORY = "/tmp/data" --必传，本地文件路径
local fileNamePrefix = "td" --可选参数，生成的文件前缀，生成的文件格式为td.log.%Y-%m-%d-%H_0，默认格式为log.%Y-%m-%d-%H_0
local batchNum = 15 --可选参数，设置每次保存的条数，即每15条保存一次，默认值为10
local fileSize = 15 --可选参数，每个文件大小上限，单位为M，默认不设上限
local rule = TdSDK.LOG_RULE.HOUR --可选参数，分隔文件的方式，可选为HOUR或DAY，即按小时划分或按天划分，默认按天划分
local consumer = TdSDK.LogConsumer(LOG_DIRECTORY, fileNamePrefix, batchNum, fileSize, rule)
local td = TdSDK(consumer)
```

`LOG_DIRECTORY`为写入本地的文件夹地址，您只需将LogBus的监听文件夹地址设置为此处的地址，即可使用LogBus进行数据的监听上传。

### b) BatchConsumer

**BatchConsumer：** 批量向TA服务器传输数据，不需要搭配传输工具，可设置每次上传的最大数量（默认20）和缓存最大批数（默认50），即默认最大缓存数量为20*50条。

```lua
--BatchConsumer
local TdSDK = require "ThinkingDataSdk"
local APP_ID = "APPKEY"
local SERVER_URI = "http://host:port"
local consumer = TdSDK.BatchConsumer(SERVER_URI, APP_ID)
local td = TdSDK(consumer)
```

### c) DebugConsumer

**DebugConsumer：** 逐条向 TA 服务器传输数据，在数据校验出错时会抛出异常，用于数据调试

```lua
--DebugConsumer
local TdSDK = require "ThinkingDataSdk"
local APP_ID = "APPKEY"
local SERVER_URI = "http://host:port"
local consumer = TdSDK.DebugConsumer(SERVER_URI, APP_ID)
local td = TdSDK(consumer)
```
`SERVER_URI`为传输数据的uri，`APP_ID`为您的项目的APP ID

如果您使用的是云服务，请输入以下URL:

http://receiver.ta.thinkingdata.cn

如果您使用的是私有化部署的版本，请输入以下URL:

http://<font color="red">数据采集地址</font>



## 2. 发送事件

在SDK初始化完成之后，您就可以调用`track`来上传事件，一般情况下，您可能需要上传十几到上百个不同的事件，如果您是第一次使用TGA后台，我们推荐您先上传几个关键事件。


### a) 发送事件

您可以调用`track`来上传事件，建议您根据先前梳理的文档来设置事件的属性以及发送信息的条件，此处以玩家付费作为范例：

```lua
--初始化SDK
local TdSDK = require "ThinkingDataSdk"
local APP_ID = "APPKEY"
local SERVER_URI = "http://host:port"
local consumer = TdSDK.BatchConsumer(SERVER_URI, APP_ID)
local td = TdSDK(consumer)

--设置访客ID"ABCDEFG123456789"
local distinctId = "ABCDEFG123456789"

--设置账号ID"TA_10001"
local accountId = "TA_10001"

--设置事件属性
local properties = {}

--设置事件发生的时间，如果不设置的话，则默认使用为当前时间
properties["#time"] = os.date("%Y-%m-%d %H:%M:%S")

--设置用户的ip地址，TA系统会根据IP地址解析用户的地理位置信息，如果不设置的话，则默认不上报
properties["#ip"] = "192.168.1.1"

properties["Product_Name"] = "月卡"
properties["Price"] = 30
properties["OrderId"] = "abc_123"

--上传事件，包含用户的访客ID与账号ID，请注意账号ID与访客ID的顺序
sdk:track(distinctId, accountId, "payment", properties)
properties = nil
```
**注：** 为了保证访客ID与账号ID能够顺利进行绑定，如果您的游戏中会用到访客ID与账号ID，我们极力建议您同时上传这两个ID，<font color="red">否则将会出现账号无法匹配的情况，导致用户重复计算</font>。

* 事件的名称是`String`类型，只能以字母开头，可包含数字，字母和下划线“\_”，长度最大为50个字符，对字母大小写不敏感。
* 事件的属性是一个`table`对象，其中每个元素代表一个属性。  
* Key的值为属性的名称，为`String`类型，规定只能是预置属性，或以字母开头，包含数字，字母和下划线“\_”，长度最大为50个字符，对字母大小写不敏感。  
* Value为该属性的值，支持`String`、`Number`、`Boolean`、`Date`和`Array`。


### b) 设置公共事件属性

对于一些需要出现在所有事件中的属性，您可以调用`setSuperProperties`将这些属性设置为公共事件属性，公共事件属性将会添加到所有使用`track`上传的事件中。
  
```lua
local superProperties = {}
--设置公共属性：服务器名称
superProperties["server_name"] = "S10001"
--设置公共属性：服务器版本
superProperties["server_version"] = "1.2.3"
--设置公共事件属性
sd:setSuperProperties(superProperties)
superProperties = nil

local properties = {}
--设置事件属性
properties["Product_Name"] = "月卡"
properties["Price"] = 30
--上传事件，此时事件中将带有公共属性以及该事件的属性
sd:track(accountId, distinctId, "payment", properties)
properties = nil
```  
  
* 公共事件属性同样也是一个`table`对象，其中每个元素代表一个属性。  
* Key的值为属性的名称，为`String`类型，规定只能是预置属性，或以字母开头，包含数字，字母和下划线“\_”，长度最大为50个字符，对字母大小写不敏感。  
* Value为该属性的值，支持`String`、`Number`、`Boolean`、`Date`和`Array`。
 
如果调用`setSuperProperties`设置先前已设置过的公共事件属性，则会覆盖之前的属性值。如果公共事件属性和`track`上传事件中的某个属性的Key重复，则该事件的属性会覆盖公共事件属性：
```lua
local superProperties = {}
superProperties["server_name"] = "S10001"
superProperties["server_version"] = "1.2.3"
--设置公共事件属性
sd:setSuperProperties(superProperties)
superProperties = {}
superProperties["server_name"] = "Q12345"
--再次设置公共事件属性，此时"server_name"被覆盖，值为"Q12345"
sd:setSuperProperties(superProperties)

local properties = {}
properties["Product_Name"] = "月卡"
--设置与公共事件属性重复的属性
superProperties["server_version"] = "1.2.4"
--上传事件，此时"server_version"的属性值会被覆盖为"1.2.4"，"server_name"的值为"Q12345"
sd:track(accountId, distinctId, "payment", properties)
```
如果您想要清空所有公共事件属性，可以调用`clearSuperProperties`。

## 3. 用户属性

TGA平台目前支持的用户属性设置接口为userSet、userUnset、userSetOnce、userAdd、userDel、userAppend。

### a) userSet

对于一般的用户属性，您可以调用`userSet`来进行设置，使用该接口上传的属性将会覆盖原有的属性值，如果之前不存在该用户属性，则会新建该用户属性，类型与传入属性的类型一致，此处以玩家设置用户名为例：

```lua
local userSetProperties = {}
userSetProperties["user_name"] = "ABC"
userSetProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--上传用户属性
sd:userSet(accountId, distinctId, userSetProperties)

userSetProperties = {}
userSetProperties["user_name"] = "abc"
userSetProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
//再次上传用户属性，此时"user_name"的值会被覆盖为"abc"
sd:userSet(accountId, distinctId, userSetProperties)
```

* `userSet`设置的用户属性是一个`table`对象，其中每个元素代表一个属性。  
* Key的值为属性的名称，为`string`类型，规定只能以字母开头，包含数字，字母和下划线“_”，长度最大为50个字符，对字母大小写不敏感。  
* Value为该属性的值，支持`String`、`Number`、`Boolean`、`Date`和`Array`。

### b) userSetOnce

如果您要上传的用户属性只要设置一次，则可以调用`userSetOnce`来进行设置，当该属性之前已经有值的时候，将会忽略这条信息，再以设置玩家用户名为例：

```lua
local userSetOnceProperties = {}
userSetOnceProperties["user_name"] = "ABC"
userSetOnceProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--上传用户属性，新建"user_name"，值为"ABC"
sd:userSetOnce(accountId, distinctId, userSetOnceProperties)

userSetOnceProperties = {}
userSetOnceProperties["user_name"] = "abc"
userSetOnceProperties["user_age"] = 18
userSetOnceProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--再次上传用户属性，此时"user_name"的值不会被覆盖，仍为"ABC"，"user_age"的值为18
sd:userSetOnce(accountId, distinctId, userSetOnceProperties)
```

`userSetOnce`设置的用户属性类型及限制条件与`userSet`一致。

### c) userAdd

当您要上传数值型的属性时，您可以调用`userAdd`来对该属性进行累加操作，如果该属性还未被设置，则会赋值0后再进行计算，可传入负值，等同于相减操作。此处以累计付费金额为例：

```lua
local userAddProperties = {}
userAddProperties["total_revenue"] = 30
userAddProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--上传用户属性，此时"total_revenue"的值为30
sd:userAdd(accountId, distinctId, userAddProperties)

userAddProperties = {}
userAddProperties["total_revenue"] = 60
userAddProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--再次上传用户属性，此时"total_revenue"的值会累加为90
sd:userAdd(accountId, distinctId, userAddProperties)
```

`userAdd`设置的用户属性类型及限制条件与`userSet`一致，<font color="red">但只支持传入数值型的用户属性。</font>

### d) userAppend

当您需要为`Array`属性值添加元素时，您可以调用`userAppend`来对该列表进行添加操作，如果该属性还未在集群中被创建，则userAppend创建该属性。此处以装备列表为例：

```lua
local equips = {}
equips[1] = "weapon"
equips[2] = "hat"
local userAppendProperties = {}
userAppendProperties["equips"] = equips
userAppendProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--上传用户属性，此时"equips"的值为["weapon", "hat"]
sd:userAppend(accountId, distinctId, userAppendProperties)

equips = {}
equips[1] = "clothes"
userAppendProperties = {}
userAppendProperties["equips"] = "clothes"
userAppendProperties["#time"] = os.date("%Y-%m-%d %H:%M:%S")
--再次上传用户属性，此时"equips"的值会增加一个"clothes":["weapon", "hat", "clothes"]
sd:userAppend(accountId, distinctId, userAppendProperties)
```
`userAppend`设置的用户属性类型<font color="red">仅支持`Array`类型，其他类型会被忽略。

### e) userUnset

当您需要清空某些属性时，可以调用`userUnset`将这些属性清空（即设置成 NULL），如果某个属性不存在不会新建该属性。

```lua
local userUnsetProperties = {}
userUnsetProperties[1] = "total_revenue"
userUnsetProperties[2] = "equips"
--上传用户属性，此时将会重置"total_revenue"和"equips"两个属性
sd:userUnset(accountId, distinctId, userUnsetProperties)

```

### f) userDel

如果您要删除某个用户，可以调用`userDel`将这名用户删除，您将无法再查询该名用户的用户属性，但该用户产生的事件仍然可以被查询到，<font color="red">该操作可能产生不可逆的后果，请慎用</font>

```lua
sd:userDel(accountId, distinctId)
```

## 4. 其他操作

### a) 立即提交数据

```lua
sd:flush()
```

立即提交数据到相应的接收器

### b) 关闭sdk
	
```lua
sd:close()
```

关闭并退出sdk，请在关闭服务器前调用本接口，以避免缓存内的数据丢失


## ChangeLog
	
#### v1.5.1 2022/09/21

* 修复Bug:用户属性的Key以#号开头，会出现数据发送异常

#### v1.5.0 2022/08/08

* 去除Util文件 
* 代码优化
	

#### v1.4.0 2022/04/26

* 支持创建默认事件uuid
* 支持动态公共属性
* 支持首次事件
* 新增user_uniq_append事件

#### v1.3.0 2022/02/28

* 支持上传复杂结构类型

#### v1.2.0 2021/03/12

* BatchConsumer模式增加可设置最大缓存值

#### v1.1.1 2021/02/23

* 增加DebugConsumer模式的debugOnly功能
* BatchConsumer模式在因网络问题发送失败时不删除数据

#### v1.1.0 2021/01/13

* 修复指定文件大小时无法生成文件的错误

#### v1.0.0 2020/11/20

* Lua SDK 1.0.0版本上线


