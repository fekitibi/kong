-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local typedefs = require "kong.db.schema.typedefs"
local utils = require "kong.tools.utils"
local normalize_ip = require("kong.tools.ip").normalize_ip


local function validate_target(target)
  local p = normalize_ip(target)
  if not p then
    local ok = utils.validate_utf8(target)
    if not ok then
      return nil, "Invalid target; not a valid hostname or ip address"
    end

    return nil, "Invalid target ('" .. target .. "'); not a valid hostname or ip address"
  end
  return true
end


return {
  name = "targets",
  dao = "kong.db.dao.targets",
  primary_key = { "id" },
  cache_key = { "upstream", "target" },
  endpoint_key = "target",
  workspaceable = true,
  fields = {
    { id = typedefs.uuid },
    { created_at = typedefs.auto_timestamp_ms },
    { updated_at = typedefs.auto_timestamp_ms },
    { upstream   = { description = "The unique identifier or the name of the upstream for which to update the target.", type = "foreign", reference = "upstreams", required = true, on_delete = "cascade" }, },
    { target     = { description = "The target address (ip or hostname) and port.", type = "string", required = true, custom_validator = validate_target, }, },
    { weight     = { description = "The weight this target gets within the upstream loadbalancer (0-65535).", type = "integer", default = 100, between = { 0, 65535 }, }, },
    { tags       = typedefs.tags },
  },
}
