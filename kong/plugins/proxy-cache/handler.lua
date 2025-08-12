local require     = require
local cache_key   = require "kong.plugins.proxy-cache.cache_key"
local kong_meta   = require "kong.meta"
local mime_type   = require "kong.tools.mime_type"
local nkeys       = require "table.nkeys"

local splitn      = require("kong.tools.string").splitn

-- weak-key map: conf -> prepared lookup tables & per-conf state
local prepared_by_conf = setmetatable({}, { __mode = "k" })

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
    n = n + 1; keys[n] = k
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

-- Return (and cache) per-conf prepared state for O(1) lookups
local function get_prepared(conf)
  local p = prepared_by_conf[conf]
  if p then
    return p
  end

  -- Build Content-Type lookup structures once per-conf:
  --   exact[type][subtype][paramsKey] = true
  --   type_wild[type][paramsKey]     = true    (type/*)
  --   any[paramsKey]                 = true    (*/*)
  local exact, type_wild, any = {}, {}, {}
  local parse_mime_type = mime_type.parse_mime_type

  for i = 1, #(conf.content_type or {}) do
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

  local strategy = require(STRATEGY_PATH)({
    strategy_name = conf.strategy,
    strategy_opts = conf[conf.strategy],
  })

  p = {
    method_set = build_set(conf.request_method or {}),
    status_set = build_set(conf.response_code or {}),

    -- CT matching structures (prebuilt once; O(1) at runtime)
    ct_exact   = exact,
    ct_type_w  = type_wild,
    ct_any     = any,

    strategy   = strategy,
  }

  prepared_by_conf[conf] = p
  return p
end

local ngx              = ngx
local kong             = kong
local type             = type
local pairs            = pairs
local floor            = math.floor
local lower            = string.lower
local time             = ngx.time
local resp_get_headers = ngx.resp and ngx.resp.get_headers
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
     and not string.find(n_header, "ratelimit-remaining", 1, true)
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

-- O(1) CT check using prebuilt maps
local function ct_is_cacheable(conf, raw_ct)
  if not raw_ct or type(raw_ct) == "table" or raw_ct == "" then
    return false
  end

  local p = get_prepared(conf)
  local t, subtype, params = parse_mime_type(raw_ct)
  if not t then
    return false
  end

  local pk = params_key(params)

  -- exact type/subtype + exact params
  local tmap = p.ct_exact[t]
  if tmap then
    local smap = tmap[subtype]
    if smap and smap[pk] then
      return true
    end
  end

  -- type/* + exact params
  local tw = p.ct_type_w[t]
  if tw and tw[pk] then
    return true
  end

  -- */* + exact params
  if p.ct_any[pk] then
    return true
  end

  return false
end

local function cacheable_request(conf, cc)
  -- method check is O(1)
  do
    local method = kong.request.get_method()
    local p = get_prepared(conf)
    if not p.method_set[method] then
      return false
    end
  end

  -- explicit disallow directives or Authorization header present
  if conf.cache_control and (cc["no-store"] or cc["no-cache"] or kong.request.get_header("authorization")) then
    return false
  end

  return true
end

local function cacheable_response(conf, cc)
  -- status check is O(1)
  do
    local status = kong.response.get_status()
    local p = get_prepared(conf)
    if not p.status_set[status] then
      return false
    end
  end

  -- content-type check is O(1)
  do
    local content_type = ngx.var.sent_http_content_type
    if not ct_is_cacheable(conf, content_type) then
      return false
    end
  end

  if conf.cache_control and (cc["private"] or cc["no-store"] or cc["no-cache"]) then
    return false
  end

  if conf.cache_control and calculate_resource_ttl(cc) <= 0 then
    return false
  end

  return true
end

-- indicate that we should attempt to cache the response to this request
local function signal_cache_req(ctx, conf, cache_key, cache_status)
  ctx.proxy_cache = { cache_key = cache_key }
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
      local ok, e = strategy:purge(cache_key)
      if not ok then
        kong.log.err("failed to purge cache key '", cache_key, "': ", e)
        return
      end
    else
      local ok, e = strategy:flush(true)
      if not ok then
        kong.log.err("error in flushing cache data: ", e)
      end
    end
  end)
end

function ProxyCacheHandler:access(conf)
  local cc = req_cc()

  -- if we know this request isn't cacheable, bail out
  if not cacheable_request(conf, cc) then
    set_header(conf, "X-Cache-Status", "Bypass")
    return
  end

  local consumer = kong.client.get_consumer()
  local route = kong.router.get_route()
  local uri = kong.request.get_path()

  -- if we want the cache-key uri only to be lowercase
  if conf.ignore_uri_case then
    uri = lower(uri)
  end

  local key, err = cache_key.build_cache_key(
    consumer and consumer.id,
    route    and route.id,
    kong.request.get_method(),
    uri,
    kong.request.get_query(),
    kong.request.get_headers(),
    conf
  )
  if err then
    kong.log.err(err)
    return
  end

  set_header(conf, "X-Cache-Key", key)

  -- try to fetch the cached object from the computed cache key
  local strategy = get_prepared(conf).strategy

  local ctx = kong.ctx.plugin
  local res, ferr = strategy:fetch(key)
  if ferr == "request object not in cache" then
    -- this request wasn't found in the data store, but the client only wanted cached data
    if conf.cache_control and cc["only-if-cached"] then
      return kong.response.exit(ngx.HTTP_GATEWAY_TIMEOUT)
    end

    ctx.req_body = kong.request.get_raw_body()

    -- mark to store later; pass upstream
    return signal_cache_req(ctx, conf, key)

  elseif ferr then
    kong.log.err(ferr)
    return
  end

  if res.version ~= CACHE_VERSION then
    kong.log.notice("cache format mismatch, purging ", key)
    strategy:purge(key)
    return signal_cache_req(ctx, conf, key, "Bypass")
  end

  -- decide if client accepts cached value
  local now = time()
  if conf.cache_control then
    if cc["max-age"]   and now - res.timestamp > cc["max-age"] then
      return signal_cache_req(ctx, conf, key, "Refresh")
    end
    if cc["max-stale"] and (now - res.timestamp - res.ttl) > cc["max-stale"] then
      return signal_cache_req(ctx, conf, key, "Refresh")
    end
    if cc["min-fresh"] and (res.ttl - (now - res.timestamp)) < cc["min-fresh"] then
      return signal_cache_req(ctx, conf, key, "Refresh")
    end
  else
    if now - res.timestamp > conf.cache_ttl then
      return signal_cache_req(ctx, conf, key, "Refresh")
    end
  end

  -- cache hit: expose response data for logging plugins
  kong.ctx.shared.proxy_cache_hit = {
    res = res,
    req = { body = res.req_body },
    server_addr = ngx.var.server_addr,
  }

  ngx.ctx.KONG_PROXIED = true

  for k in pairs(res.headers) do
    if not overwritable_header(k) then
      res.headers[k] = nil
    end
  end

  reset_res_header(res)
  set_res_header(res, "Age", floor(time() - res.timestamp), conf)
  set_res_header(res, "X-Cache-Status", "Hit", conf)
  set_res_header(res, "X-Cache-Key", key, conf)

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
    -- zero-limit means "all headers"; use raw = true for less copying
    proxy_cache.res_headers = resp_get_headers(0, true)
    proxy_cache.res_ttl     = conf.cache_control and calculate_resource_ttl(cc) or conf.cache_ttl
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
    local strategy = get_prepared(conf).strategy

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

    local ttl = conf.storage_ttl or (conf.cache_control and proxy_cache.res_ttl) or conf.cache_ttl

    local ok, err = strategy:store(proxy_cache.cache_key, res, ttl)
    if not ok then
      kong.log(err)
    end
  end
end

return ProxyCacheHandler
