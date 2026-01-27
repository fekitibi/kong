local _M = {}
local _MT = { __index = _M }


local cjson = require("cjson.safe")
local buffer = require("string.buffer")


local type = type
local sub = string.sub
local fmt = string.format
local ipairs = ipairs
local ngx_log = ngx.log
local ngx_null = ngx.null
local ngx_ERR = ngx.ERR
local cjson_encode = cjson.encode
local cjson_decode = cjson.decode


-- version string should look like: "v02_0000"
local VER_PREFIX = "v02_"
local VER_PREFIX_LEN = #VER_PREFIX
local VER_DIGITS = 28
-- equivalent to "v02_" .. "%028x"
local VERSION_FMT = VER_PREFIX .. "%0" .. VER_DIGITS .. "x"

-- number of deltas to keep before cleanup
local KEEP_VERSION_COUNT = 100
local CLEANUP_TIME_DELAY = 3600  -- 1 hour


function _M.new(db)
  local self = {
    connector = db.connector,
  }

  return setmetatable(self, _MT)
end


local PURGE_QUERY = [[
  DELETE FROM clustering_sync_version
  WHERE "version" < (
      SELECT MAX("version") - %d
      FROM clustering_sync_version
  );
]]


function _M:init_worker()
  local function cleanup_handler(premature)
    if premature then
      return
    end

    local res, err = self.connector:query(fmt(PURGE_QUERY, KEEP_VERSION_COUNT))
    if not res then
      ngx_log(ngx_ERR,
              "[incremental] unable to purge old data from incremental delta table, err: ",
              err)

      return
    end
  end

  assert(ngx.timer.every(CLEANUP_TIME_DELAY, cleanup_handler))
end


local NEW_VERSION_QUERY = [[
  DO $$
  DECLARE
    new_version bigint;
  BEGIN
    INSERT INTO clustering_sync_version DEFAULT VALUES RETURNING version INTO new_version;
    INSERT INTO clustering_sync_delta (version, type, pk, ws_id, entity) VALUES %s;
  END $$;
]]


-- deltas: {
--   { type = "service", "pk" = { id = "d78eb00f..." }, "ws_id" = "73478cf6...", entity = <JSON or ngx.null>, }
-- }
function _M:insert_delta(deltas)
  local buf = buffer.new()

  local count = #deltas
  for i = 1, count do
    local d = deltas[i]

    buf:putf("(new_version, %s, %s, %s, %s)",
             self.connector:escape_literal(d.type),
             self.connector:escape_literal(cjson_encode(d.pk)),
             self.connector:escape_literal(d.ws_id or kong.default_workspace),
             self.connector:escape_literal(cjson_encode(d.entity)))

    -- sql values should be separated by comma
    if i < count then
      buf:put(",")
    end
  end

  local sql = fmt(NEW_VERSION_QUERY, buf:get())

  return self.connector:query(sql)
end


function _M:get_latest_version()
  local sql = "SELECT MAX(version) FROM clustering_sync_version"

  local res, err = self.connector:query(sql, "read")
  if not res then
    return nil, err
  end

  local ver = res[1] and res[1].max
  if ver == ngx_null then
    return fmt(VERSION_FMT, 0)
  end

  return fmt(VERSION_FMT, ver)
end


-- get deltas after a specific version
function _M:get_delta(version)
  -- convert version string to number
  local version_num = self:version_to_number(version)--tonumber(sub(version, VER_PREFIX_LEN + 1), 16)

  local sql = "SELECT * FROM clustering_sync_delta" ..
              " WHERE version > " .. self.connector:escape_literal(version_num) ..
              " ORDER BY version ASC"

  local res, err = self.connector:query(sql, "read")
  if not res then
    return nil, err
  end

  -- transform the result to include version as string format
  for _, row in ipairs(res) do
    row.version = fmt(VERSION_FMT, row.version)
    row.pk = cjson_decode(row.pk)
    if row.entity ~= ngx_null then
      row.entity = cjson_decode(row.entity)
    end
    if row.ws_id == ngx_null then
      row.ws_id = nil
    end
  end

  return res
end


function _M:is_valid_version(str)
  if type(str) ~= "string" then
    return false
  end

  if #str ~= VER_PREFIX_LEN + VER_DIGITS then
    return false
  end

  -- | v02_xxxxxxxxxxxxxxxxxxxxxxxxxx |
  --   |--|
  -- Is starts with "v02_"?
  if sub(str, 1, VER_PREFIX_LEN) ~= VER_PREFIX then
    return false
  end

  -- | v02_xxxxxxxxxxxxxxxxxxxxxxxxxx |
  --       |------------------------|
  -- Is the rest a valid hex number?
  if not tonumber(sub(str, VER_PREFIX_LEN + 1), 16) then
    return false
  end

  return true
end


-- convert version string to number for comparison
function _M:version_to_number(str)
  if not self:is_valid_version(str) then
    return 0
  end
  return tonumber(sub(str, VER_PREFIX_LEN + 1), 16)
end


function _M:begin_txn()
  return self.connector:query("BEGIN;")
end


function _M:commit_txn()
  return self.connector:query("COMMIT;")
end


function _M:cancel_txn()
  -- we will close the connection, not execute 'ROLLBACK'
  return self.connector:close()
end


return _M
