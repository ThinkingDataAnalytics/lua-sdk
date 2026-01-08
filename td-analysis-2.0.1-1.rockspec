rockspec_format = "3.0"
package = "td-analysis"
version = "2.0.1-1"

source = {
    url = "git+https://github.com/ThinkingDataAnalytics/lua-sdk",
    tag = "v2.0.1",
}

build = {
  type = "builtin",
  modules = {
    ["td-analysis"] = "ThinkingDataLuaSdk/ThinkingDataSdk.lua",
  }
}

description = {
    summary = "Thinking data analysis sdk",
    detailed = [[
        https://thinkingdata.cn/
    ]],
    homepage = "https://thinkingdata.cn/",
    license = "Apache-2.0"
}

dependencies = {
    "lua >= 5.1",
    "lua-cjson >= 2.1.0.10-1",
    "luasec >= 1.3.2-1",
    "luasocket >= 3.1.0-1",
    "uuid == 0.3-1"
}