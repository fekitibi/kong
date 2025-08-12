local require     = require
local cache_key   = require "kong.plugins.proxy-cache.cache_key"
local kong_meta   = require "kong.meta"
local mime_type   = require "kong.tools.mime_type"
local nkeys       = require "table.nkeys"
local splitn      = require("kong.tools.string").splitn


local ngx              = ngx
local kong             = kong
local type             = type
local pairs            = pairs
local floor            = math.floor
local lower            = string.lower
local time             = ngx.time
local resp_get_headers = ngx.resp and ngx.resp.get_headers
local ngx_re_sub       = ngx.re.gsub
local ngx_re_match     = ngx.re.match
local parse_mime_type  = mime_type.parse_mime_type
local parse_directive_header = require("kong.tools.http").parse_directive_header
local calculate_resource_ttl = require("kong.tools.http").calculate_resource_ttl




local STRATEGY_PATH = "kong.plugins.proxy-cache.strategies"
local CACHE_VERSION = 1
local EMPTY = require("kong.tools.table").EMPTY


-- http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.1
-- note content-length is not strictly hop-by-hop but we will be
-- adjusting it here anyhow
local hop_by_hop_headers = {
  ["connection"]          = true,
  ["keep-alive"]          = true,
  ["proxy-authenticate"]  = true,
  ["proxy-authorization"] = true,
  ["te"]                  = true,
  ["trailers"]            = true,
  ["transfer-encoding"]   = true,
  ["upgrade"]             = true,
  ["content-length"]      = true,
}


local function overwritable_header(header)
  local n_header = lower(header)

  return not hop_by_hop_headers[n_header]
     and not ngx_re_match(n_header, "ratelimit-remaining", "jo")
end

local function set_header(conf, header, value)
  if ngx.var.http_kong_debug or conf.response_headers[header] then
    kong.response.set_header(header, value)
  end
end

local function reset_res_header(res)
  res.headers["Age"] = nil
  res.headers["X-Cache-Status"] = nil
  res.headers["X-Cache-Key"] = nil
end

local function set_res_header(res, header, value, conf)
  if ngx.var.http_kong_debug or conf.response_headers[header] then
    res.headers[header] = value
  end
end

local function req_cc()
  return parse_directive_header(ngx.var.http_cache_control)
end


local function res_cc()
  return parse_directive_header(ngx.var.sent_http_cache_control)
end


-- Build a set (hash) from an array-like table
local function build_set(t)
  local s = {}
  for i = 1, #t do
    s[t[i]] = true
  end
  return s
end

-- JIT-friendly in-place insertion sort for small arrays of strings
local function isort(a)
  for i = 2, #a do
    local v = a[i]
    local j = i - 1
    while j >= 1 and a[j] > v do
      a[j + 1] = a[j]
      j = j - 1
    end
    a[j + 1] = v
  end
end

-- Canonicalize MIME params to a stable key like "charset=utf-8;q=1"
local function params_key(params)
  if not params or nkeys(params) == 0 then
    return ""
  end
  local keys, n = {}, 0
  for k in pairs(params) do
    n = n + 1
    keys[n] = k
  end
  isort(keys)

  local parts, m = {}, 0
  for i = 1, n do
    local k = keys[i]
    m = m + 1
    parts[m] = k .. "=" .. (params[k] or "")
  end
  return table.concat(parts, ";")
end

-- Precompute O(1) lookups on first use in this worker
local function prepare_lookups(conf)
  if conf._pc_prepared then
    return
  end

  -- request methods and response codes
  conf._pc_method_set  = build_set(conf.request_method)

  local status_set = {}
  for i = 1, #conf.response_code do
    status_set[conf.response_code[i]] = true
  end
  conf._pc_status_set = status_set

  -- content-type patterns:
  -- store three maps:
  --   exact[type][subtype][paramsKey] = true
  --   type_wild[type][paramsKey]      = true      (matches type/* with exact params)
  --   any[paramsKey]                  = true      (*/* with exact params)
  local exact, type_wild, any = {}, {}, {}
  for i = 1, #conf.content_type do
    local exp_type, exp_subtype, exp_params = parse_mime_type(conf.content_type[i])
    if exp_type then
      local pkey = params_key(exp_params)
      if exp_type == "*" and exp_subtype == "*" then
        any[pkey] = true
      elseif exp_subtype == "*" then
        local tw = type_wild[exp_type]
        if not tw then
          tw = {}
          type_wild[exp_type] = tw
        end
        tw[pkey] = true
      else
        local tmap = exact[exp_type]
        if not tmap then
          tmap = {}
          exact[exp_type] = tmap
        end
        local smap = tmap[exp_subtype]
        if not smap then
          smap = {}
          tmap[exp_subtype] = smap
        end
        smap[pkey] = true
      end
    end
  end
  conf._pc_ct_exact      = exact
  conf._pc_ct_type_wild  = type_wild
  conf._pc_ct_any        = any
  conf._pc_prepared      = true
end


local function cacheable_request(conf, cc)
  prepare_lookups(conf)
  do
    local method = kong.request.get_method()
    if not conf._pc_method_set[method] then
      return false
    end
  end

  -- check for explicit disallow directives
  -- TODO note that no-cache isnt quite accurate here
  if conf.cache_control and (cc["no-store"] or cc["no-cache"] or
     ngx.var.authorization) then
    return false
  end

  return true
end


local function cacheable_response(conf, cc)
  prepare_lookups(conf)
  do
    local status = kong.response.get_status()
    if not conf._pc_status_set[status] then
      return false
    end
  end

  do
    local content_type = ngx.var.sent_http_content_type

    -- bail if we cannot examine this content type
    if not content_type or type(content_type) == "table" or
       content_type == "" then

      return false
    end

    local t, subtype, params = parse_mime_type(content_type)
    local pkey = params_key(params)
    local match = false

    -- exact type/subtype
    local tmap = conf._pc_ct_exact[t]
    if tmap then
      local smap = tmap[subtype]
      if smap and smap[pkey] then
        match = true
      end
    end
    -- type/* wildcard
    if not match then
      local tw = conf._pc_ct_type_wild[t]
      if tw and tw[pkey] then
        match = true
      end
    end
    -- */* wildcard
    if not match then
      if conf._pc_ct_any[pkey] then
        match = true
      end
    end

    if not match then
      return false
    end
  end

  if conf.cache_control and (cc["private"] or cc["no-store"] or cc["no-cache"])
  then
    return false
  end

  if conf.cache_control and calculate_resource_ttl(cc) <= 0 then
    return false
  end

  return true
end


-- indicate that we should attempt to cache the response to this request
local function signal_cache_req(ctx, conf, cache_key, cache_status)
  ctx.proxy_cache = {
    cache_key = cache_key,
  }
  set_header(conf, "X-Cache-Status", cache_status or "Miss")
end


local ProxyCacheHandler = {
  VERSION = kong_meta.version,
  PRIORITY = 100,
}


function ProxyCacheHandler:init_worker()
  -- catch notifications from other nodes that we purged a cache entry
  -- only need one worker to handle purges like this
  -- if/when we introduce inline LRU caching this needs to involve
  -- worker events as well
  kong.cluster_events:subscribe("proxy-cache:purge", function(data)
    kong.log.err("handling purge of '", data, "'")

    local t = splitn(data, ":", 3)
    local plugin_id, cache_key = t[1], t[2]
    local plugin, err = kong.db.plugins:select({ id = plugin_id })
    if err then
      kong.log.err("error in retrieving plugins: ", err)
      return
    end

    local strategy = require(STRATEGY_PATH)({
      strategy_name = plugin.config.strategy,
      strategy_opts = plugin.config[plugin.config.strategy],
    })

    if cache_key ~= "nil" then
      local ok, err = strategy:purge(cache_key)
      if not ok then
        kong.log.err("failed to purge cache key '", cache_key, "': ", err)
        return
      end

    else
      local ok, err = strategy:flush(true)
      if not ok then
        kong.log.err("error in flushing cache data: ", err)
      end
    end
  end)
end


function ProxyCacheHandler:access(conf)
  local cc = req_cc()

  -- if we know this request isnt cacheable, bail out
  if not cacheable_request(conf, cc) then
    set_header(conf, "X-Cache-Status", "Bypass")
    return
  end

  local consumer = kong.client.get_consumer()
  local route = kong.router.get_route()
  local uri = ngx_re_sub(ngx.var.request, "\\?.*", "", "oj")

  -- if we want the cache-key uri only to be lowercase
  if conf.ignore_uri_case then
    uri = lower(uri)
  end

  local cache_key, err = cache_key.build_cache_key(consumer and consumer.id,
                                                   route    and route.id,
                                                   kong.request.get_method(),
                                                   uri,
                                                   kong.request.get_query(),
                                                   kong.request.get_headers(),
                                                   conf)
  if err then
    kong.log.err(err)
    return
  end

  set_header(conf, "X-Cache-Key", cache_key)

  -- try to fetch the cached object from the computed cache key
  local strategy = require(STRATEGY_PATH)({
    strategy_name = conf.strategy,
    strategy_opts = conf[conf.strategy],
  })

  local ctx = kong.ctx.plugin
  local res, err = strategy:fetch(cache_key)
  if err == "request object not in cache" then -- TODO make this a utils enum err

    -- this request wasn't found in the data store, but the client only wanted
    -- cache data. see https://tools.ietf.org/html/rfc7234#section-5.2.1.7
    if conf.cache_control and cc["only-if-cached"] then
      return kong.response.exit(ngx.HTTP_GATEWAY_TIMEOUT)
    end

    ctx.req_body = kong.request.get_raw_body()

    -- this request is cacheable but wasn't found in the data store
    -- make a note that we should store it in cache later,
    -- and pass the request upstream
    return signal_cache_req(ctx, conf, cache_key)

  elseif err then
    kong.log.err(err)
    return
  end

  if res.version ~= CACHE_VERSION then
    kong.log.notice("cache format mismatch, purging ", cache_key)
    strategy:purge(cache_key)
    return signal_cache_req(ctx, conf, cache_key, "Bypass")
  end

  -- figure out if the client will accept our cache value
  if conf.cache_control then
    if cc["max-age"] and time() - res.timestamp > cc["max-age"] then
      return signal_cache_req(ctx, conf, cache_key, "Refresh")
    end

    if cc["max-stale"] and time() - res.timestamp - res.ttl > cc["max-stale"]
    then
      return signal_cache_req(ctx, conf, cache_key, "Refresh")
    end

    if cc["min-fresh"] and res.ttl - (time() - res.timestamp) < cc["min-fresh"]
    then
      return signal_cache_req(ctx, conf, cache_key, "Refresh")
    end

  else
    -- don't serve stale data; res may be stored for up to `conf.storage_ttl` secs
    if time() - res.timestamp > conf.cache_ttl then
      return signal_cache_req(ctx, conf, cache_key, "Refresh")
    end
  end

  -- we have cache data yo!
  -- expose response data for logging plugins
  local response_data = {
    res = res,
    req = {
      body = res.req_body,
    },
    server_addr = ngx.var.server_addr,
  }

  kong.ctx.shared.proxy_cache_hit = response_data

  local nctx = ngx.ctx
  nctx.KONG_PROXIED = true

  for k in pairs(res.headers) do
    if not overwritable_header(k) then
      res.headers[k] = nil
    end
  end


  reset_res_header(res)
  set_res_header(res, "age", floor(time() - res.timestamp), conf)
  set_res_header(res, "X-Cache-Status", "Hit", conf)
  set_res_header(res, "X-Cache-Key", cache_key, conf)

  return kong.response.exit(res.status, res.body, res.headers)
end


function ProxyCacheHandler:header_filter(conf)
  local ctx = kong.ctx.plugin
  local proxy_cache = ctx.proxy_cache
  -- don't look at our headers if
  -- a) the request wasn't cacheable, or
  -- b) the request was served from cache
  if not proxy_cache then
    return
  end

  local cc = res_cc()

  -- if this is a cacheable request, gather the headers and mark it so
  if cacheable_response(conf, cc) then
    -- TODO: should this use the kong.conf configured limit?
    proxy_cache.res_headers = resp_get_headers(0, true)
    proxy_cache.res_ttl = conf.cache_control and calculate_resource_ttl(cc) or conf.cache_ttl

  else
    set_header(conf, "X-Cache-Status", "Bypass")
    ctx.proxy_cache = nil
  end

  -- TODO handle Vary header
end


function ProxyCacheHandler:body_filter(conf)
  local ctx = kong.ctx.plugin
  local proxy_cache = ctx.proxy_cache
  if not proxy_cache then
    return
  end

  local body = kong.response.get_raw_body()
  if body then
    local strategy = require(STRATEGY_PATH)({
      strategy_name = conf.strategy,
      strategy_opts = conf[conf.strategy],
    })

    local res = {
      status    = kong.response.get_status(),
      headers   = proxy_cache.res_headers,
      body      = body,
      body_len  = #body,
      timestamp = time(),
      ttl       = proxy_cache.res_ttl,
      version   = CACHE_VERSION,
      req_body  = ctx.req_body,
    }

    local ttl = conf.storage_ttl or conf.cache_control and proxy_cache.res_ttl or
                conf.cache_ttl

    local ok, err = strategy:store(proxy_cache.cache_key, res, ttl)
    if not ok then
      kong.log(err)
    end
  end
end


return ProxyCacheHandler
