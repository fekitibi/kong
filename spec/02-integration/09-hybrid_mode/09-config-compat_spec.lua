-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local helpers = require "spec.helpers"
local utils = require "kong.tools.utils"
local cjson = require "cjson"
local func = require "pl.func"
local tablex = require "pl.tablex"
local CLUSTERING_SYNC_STATUS = require("kong.constants").CLUSTERING_SYNC_STATUS

local admin = require "spec.fixtures.admin_api"

local CP_HOST = "127.0.0.1"
local CP_PORT = 9005

local PLUGIN_LIST


local function cluster_client(opts)
  opts = opts or {}
  local res, err = helpers.clustering_client({
    host = CP_HOST,
    port = CP_PORT,
    cert = "spec/fixtures/kong_clustering.crt",
    cert_key = "spec/fixtures/kong_clustering.key",
    node_hostname = opts.hostname or "test",
    node_id = opts.id or utils.uuid(),
    node_version = opts.version,
    node_plugins_list = PLUGIN_LIST,
  })

  assert.is_nil(err)
  return res
end

local function get_entity(entity_type, node_id, node_version, name, allow_nil)
  allow_nil = allow_nil or false
  local res, err = cluster_client({ id = node_id, version = node_version })
  assert.is_nil(err)
  assert.is_table(res and res.config_table and res.config_table[entity_type .. 's'],
                  "invalid response from clustering client")

  local entity
  for _, e in ipairs(res.config_table[entity_type .. 's']) do
    if e.name == name then
      entity = e
      break
    end
  end

  if not allow_nil then
    assert.not_nil(entity, entity_type .. " " .. name .. " not found in config")
  end
  return entity
end


local get_plugin = func.bind1(get_entity, "plugin")
local get_vault = func.bind1(get_entity, "vault")


local function get_sync_status(id)
  local status
  local admin_client = helpers.admin_client()

  helpers.wait_until(function()
    local res = admin_client:get("/clustering/data-planes")
    local body = assert.res_status(200, res)

    local json = cjson.decode(body)

    for _, v in pairs(json.data) do
      if v.id == id then
        status = v.sync_status
        return true
      end
    end
  end, 5, 0.5)

  admin_client:close()

  return status
end


for _, strategy in helpers.each_strategy() do

describe("CP/DP config compat transformations #" .. strategy, function()
  local cg_id
  lazy_setup(function()
    local bp = helpers.get_db_utils(strategy, {
      "routes",
      "services",
      "consumer_groups",
      "vaults",
    })

    PLUGIN_LIST = helpers.get_plugins_list()

    bp.routes:insert {
      name = "compat.test",
      hosts = { "compat.test" },
      service = bp.services:insert {
        name = "compat.test",
      }
    }

    local cg = assert(bp.consumer_groups:insert {
      name = "test_group"
    })
    cg_id = cg.id

    assert(helpers.start_kong({
      role = "control_plane",
      cluster_cert = "spec/fixtures/kong_clustering.crt",
      cluster_cert_key = "spec/fixtures/kong_clustering.key",
      database = strategy,
      db_update_frequency = 0.1,
      cluster_listen = CP_HOST .. ":" .. CP_PORT,
      nginx_conf = "spec/fixtures/custom_nginx.template",
      plugins = "bundled",
      vaults = "gcp,hcv,aws",
    }))
  end)

  lazy_teardown(function()
    helpers.stop_kong()
  end)

  describe("plugin config fields", function()
    local rate_limit, response_transformer, cors, opentelemetry, zipkin

    lazy_setup(function()
      response_transformer = admin.plugins:insert {
        name = "response-transformer",
        enabled = true,
        -- This should not be present in 3.3
        consumer_group = {
          id = cg_id,
        },
        config = { },
      }

      cors = admin.plugins:insert {
        name = "cors",
        enabled = true,
        config = {
          -- [[ new fields 3.5.0
          private_network = false
          -- ]]
        }
      }
    end)

    lazy_teardown(function()
      admin.plugins:remove({ id = rate_limit.id })
    end)

    local function do_assert(node_id, node_version, expected_entity)
      local plugin = get_plugin(node_id, node_version, expected_entity.name)
      assert.same(expected_entity.config, plugin.config)
      assert.equals(CLUSTERING_SYNC_STATUS.NORMAL, get_sync_status(node_id))
    end

    it("removes new fields before sending them to older DP nodes", function()
      rate_limit = admin.plugins:insert {
        name = "rate-limiting",
        enabled = true,
        config = {
          second = 1,
          policy = "redis",
          redis = {
            host = "localhost"
          },

          -- [[ new fields
          error_code = 403,
          error_message = "go away!",
          sync_rate = -1,
          -- ]]
        },
      }

      --[[
        For 3.0.x
        should not have: error_code, error_message, sync_rate
      --]]
      local expected = utils.cycle_aware_deep_copy(rate_limit)
      expected.config.redis = nil
      expected.config.error_code = nil
      expected.config.error_message = nil
      expected.config.sync_rate = nil
      do_assert(utils.uuid(), "3.0.0", expected)


      --[[
        For 3.2.x
        should have: error_code, error_message
        should not have: sync_rate
      --]]
      expected = utils.cycle_aware_deep_copy(rate_limit)
      expected.config.redis = nil
      expected.config.sync_rate = nil
      do_assert(utils.uuid(), "3.2.0", expected)


      --[[
        For 3.3.x,
        should have: error_code, error_message
        should not have: sync_rate
      --]]
      expected = utils.cycle_aware_deep_copy(rate_limit)
      expected.config.redis = nil
      expected.config.sync_rate = nil
      do_assert(utils.uuid(), "3.3.0", expected)

      -- cleanup
      admin.plugins:remove({ id = rate_limit.id })
    end)

    it("does not remove fields from DP nodes that are already compatible", function()
      rate_limit = admin.plugins:insert {
        name = "rate-limiting",
        enabled = true,
        config = {
          second = 1,
          policy = "redis",
          redis = {
            host = "localhost"
          },

          -- [[ new fields
          error_code = 403,
          error_message = "go away!",
          sync_rate = -1,
          -- ]]
        },
      }

      local expected = utils.cycle_aware_deep_copy(rate_limit)
      expected.config.redis = nil
      do_assert(utils.uuid(), "3.4.0", expected)

      -- cleanup
      admin.plugins:remove({ id = rate_limit.id })
    end)

    it("consumer_group scoped plugins should not be present in 3.3 dataplanes", function()
      local id = utils.uuid()
      local plugin = get_plugin(id, "3.3.0", response_transformer.name, true)
      assert.is_nil(plugin)
      assert.equals(CLUSTERING_SYNC_STATUS.NORMAL, get_sync_status(id))
    end)

    it("consumer_group scoped plugins should be present in 3.4 dataplanes", function()
      local id = utils.uuid()
      local plugin = get_plugin(id, "3.4.0", response_transformer.name, true)
      assert.is_not_nil(plugin)
      assert.same(response_transformer.config, plugin.config)
      assert.equals(CLUSTERING_SYNC_STATUS.NORMAL, get_sync_status(id))
    end)

    it("plugins with inherit `nil` consumer-group should be present in 3.4 dataplanes", function()
      rate_limit = admin.plugins:insert {
        name = "rate-limiting",
        enabled = true,
        config = {
          second = 1,
          policy = "redis",
          redis = {
            host = "localhost"
          },

          -- [[ new fields
          error_code = 403,
          error_message = "go away!",
          sync_rate = -1,
          -- ]]
        },
      }

      local expected = utils.cycle_aware_deep_copy(rate_limit)
      expected.config.redis = nil
      do_assert(utils.uuid(), "3.4.0", expected)

      -- cleanup
      admin.plugins:remove({ id = rate_limit.id })
    end)

    describe("compatibility test for cors plugin", function()
      it("removes `config.private_network` before sending them to older(less than 3.4.3.5) DP nodes", function()
        assert.not_nil(cors.config.private_network)
        local expected_cors = utils.cycle_aware_deep_copy(cors)
        expected_cors.config.private_network = nil
        do_assert(utils.uuid(), "3.4.3.3", expected_cors)
      end)

      it("does not remove `config.private_network` from DP nodes that are already compatible", function()
        do_assert(utils.uuid(), "3.4.3.6", cors)
      end)
    end)

    describe("compatibility tests for opentelemetry plugin", function()
      it("replaces `aws` values of `header_type` property with default `preserve`", function()
        -- [[ 3.5.x ]] --
        opentelemetry = admin.plugins:insert {
          name = "opentelemetry",
          enabled = true,
          config = {
            endpoint = "http://1.1.1.1:12345/v1/trace",
            -- [[ new value 3.5.0
            header_type = "gcp"
            -- ]]
          }
        }

        local expected_otel_prior_35 = utils.cycle_aware_deep_copy(opentelemetry)
        expected_otel_prior_35.config.header_type = "preserve"
        expected_otel_prior_35.config.sampling_rate = nil
        expected_otel_prior_35.config.propagation = nil
        do_assert(utils.uuid(), "3.4.0", expected_otel_prior_35)

        -- cleanup
        admin.plugins:remove({ id = opentelemetry.id })

        -- [[ 3.4.x ]] --
        opentelemetry = admin.plugins:insert {
          name = "opentelemetry",
          enabled = true,
          config = {
            endpoint = "http://1.1.1.1:12345/v1/trace",
            -- [[ new value 3.4.0
            header_type = "aws"
            -- ]]
          }
        }

        local expected_otel_prior_34 = utils.cycle_aware_deep_copy(opentelemetry)
        expected_otel_prior_34.config.header_type = "preserve"
        expected_otel_prior_34.config.sampling_rate = nil
        expected_otel_prior_34.config.propagation = nil
        do_assert(utils.uuid(), "3.3.0", expected_otel_prior_34)

        -- cleanup
        admin.plugins:remove({ id = opentelemetry.id })
      end)

    end)

    describe("compatibility tests for zipkin plugin", function()
      it("replaces `aws` and `gcp` values of `header_type` property with default `preserve`", function()
        -- [[ 3.5.x ]] --
        zipkin = admin.plugins:insert {
          name = "zipkin",
          enabled = true,
          config = {
            http_endpoint = "http://1.1.1.1:12345/v1/trace",
            -- [[ new value 3.5.0
            header_type = "gcp"
            -- ]]
          }
        }

        local expected_zipkin_prior_35 = utils.cycle_aware_deep_copy(zipkin)
        expected_zipkin_prior_35.config.header_type = "preserve"
        expected_zipkin_prior_35.config.default_header_type = "b3"
        expected_zipkin_prior_35.config.propagation = nil
        do_assert(utils.uuid(), "3.4.0", expected_zipkin_prior_35)

        -- cleanup
        admin.plugins:remove({ id = zipkin.id })

        -- [[ 3.4.x ]] --
        zipkin = admin.plugins:insert {
          name = "zipkin",
          enabled = true,
          config = {
            http_endpoint = "http://1.1.1.1:12345/v1/trace",
            -- [[ new value 3.4.0
            header_type = "aws"
            -- ]]
          }
        }

        local expected_zipkin_prior_34 = utils.cycle_aware_deep_copy(zipkin)
        expected_zipkin_prior_34.config.header_type = "preserve"
        expected_zipkin_prior_34.config.default_header_type = "b3"
        expected_zipkin_prior_34.config.propagation = nil
        do_assert(utils.uuid(), "3.3.0", expected_zipkin_prior_34)

        -- cleanup
        admin.plugins:remove({ id = zipkin.id })
      end)
    end)

    describe("compatibility tests for redis standarization", function()
      describe("acme plugin", function()
        it("translates standardized redis config to older acme structure", function()
          -- [[ 3.6.x ]] --
          local acme = admin.plugins:insert {
            name = "acme",
            enabled = true,
            config = {
              account_email = "test@example.com",
              storage = "redis",
              storage_config = {
                -- [[ new structure redis
                redis = {
                  host = "localhost",
                  port = 57198,
                  username = "test",
                  password = "secret",
                  database = 2,
                  timeout = 1100,
                  ssl = true,
                  ssl_verify = true,
                  server_name = "example.test",
                  extra_options = {
                    namespace = "test_namespace",
                    scan_count = 13
                  }
                }
                -- ]]
              }
            }
          }

          local expected_acme_prior_36 = utils.cycle_aware_deep_copy(acme)
          expected_acme_prior_36.config.storage_config.redis = {
            host = "localhost",
            port = 57198,
            auth = "secret",
            database = 2,
            ssl = true,
            ssl_verify = true,
            ssl_server_name = "example.test",
            namespace = "test_namespace",
            scan_count = 13
          }
          do_assert(utils.uuid(), "3.5.0", expected_acme_prior_36)

          -- cleanup
          admin.plugins:remove({ id = acme.id })
        end)
      end)

      describe("rate-limiting plugin", function()
        it("translates standardized redis config to older rate-limiting structure", function()
          -- [[ 3.6.x ]] --
          rate_limit = admin.plugins:insert {
            name = "rate-limiting",
            enabled = true,
            config = {
              minute = 300,
              policy = "redis",
              -- [[ new structure redis
              redis = {
                  host = "localhost",
                  port = 57198,
                  username = "test",
                  password = "secret",
                  database = 2,
                  timeout = 1100,
                  ssl = true,
                  ssl_verify = true,
                  server_name = "example.test"
              }
              -- ]]
            }
          }

          local expected_rl_prior_36 = utils.cycle_aware_deep_copy(rate_limit)
          expected_rl_prior_36.config.redis = nil
          expected_rl_prior_36.config.redis_host = "localhost"
          expected_rl_prior_36.config.redis_port = 57198
          expected_rl_prior_36.config.redis_username = "test"
          expected_rl_prior_36.config.redis_password = "secret"
          expected_rl_prior_36.config.redis_database = 2
          expected_rl_prior_36.config.redis_timeout = 1100
          expected_rl_prior_36.config.redis_ssl = true
          expected_rl_prior_36.config.redis_ssl_verify = true
          expected_rl_prior_36.config.redis_server_name = "example.test"


          do_assert(utils.uuid(), "3.5.0", expected_rl_prior_36)

          -- cleanup
          admin.plugins:remove({ id = rate_limit.id })
        end)
      end)

      describe("response-ratelimiting plugin", function()
        it("translates standardized redis config to older response-ratelimiting structure", function()
          -- [[ 3.6.x ]] --
          local response_rl = admin.plugins:insert {
            name = "response-ratelimiting",
            enabled = true,
            config = {
              limits = {
                video = {
                  minute = 300,
                }
              },
              policy = "redis",
              -- [[ new structure redis
              redis = {
                host = "localhost",
                port = 57198,
                username = "test",
                password = "secret",
                database = 2,
                timeout = 1100,
                ssl = true,
                ssl_verify = true,
                server_name = "example.test"
              }
              -- ]]
            }
          }

          local expected_response_rl_prior_36 = utils.cycle_aware_deep_copy(response_rl)
          expected_response_rl_prior_36.config.redis = nil
          expected_response_rl_prior_36.config.redis_host = "localhost"
          expected_response_rl_prior_36.config.redis_port = 57198
          expected_response_rl_prior_36.config.redis_username = "test"
          expected_response_rl_prior_36.config.redis_password = "secret"
          expected_response_rl_prior_36.config.redis_database = 2
          expected_response_rl_prior_36.config.redis_timeout = 1100
          expected_response_rl_prior_36.config.redis_ssl = true
          expected_response_rl_prior_36.config.redis_ssl_verify = true
          expected_response_rl_prior_36.config.redis_server_name = "example.test"


          do_assert(utils.uuid(), "3.5.0", expected_response_rl_prior_36)

          -- cleanup
          admin.plugins:remove({ id = response_rl.id })
        end)
      end)
    end)
  end)

  -- fixme: azure not tested (test needs to be added when it azure is added)
  for _, vault_name in pairs({"gcp", "hcv", "aws"}) do
    describe("vault #" .. vault_name, function()
      local vault_configs = {
        gcp = { project_id = "the-project-id" },
        hcv = { token = "the-token" },
        aws = { }
      }

      lazy_setup(function()
        admin.vaults:insert {
          name = vault_name,
          prefix = "my-" .. vault_name .. "-vault",
          config = tablex.merge(vault_configs[vault_name], { ttl = 1, resurrect_ttl = 1, neg_ttl = 1 }, true),
        }
      end)

      it("ttl parameters should be present in 3.4 dataplanes", function()
        local id = utils.uuid()
        local transformed_vault = get_vault(id, "3.4.0", vault_name, true)
        assert.is_not_nil(transformed_vault)
        assert.is_not_nil(transformed_vault.config.ttl)
        assert.is_not_nil(transformed_vault.config.neg_ttl)
        assert.is_not_nil(transformed_vault.config.resurrect_ttl)
        assert.equals(CLUSTERING_SYNC_STATUS.NORMAL, get_sync_status(id))
      end)

      it("ttl parameters should not be present in 3.3 dataplanes", function()
        local id = utils.uuid()
        local transformed_vault = get_vault(id, "3.3.0", vault_name, true)
        assert.is_not_nil(transformed_vault)
        assert.is_nil(transformed_vault.config.ttl)
        assert.is_nil(transformed_vault.config.neg_ttl)
        assert.is_nil(transformed_vault.config.resurrect_ttl)
        assert.equals(CLUSTERING_SYNC_STATUS.NORMAL, get_sync_status(id))
      end)
    end)
  end
end)

end -- each strategy
