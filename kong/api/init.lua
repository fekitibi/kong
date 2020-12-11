-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local lapis       = require "lapis"
local utils       = require "kong.tools.utils"
local singletons  = require "kong.singletons"
local api_helpers = require "kong.api.api_helpers"
local Endpoints   = require "kong.api.endpoints"
local hooks       = require "kong.hooks"


local ngx      = ngx
local type     = type
local pairs    = pairs
local ipairs   = ipairs


local app = lapis.Application()


app.default_route = api_helpers.default_route
app.handle_404 = api_helpers.handle_404
app.handle_error = api_helpers.handle_error
app:before_filter(api_helpers.before_filter)


assert(hooks.run_hook("api:init:pre", app))


ngx.log(ngx.DEBUG, "Loading Admin API endpoints")


-- Load core routes
for _, v in ipairs({"kong", "health", "cache", "config", }) do
  local routes = require("kong.api.routes." .. v)
  api_helpers.attach_routes(app, routes)
end


-- Load custom DB routes
for _, v in ipairs({"clustering", }) do
  local routes = require("kong.api.routes." .. v)
  api_helpers.attach_new_db_routes(app, routes)
end


do
  -- This function takes the auto-generated routes and then customizes them
  -- based on custom_endpoints. It will add one argument to actual function
  -- call `parent` that the customized function can use to call the original
  -- auto-generated function.
  --
  -- E.g. the `/routes/:routes` API gets autogenerated from `routes` DAO.
  -- Now if your plugin adds `api.lua` that also defines the same endpoint:
  -- `/routes/:routes`, it means that the plugin one overrides the original
  -- function. Original is kept and passed to the customized function as an
  -- function argument (of course usually plugins want to only customize
  -- the autogenerated endpoints the plugin's own DAOs introduced).
  local function customize_routes(routes, custom_endpoints, schema)
    for route_pattern, verbs in pairs(custom_endpoints) do
      if type(verbs) == "table" then
        local methods = verbs.methods or verbs

        if routes[route_pattern] == nil then
          routes[route_pattern] = {
            schema  = verbs.schema or schema,
            methods = methods
          }

        else
          for method, handler in pairs(methods) do
            local parent = routes[route_pattern]["methods"][method]
            if parent ~= nil and type(handler) == "function" then
              routes[route_pattern]["methods"][method] = function(self, db, helpers)
                return handler(self, db, helpers, function(post_process)
                  return parent(self, db, helpers, post_process)
                end)
              end

            else
              routes[route_pattern]["methods"][method] = handler
            end
          end
        end
      end
    end
  end

  local routes = {}

  -- DAO Routes
  for _, dao in pairs(singletons.db.daos) do
    if dao.schema.generate_admin_api ~= false and not dao.schema.legacy then
      routes = Endpoints.new(dao.schema, routes)
    end
  end

  -- Custom Routes
  for _, dao in pairs(singletons.db.daos) do
    local schema = dao.schema
    local ok, custom_endpoints = utils.load_module_if_exists("kong.api.routes." .. schema.name)
    if ok then
      customize_routes(routes, custom_endpoints, schema)
    end
  end

  -- Plugin Routes
  if singletons.configuration and singletons.configuration.loaded_plugins then
    for k in pairs(singletons.configuration.loaded_plugins) do
      local loaded, custom_endpoints = utils.load_module_if_exists("kong.plugins." .. k .. ".api")
      if loaded then
        ngx.log(ngx.DEBUG, "Loading API endpoints for plugin: ", k)
        if api_helpers.is_new_db_routes(custom_endpoints) then
          customize_routes(routes, custom_endpoints, custom_endpoints.schema)

        else
          api_helpers.attach_routes(app, custom_endpoints)
        end

      else
        ngx.log(ngx.DEBUG, "No API endpoints loaded for plugin: ", k)
      end
    end
  end

  assert(hooks.run_hook("api:init:post", app, routes))

  api_helpers.attach_new_db_routes(app, routes)
end

return app
