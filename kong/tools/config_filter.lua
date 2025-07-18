-- kong/tools/config_filter.lua
-- Utility to filter Kong config tables by tags, labels, or entities (workspaces, services, etc.)
-- Used for filtered delta syncing between CP and DP.

local _M = {}

-- Filters config by tags, labels, or entities
-- @param config_table: table, full config
-- @param filter: table, e.g. { tags = {...}, workspaces = {...}, services = {...}, ... }
-- Returns filtered config table
function _M.filter_config(config_table, filter)
  local filtered = {}
  -- Example: filter by workspaces
  if filter.workspaces then
    filtered.workspaces = {}
    for _, ws in ipairs(config_table.workspaces or {}) do
      if filter.workspaces[ws.name] then
        table.insert(filtered.workspaces, ws)
      end
    end
  end
  -- Example: filter by services
  if filter.services then
    filtered.services = {}
    for _, svc in ipairs(config_table.services or {}) do
      if filter.services[svc.name] then
        table.insert(filtered.services, svc)
      end
    end
  end
  -- Example: filter by tags
  if filter.tags then
    filtered.routes = {}
    for _, route in ipairs(config_table.routes or {}) do
      for _, tag in ipairs(route.tags or {}) do
        if filter.tags[tag] then
          table.insert(filtered.routes, route)
          break
        end
      end
    end
  end
  -- Extend for other entities as needed
  return filtered
end

return _M
