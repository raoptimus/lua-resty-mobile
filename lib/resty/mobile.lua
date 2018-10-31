-- Copyright (C) 2015 Ivan Epifanov

local log           = ngx.log
local ERR           = ngx.ERR
local ngx_header    = ngx.header
local shared        = ngx.shared
local json          = require "cjson"
local resty_cookie  = require "resty.cookie"

-- explode(seperator, string)
function explode(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function


local _M = {}

_M._VERSION = '0.01'

local mt = { __index = _M }

function _M.init(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    local _decoded = json.decode(content)
    -- phones
    local _ptable = {}
    for key,value in pairs(_decoded.uaMatch.phones) do
      table.insert(_ptable, value)
    end
    local _phones="("..table.concat(_ptable, "|")..")"
    shared.mobile:set("phones",_phones)

    -- tablets
    local _ttable = {}
    for key,value in pairs(_decoded.uaMatch.tablets) do
      table.insert(_ttable, value)
    end
    local _tablets="("..table.concat(_ttable, "|")..")"
    shared.mobile:set("tablets",_tablets)

    -- browsers
    local _btable = {}
    for key,value in pairs(_decoded.uaMatch.browsers) do
      table.insert(_btable, value)
    end
    local _browsers="("..table.concat(_btable, "|")..")"
    shared.mobile:set("browsers",_browsers)

    -- os
    local _ostable = {}
    for key,value in pairs(_decoded.uaMatch.os) do
      table.insert(_ostable, value)
    end
    local _os="("..table.concat(_ostable, "|")..")"
    shared.mobile:set("os",_os)

    -- ua headers
    shared.mobile:set("uaheaders",string.lower(table.concat(_decoded.uaHttpHeaders,"|")))

    -- headers
    local _htable = {}

    for key,value in pairs(_decoded.headerMatch) do
      if value == json.null then
        shared.mobile:set("header:"..string.lower(key),"(.+)")
      else
        shared.mobile:set("header:"..string.lower(key),"("..table.concat(value.matches,"|")..")")
      end
      table.insert(_htable, string.lower(key))
    end
    shared.mobile:set("headers",table.concat(_htable, "|"))
end


function _M.detect(cookie_name)
  if cookie_name then
    local cookies, err = resty_cookie:new()
    if not cookies then
      log(ngx.ERR, err)
      return 'false'
    end

    -- get mobile cookie
    local field, err = cookies:get(cookie_name)
    if field then
      ngx.var.device = field
      return 'true'
    end

    -- check cookie mode
    local cookie_value, err = cookies:get("mode")
    if cookie_value then 
      ngx.var.device = "desktop"
      return 'true'
    end

  end

  local device = 'desktop'

  -- check headers
  for key, value in pairs(explode("|",shared.mobile:get("headers"))) do
    if ngx.var[value] then
      local m, err = ngx.re.match( ngx.var[value], shared.mobile:get("header:"..value))
      if m then
        device = 'mobile'
      else
        if err then
          log(ngx.ERR, "error: ", err)
          return 'false'
        end
      end
    end
  end

  -- compose UA string
  local _uastr = ""
  for key, value in pairs(explode("|",shared.mobile:get("uaheaders"))) do
    if ngx.var[value] then
      _uastr=_uastr.." "..ngx.var[value]
    end
  end

  -- check against phones
  local m, err = ngx.re.match( _uastr, shared.mobile:get("phones"))
  if m then
    device = 'mobile'
  else
    if err then
      log(ngx.ERR, "error: ", err)
      return 'false'
    end
  end

  -- check against browsers
  local m, err = ngx.re.match( _uastr, shared.mobile:get("browsers"))
  if m then
    device = 'mobile'
  else
    if err then
      log(ngx.ERR, "error: ", err)
      return 'false'
    end
  end

  -- check against os
  local m, err = ngx.re.match( _uastr, shared.mobile:get("os"))
  if m then
    device = 'mobile'
  else
    if err then
      log(ngx.ERR, "error: ", err)
      return 'false'
    end
  end

  -- check against tablets
  local m, err = ngx.re.match( _uastr, shared.mobile:get("tablets"))
  if m then
      device = 'tablet'
  else
    if err then
      log(ngx.ERR, "error: ", err)
      return 'false'
    end
  end

  ngx.var.device = device

  -- local age = 31536000 --10 years
  -- _, err = cookies.set({
  --   key = cookie_name,
  --   value = device,
  --   path = "/",
  --   domain = ngx.var.http_host,
  --   secure = false, 
  --   httponly = true,
  --   expires = os.date("%a, %d %b %Y %X GMT", os.time() + age),
  --   max_age = age,
  -- })
  -- if err then
  --   log(ngx.ERR, "error: ", err)
  --   return 'false'
  -- end

  return 'true'
end

return _M
