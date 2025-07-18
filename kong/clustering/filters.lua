local _M = {}

local json_encode = require("cjson").encode
local json_decode = require("cjson").decode
local string_match = string.match
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs
local type = type

-- Kong-aligned filter types
local FILTER_TYPES = {
  TAGS = "tags",              -- Kong's existing tag system
  WORKSPACE = "workspace",    -- Kong Enterprise workspace concept
  LABELS = "labels",          -- DP labels (already used in clustering)
  SERVICE = "service",        -- Filter by specific services
  ROUTE = "route",           -- Filter by specific routes
  CONSUMER = "consumer",      -- Filter by specific consumers
  PLUGIN = "plugin",         -- Filter by plugin types
  CUSTOM = "custom"          -- For extensibility
}

-- Kong-style tag matching with wildcards
function _M.tag_matches(entity_tag, filter_tag)
  -- Exact match
  if entity_tag == filter_tag then
    return true
  end

  -- Wildcard matching (Kong pattern)
  -- env:* matches env:prod, env:staging, etc.
  if string_find(filter_tag, "*", 1, true) then
    local pattern = string_gsub(filter_tag, "%*", ".*")
    return string_match(entity_tag, "^" .. pattern .. "$") ~= nil
  end

  -- Prefix matching
  -- env: matches env:prod, env:staging (without explicit *)
  if string_sub(filter_tag, -1) == ":" then
    return string_sub(entity_tag, 1, #filter_tag) == filter_tag
  end

  return false
end

-- Default filter functions using Kong patterns
local DEFAULT_FILTERS = {
  [FILTER_TYPES.TAGS] = function(entity, filter_config)
    -- Use Kong's existing tag system
    if not entity.tags then
      return filter_config.default_action ~= "exclude"
    end

    local include_tags = filter_config.include or {}
    local exclude_tags = filter_config.exclude or {}

    -- Check exclusions first
    for _, entity_tag in ipairs(entity.tags) do
      for _, exclude_tag in ipairs(exclude_tags) do
        if _M.tag_matches(entity_tag, exclude_tag) then
          return false
        end
      end
    end

    -- Check inclusions
    if #include_tags == 0 then
      return true -- No specific inclusion rules
    end

    for _, entity_tag in ipairs(entity.tags) do
      for _, include_tag in ipairs(include_tags) do
        if _M.tag_matches(entity_tag, include_tag) then
          return true
        end
      end
    end

    return false
  end,

  [FILTER_TYPES.WORKSPACE] = function(entity, filter_config)
    -- Workspace-based filtering (Kong Enterprise pattern)
    local entity_workspace = entity.ws_id or entity.workspace or "default"
    local allowed_workspaces = filter_config.workspaces or { "default" }

    for _, workspace in ipairs(allowed_workspaces) do
      if entity_workspace == workspace then
        return true
      end
    end
    return false
  end,

  [FILTER_TYPES.SERVICE] = function(entity, filter_config)
    -- Service-specific filtering
    if entity._entity_type ~= "services" then
      return true -- Non-service entities pass through
    end

    if not filter_config.names and not filter_config.tags then
      return true
    end

    -- Filter by service names
    if filter_config.names then
      for _, name in ipairs(filter_config.names) do
        if entity.name == name then
          return true
        end
      end
    end

    -- Filter by service tags
    if filter_config.tags and entity.tags then
      for _, entity_tag in ipairs(entity.tags) do
        for _, filter_tag in ipairs(filter_config.tags) do
          if _M.tag_matches(entity_tag, filter_tag) then
            return true
          end
        end
      end
    end

    return false
  end,

  [FILTER_TYPES.ROUTE] = function(entity, filter_config)
    -- Route-specific filtering
    if entity._entity_type ~= "routes" then
      return true -- Non-route entities pass through
    end

    if not filter_config.paths and not filter_config.tags then
      return true
    end

    -- Filter by route paths
    if filter_config.paths and entity.paths then
      for _, entity_path in ipairs(entity.paths) do
        for _, filter_path in ipairs(filter_config.paths) do
          if string_match(entity_path, filter_path) then
            return true
          end
        end
      end
    end

    -- Filter by route tags
    if filter_config.tags and entity.tags then
      for _, entity_tag in ipairs(entity.tags) do
        for _, filter_tag in ipairs(filter_config.tags) do
          if _M.tag_matches(entity_tag, filter_tag) then
            return true
          end
        end
      end
    end

    return false
  end,

  [FILTER_TYPES.PLUGIN] = function(entity, filter_config)
    -- Plugin-specific filtering
    if entity._entity_type ~= "plugins" then
      return true -- Non-plugin entities pass through
    end

    if not filter_config.names and not filter_config.tags then
      return true
    end

    -- Filter by plugin names
    if filter_config.names then
      for _, name in ipairs(filter_config.names) do
        if entity.name == name then
          return true
        end
      end
    end

    -- Filter by plugin tags
    if filter_config.tags and entity.tags then
      for _, entity_tag in ipairs(entity.tags) do
        for _, filter_tag in ipairs(filter_config.tags) do
          if _M.tag_matches(entity_tag, filter_tag) then
            return true
          end
        end
      end
    end

    return false
  end,

  [FILTER_TYPES.LABELS] = function(entity, filter_config)
    -- Use Kong's DP label system
    if not filter_config.match then
      return true
    end

    -- This works on the DP level, not entity level
    -- We'll handle this in the DP filter parsing
    return true
  end
}

-- Custom filter registry
local custom_filters = {}

function _M.register_custom_filter(name, filter_func)
  custom_filters[name] = filter_func
end

function _M.parse_dp_filters(dp_metadata)
  local filters = {}

  -- Check for Kong-style configuration
  local filter_config = nil

  if dp_metadata and dp_metadata.filters then
    filter_config = dp_metadata.filters
  elseif dp_metadata and dp_metadata.labels then
    -- Auto-generate filters from DP labels (Kong pattern)
    filter_config = _M.labels_to_filters(dp_metadata.labels)
  end

  if not filter_config then
    return filters
  end

  if type(filter_config) == "string" then
    local ok, parsed = pcall(json_decode, filter_config)
    if ok then
      filter_config = parsed
    else
      return filters
    end
  end

  for _, filter in ipairs(filter_config) do
    if filter.type and filter.config then
      table_insert(filters, {
        type = filter.type,
        config = filter.config,
        operator = filter.operator or "AND" -- Changed to AND for security
      })
    end
  end

  return filters
end

-- Convert DP labels to filters (Kong pattern)
function _M.labels_to_filters(labels)
  if not labels then
    return nil
  end

  local auto_filters = {}

  -- Convert common label patterns to tag filters
  if labels.environment then
    table_insert(auto_filters, {
      type = "tags",
      config = {
        include = {"env:" .. labels.environment}
      }
    })
  end

  if labels.team then
    table_insert(auto_filters, {
      type = "tags",
      config = {
        include = {"team:" .. labels.team}
      }
    })
  end

  if labels.region then
    table_insert(auto_filters, {
      type = "tags",
      config = {
        include = {"region:" .. labels.region}
      }
    })
  end

  return auto_filters
end

function _M.should_sync_entity(entity, dp_filters)
  -- If no filters defined, sync everything (backward compatibility)
  if not dp_filters or #dp_filters == 0 then
    return true
  end

  -- Apply filters with OR logic between different filters
  for _, filter in ipairs(dp_filters) do
    local filter_func = DEFAULT_FILTERS[filter.type] or custom_filters[filter.type]

    if filter_func then
      local matches = filter_func(entity, filter.config)
      if matches then
        return true
      end
    end
  end

  return false
end

function _M.filter_config_for_dp(config_table, dp_filters)
  if not dp_filters or #dp_filters == 0 then
    return config_table
  end

  local filtered_config = {}

  for entity_type, entities in pairs(config_table) do
    if type(entities) == "table" then
      filtered_config[entity_type] = {}

      for _, entity in ipairs(entities) do
        -- Add entity type for filtering
        entity._entity_type = entity_type

        if _M.should_sync_entity(entity, dp_filters) then
          table_insert(filtered_config[entity_type], entity)
        end
      end

      -- Remove empty entity types
      if #filtered_config[entity_type] == 0 then
        filtered_config[entity_type] = nil
      end
    else
      -- Non-array entities (like _format_version)
      filtered_config[entity_type] = entities
    end
  end

  return filtered_config
end

function _M.calculate_filtered_hash(config_table, dp_filters)
  local filtered_config = _M.filter_config_for_dp(config_table, dp_filters)
  local calculate_config_hash = require("kong.clustering.config_helper").calculate_config_hash
  return calculate_config_hash(filtered_config)
end

-- Efficient differential sync - only send changes
function _M.calculate_dp_delta(dp_id, new_config, old_config, dp_filters)
  local filtered_new = _M.filter_config_for_dp(new_config, dp_filters)
  local filtered_old = _M.filter_config_for_dp(old_config or {}, dp_filters)

  local delta = {
    added = {},
    updated = {},
    removed = {},
  }

  -- Find additions and updates
  for entity_type, new_entities in pairs(filtered_new) do
    if type(new_entities) == "table" and #new_entities > 0 then
      local old_entities = filtered_old[entity_type] or {}
      local old_map = {}

      -- Create lookup map for old entities
      for _, entity in ipairs(old_entities) do
        if entity.id then
          old_map[entity.id] = entity
        end
      end

      delta.added[entity_type] = {}
      delta.updated[entity_type] = {}

      for _, new_entity in ipairs(new_entities) do
        if new_entity.id then
          local old_entity = old_map[new_entity.id]
          if not old_entity then
            table_insert(delta.added[entity_type], new_entity)
          elseif not _M.entities_equal(new_entity, old_entity) then
            table_insert(delta.updated[entity_type], new_entity)
          end
        end
      end

      -- Clean up empty deltas
      if #delta.added[entity_type] == 0 then
        delta.added[entity_type] = nil
      end
      if #delta.updated[entity_type] == 0 then
        delta.updated[entity_type] = nil
      end
    end
  end

  -- Find removals
  for entity_type, old_entities in pairs(filtered_old) do
    if type(old_entities) == "table" and #old_entities > 0 then
      local new_entities = filtered_new[entity_type] or {}
      local new_map = {}

      -- Create lookup map for new entities
      for _, entity in ipairs(new_entities) do
        if entity.id then
          new_map[entity.id] = true
        end
      end

      delta.removed[entity_type] = {}

      for _, old_entity in ipairs(old_entities) do
        if old_entity.id and not new_map[old_entity.id] then
          table_insert(delta.removed[entity_type], { id = old_entity.id })
        end
      end

      -- Clean up empty deltas
      if #delta.removed[entity_type] == 0 then
        delta.removed[entity_type] = nil
      end
    end
  end

  return delta
end

function _M.entities_equal(entity1, entity2)
  -- Simple comparison - in production you might want a more sophisticated approach
  local json1 = json_encode(entity1)
  local json2 = json_encode(entity2)
  return json1 == json2
end

function _M.is_delta_empty(delta)
  local function table_empty(t)
    if not t then 
      return true 
    end
    return next(t) == nil
  end

  return table_empty(delta.added) and
         table_empty(delta.updated) and
         table_empty(delta.removed)
end

-- Performance optimization: cache filtered configs per DP
local dp_config_cache = {}

function _M.get_cached_dp_config(dp_id)
  return dp_config_cache[dp_id]
end

function _M.set_cached_dp_config(dp_id, config, hash)
  dp_config_cache[dp_id] = {
    config = config,
    hash = hash,
    timestamp = ngx.time()
  }
end

function _M.clear_dp_cache(dp_id)
  if dp_id then
    dp_config_cache[dp_id] = nil
  else
    dp_config_cache = {}
  end
end

return _M
