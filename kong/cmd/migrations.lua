-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local DB = require "kong.db"
local log = require "kong.cmd.utils.log"
local tty = require "kong.cmd.utils.tty"
local meta = require "kong.meta"
local conf_loader = require "kong.conf_loader"
local kong_global = require "kong.global"
local prefix_handler = require "kong.cmd.utils.prefix_handler"
local migrations_utils = require "kong.cmd.utils.migrations"


local fmt = string.format

local function list_fields(db, tname)

  local qs = {
    postgres = function()
      return fmt("SELECT column_name FROM information_schema.columns WHERE table_schema='%s' and table_name='%s';",
        db.connector.config.schema,
        tname)
    end,
    cassandra = function()
      -- Handle schema system tables and column name differences between Apache
      -- Cassandra version
      if db.connector.major_version >= 3 then
        return fmt("SELECT column_name FROM system_schema.columns WHERE keyspace_name='%s' and table_name='%s';",
          db.connector.keyspace,
          tname)
      else
        return fmt("SELECT column_name FROM system.schema_columns WHERE keyspace_name='%s' and columnfamily_name='%s';",
          db.connector.keyspace,
          tname)
      end
    end,
    off = function()
      return setmetatable({}, {
        __index = function()
          return true
      end})
    end,
  }

  if not qs[db.strategy] then
    return {}
  end

  local fields = {}
  local rows, err = db.connector:query(qs[db.strategy]())

  if err then
    return nil, err
  end
  for _, v in ipairs(rows) do
    local _,vv = next(v)
    fields[vv]=true
  end

  return fields
end

local function has_ws_id_in_db(db, tname)
  return list_fields(db, tname).ws_id
end

local function migrate_table(db, conf, tname)
  if db.daos[tname] then
    local schema = db.daos[tname].schema
    local has_ws_id = has_ws_id_in_db(db, schema.name)
    if schema.workspaceable and not has_ws_id then
      local fks = {}
      local uniques = {}

      for field_name, field_schema in pairs(schema.fields) do
        if field_schema.unique then
          table.insert(uniques, field_name)
        elseif field_schema.type == "foreign" then
          table.insert(fks, {
            name = field_name,
            reference = field_schema.reference,
            on_delete = field_schema.on_delete,
          })
        end
      end

      local data = {
        name = schema.name,
        primary_key = schema.primary_key[1],
        uniques = uniques,
        fks = fks,
      }
      print(fmt([[
Table %s is workspaceable but hasn't been migrated. Follow the migrations path in:
https://docs.konghq.com/enterprise/2.1.x/deployment/upgrades/custom-changes/

Here's the temptative autogenerated migration file

---------8<---------
local operations = require "kong.enterprise_edition.db.migrations.operations.1500_to_2100"

local plugin_entities = {%s}

return operations.ws_migrate_plugin(plugin_entities)
---------8<---------
]], schema.name, require("inspect")(data)))
    else
      error(fmt("table %s is%sworkspaceable and%sws_id field.",
        tname,
        schema.workspaceable and " " or " not ",
        has_ws_id and " has already " or " doesn't have "))
    end
  else
    error(fmt("table %s doesn't exist", tname))
  end
end


local lapp = [[
Usage: kong migrations COMMAND [OPTIONS]

Manage database schema migrations.

The available commands are:
  bootstrap                         Bootstrap the database and run all
                                    migrations.

  up                                Run any new migrations.

  finish                            Finish running any pending migrations after
                                    'up'.

  list                              List executed migrations.

  reset                             Reset the database.

  migrate-community-to-enterprise   Migrates CE entities to EE on the default
                                    workspace

  upgrade-workspace-table           Outputs a script to be run on the db to upgrade
                                    the entity for 2.x workspaces implementation


  reinitialize-workspace-entity-counters  Resets the entity counters from the
                                          database entities.

Options:
 -y,--yes                           Assume "yes" to prompts and run
                                    non-interactively.

 -q,--quiet                         Suppress all output.

 -f,--force                         Run migrations even if database reports
                                    as already executed.

                                    With 'migrate-community-to-enterprise' it
                                    disables the workspace entities check.

 --db-timeout     (default 60)      Timeout, in seconds, for all database
                                    operations (including schema consensus for
                                    Cassandra).

 --lock-timeout   (default 60)      Timeout, in seconds, for nodes waiting on
                                    the leader node to finish running
                                    migrations.

 -c,--conf        (optional string) Configuration file.

]]


local function confirm_prompt(q)
  local MAX = 3
  local ANSWERS = {
    y = true,
    Y = true,
    yes = true,
    YES = true,
    n = false,
    N = false,
    no = false,
    NO = false
  }

  while MAX > 0 do
    io.write("> " .. q .. " [Y/n] ")
    local a = io.read("*l")
    if ANSWERS[a] ~= nil then
      return ANSWERS[a]
    end
    MAX = MAX - 1
  end
end


local function execute(args)
  args.db_timeout = args.db_timeout * 1000
  args.lock_timeout = args.lock_timeout

  if args.quiet then
    log.disable()
  end

  local conf = assert(conf_loader(args.conf))

  package.path = conf.lua_package_path .. ";" .. package.path

  conf.pg_timeout = args.db_timeout -- connect + send + read

  conf.cassandra_timeout = args.db_timeout -- connect + send + read
  conf.cassandra_schema_consensus_timeout = args.db_timeout

  assert(prefix_handler.prepare_prefix(conf, args.nginx_conf))

  _G.kong = kong_global.new()
  kong_global.init_pdk(_G.kong, conf, nil) -- nil: latest PDK

  local db = assert(DB.new(conf))
  assert(db:init_connector())

  if args.command == "bootstrap" then -- Needs to be here cause
                                      -- schema_state loads the
                                      -- ops/200_to_210 file
    kong.bootstrapping = true
  end

  local schema_state = assert(db:schema_state())

  if args.command == "list" then
    if schema_state.needs_bootstrap then
      log(migrations_utils.NEEDS_BOOTSTRAP_MSG)
      os.exit(3)
    end

    local r = ""

    if schema_state.executed_migrations then
      log("Executed migrations:\n%s", schema_state.executed_migrations)
      r = "\n"
    end

    if schema_state.pending_migrations then
      log("%sPending migrations:\n%s", r, schema_state.pending_migrations)
      r = "\n"
    end

    if schema_state.new_migrations then
      log("%sNew migrations available:\n%s", r, schema_state.new_migrations)
      r = "\n"
    end

    if schema_state.pending_migrations and schema_state.new_migrations then
      if r ~= "" then
        log("")
      end

      log.warn("Database has pending migrations from a previous upgrade, " ..
               "and new migrations from this upgrade (version %s)",
               tostring(meta._VERSION))

      log("\nRun 'kong migrations finish' when ready to complete pending " ..
          "migrations (%s %s will be incompatible with the previous Kong " ..
          "version)", db.strategy, db.infos.db_desc)

      os.exit(4)
    end

    if schema_state.needs_bootstrap then
      os.exit(3)
    end

    if schema_state.pending_migrations then
      log("\nRun 'kong migrations finish' when ready")
      os.exit(4)
    end

    if schema_state.new_migrations then
      log("\nRun 'kong migrations up' to proceed")
      os.exit(5)
    end

    -- exit(0)

  elseif args.command == "bootstrap" then
    if args.force then
      migrations_utils.reset(schema_state, db, args.lock_timeout)
      schema_state = assert(db:schema_state())
    end
    migrations_utils.bootstrap(schema_state, db, args.lock_timeout)

  elseif args.command == "reset" then
    if not args.yes then
      if not tty.isatty() then
        error("not a tty: invoke 'reset' non-interactively with the --yes flag")
      end

      if not schema_state.needs_bootstrap and
        not confirm_prompt("Are you sure? This operation is irreversible.") then
        log("cancelled")
        return
      end
    end

    local ok = migrations_utils.reset(schema_state, db, args.lock_timeout)
    if not ok then
      os.exit(1)
    end
    os.exit(0)

  elseif args.command == "up" then
    migrations_utils.up(schema_state, db, {
      ttl = args.lock_timeout,
      force = args.force,
      abort = true, -- exit the mutex if another node acquired it
    })

  elseif args.command == "finish" then
    migrations_utils.finish(schema_state, db, {
      ttl = args.lock_timeout,
      force = args.force,
    })

  elseif args.command == "migrate-community-to-enterprise" then
    if not args.yes then
      if not tty.isatty() then
        error("not a tty: invoke 'reset' non-interactively with the --yes flag")
      end

      if not confirm_prompt("Are you sure? This operation is irreversible." ..
                          " Confirm you have a backup of your production data") then
        log("cancelled")
        return
      end
    end

    local _, err = migrations_utils.migrate_core_entities(schema_state, db, {
      conf = conf,
      ttl = args.lock_timeout,
      force = args.force,
    })
    if err then
      error(err)
    end

  elseif args.command == "upgrade-workspace-table" then
    local tname = table.remove(args, 1)
    if tname then
      db.plugins:load_plugin_schemas(conf.loaded_plugins)
      migrate_table(db, conf, tname)
    else
      error("upgrade-workspace-table needs an existing non-migrated table name")
    end

  elseif args.command == "reinitialize-workspace-entity-counters" then
    local counters = require "kong.workspaces.counters"
    db.plugins:load_plugin_schemas(conf.loaded_plugins)
    kong.db=db
    counters.initialize_counters(db)

  else
    error("unreachable")
  end
end


return {
  lapp = lapp,
  execute = execute,
  sub_commands = {
    bootstrap = true,
    up = true,
    finish = true,
    list = true,
    reset = true,
    ["migrate-community-to-enterprise"] = true,
    ["reinitialize-workspace-entity-counters"]=true,
    ["upgrade-workspace-table"]=true,
  }
}
