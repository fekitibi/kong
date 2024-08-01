-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local helpers = require "spec.helpers"
local cjson = require "cjson.safe"
local fmt = string.format
local http = require("resty.http")

local split = require "kong.tools.string".split
local buffer = require("string.buffer")

local PLUGIN_NAME = "ai-semantic-caching"
local MOCK_PORT = helpers.get_available_port()

local vectordb = require("kong.llm.vectordb")

local REDIS_HOST = helpers.redis_host
local REDIS_PORT = tonumber(os.getenv("KONG_SPEC_TEST_REDIS_STACK_PORT") or 16379)

local MOCK_FIXTURE = [[
  server {
    server_name llm;
    listen ]]..MOCK_PORT..[[;

    default_type 'application/json';

    location = "/good" {
      content_by_lua_block {
        local pl_file = require "pl.file"
        local json = require("cjson.safe")
        ngx.req.read_body()
        
        local body, err = ngx.req.get_body_data()
        body, err = json.decode(body)

        local token = ngx.req.get_headers()["authorization"]

        if err then
          ngx.status = 400
          ngx.print("bad request somehow")
        end

        if body.model == "text-embedding-3-large" and token == "Bearer openai-key" then
          ngx.status = 200
          ngx.print(pl_file.read("spec-ee/fixtures/ai-proxy/embeddings/response/good.json"))
        else
          ngx.status = 401
          ngx.print(pl_file.read("spec-ee/fixtures/ai-proxy/embeddings/response/unauthorized.json"))
        end
      }
    }

    location = "/bad" {
      content_by_lua_block {
        local pl_file = require "pl.file"
        local json = require("cjson.safe")
        ngx.req.read_body()
        
        local body, err = ngx.req.get_body_data()
        body, err = json.decode(body)
        if err then
          ngx.status = 400
          ngx.print("bad request somehow")
        end

        if body.model == "text-embedding-3-large" then
          ngx.status = 200
          ngx.print(pl_file.read("spec-ee/fixtures/ai-proxy/embeddings/response/bad.json"))
        else
          ngx.status = 401
          ngx.print(pl_file.read("spec-ee/fixtures/ai-proxy/embeddings/response/unauthorized.json"))
        end
      }
    }
  }
]]

local function wait_until_key_in_cache(vector_connector, key)
  -- wait until key is in cache (we get a 200 on plugin API) and execute
  -- a test function if provided.
  helpers.wait_until(function()
    local res, err = vector_connector:keys(key)

    -- wait_until does not like asserts
    if not res or err then return false end

    if #res < 1 then
      return false
    end

    return res
  end, 5)
end

local PRE_FUNCTION_ACCESS_SCRIPT = [[
  local pl_file = require("pl.file")
  local cjson = require("cjson.safe")

  local original_request = cjson.decode(pl_file.read("spec-ee/fixtures/ai-proxy/chat/request/%s.json"))
  kong.ctx.shared.ai_proxy_original_request = original_request

  if kong.request.get_header("x-test-stream-mode") and kong.request.get_header("x-test-stream-mode") == "true" then
    original_request.stream = true
    kong.ctx.shared.ai_proxy_original_request.stream = true
  end

  if (%s) then
    kong.ctx.shared.ai_stream_full_text = pl_file.read("spec-ee/fixtures/ai-proxy/chat/request/%s-stream.txt")
  else
    kong.ctx.shared.parsed_response = pl_file.read("spec-ee/fixtures/ai-proxy/chat/response/%s.json")
  end
]]

local PRE_FUNCTION_HEADER_FILTER_SCRIPT = [[
  if (%s) then
    kong.response.set_header("Content-Type", "text/event-stream")
  end
]]


local COMPATIBLE_VECTORDB = {
  "redis",
}

local COMPATIBLE_EMBEDDINGS = {
  "openai",
}

local DIMENSIONS_LOOKUP = {
  ["good"] = 3072,
  ["bad_too_few_dimensions"] = 256,
  ["bad_unauthorized"] = 3072,
}

local TEST_SCANARIOS = {
  { id = "97a884ab-5b8f-442a-8011-89dce47a68b6", desc = "good caching",                 vector_config = "good", embeddings_config = "good",                   embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 200 },
  { id = "4819bbfb-7669-4d7d-a7b8-1c60dc71d2a8", desc = "stream request rest response", vector_config = "good", embeddings_config = "good",                   embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 200, stream_request = true },
  { id = "e73873a3-aec5-429d-b36d-8cfc6bcaed3a", desc = "rest request stream response", vector_config = "good", embeddings_config = "good",                   embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 200, stream_response = true },
  { id = "ee2b67b2-b766-46f4-b718-af5811f0e365", desc = "good caching short countback", vector_config = "good", embeddings_config = "good",                   embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 1,  expect = 200 },
  { id = "802b9c2d-efd3-4cdf-b141-4a8f4886b3f8", desc = "bad too few dimensions",       vector_config = "good", embeddings_config = "bad_too_few_dimensions", embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 400 },
  { id = "ad7c8591-415a-49f4-8ae2-b36c3522fa0a", desc = "bad vectordb configuration",   vector_config = "bad",  embeddings_config = "good",                   embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 400 },
  { id = "8d89e29e-76ee-4ba7-83a3-eb1c6157877a", desc = "bad embeddings configuration", vector_config = "good", embeddings_config = "bad_unauthorized",       embeddings_response = "good", chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 400 },
  { id = "ea9513a1-6c5a-44f2-b60f-df083c1b036b", desc = "bad embeddings response",      vector_config = "good", embeddings_config = "good",                   embeddings_response = "bad",  chat_request = "good", chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 400 },
  { id = "43df7fd8-6c1e-4ff4-902f-84a655196679", desc = "bad inference request",        vector_config = "good", embeddings_config = "good",                   embeddings_response = "good", chat_request = "bad",  chat_response = "good", stop_on_failure = true, message_countback = 10, expect = 400 },
}

for _, strategy in helpers.all_strategies() do if strategy ~= "cassandra" then
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    -- setup
    local proxy_client

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME, "pre-function" })

      -- set up openai mock fixtures
      local fixtures = {
        http_mock = {},
      }
      fixtures.http_mock.llm = MOCK_FIXTURE

      for _, VECTORDB_STRATEGY in ipairs(COMPATIBLE_VECTORDB) do
        for _, EMBEDDINGS_STRATEGY in ipairs(COMPATIBLE_EMBEDDINGS) do
          for _, TEST_SCENARIO in ipairs(TEST_SCANARIOS) do
            local rt = assert(bp.routes:insert {
              protocols = { "http" },
              strip_path = true,
              paths = { fmt("/%s/%s/%s", VECTORDB_STRATEGY, EMBEDDINGS_STRATEGY, TEST_SCENARIO.id) }
            })
            bp.plugins:insert {
              name = "pre-function",
              route = { id = rt.id },
              config = {
                access = {
                  [1] = fmt(PRE_FUNCTION_ACCESS_SCRIPT, TEST_SCENARIO.chat_request, TEST_SCENARIO.stream_request, TEST_SCENARIO.chat_request, TEST_SCENARIO.chat_response),
                },
                header_filter = {
                  [1] = fmt(PRE_FUNCTION_HEADER_FILTER_SCRIPT, TEST_SCENARIO.stream_request),
                },
              },
            }
            bp.plugins:insert {
              name = PLUGIN_NAME,
              id = TEST_SCENARIO.id,
              route = { id = rt.id },
              config = {
                message_countback = TEST_SCENARIO.message_countback or 10,
                ignore_assistant_prompts = true,
                ignore_system_prompts = true,
                stop_on_failure = TEST_SCENARIO.stop_on_failure or true,
                embeddings = {
                  auth = {
                    token = TEST_SCENARIO.embeddings_config == "bad_unauthorized" and "wrong-key" or "openai-key",
                  },
                  driver = "openai",
                  model = "text-embedding-3-large",
                  upstream_url = "http://"..helpers.mock_upstream_host..":"..MOCK_PORT.."/" .. TEST_SCENARIO.embeddings_response,
                },
                vectordb = {
                  strategy = VECTORDB_STRATEGY,
                  dimensions = DIMENSIONS_LOOKUP[TEST_SCENARIO.embeddings_config],
                  distance_metric = "cosine",
                  threshold = 0.7,
                  redis = VECTORDB_STRATEGY == "redis" and {
                    host = TEST_SCENARIO.vector_config == "good" and REDIS_HOST or "wrong.local",
                    port = REDIS_PORT,  -- use the "other" redis, that includes RediSearch
                  } or {},
                },
              },
            }
          end -- end for each TEST SCENARIO
        end -- end for each EMBEDDINGS
      end -- end for each VECTORDB

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME .. ",pre-function",
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
        -- let me read test files
        untrusted_lua_sandbox_requires = "pl.file,cjson.safe"
      }, nil, nil, fixtures))
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)

    before_each(function()
      proxy_client = helpers.proxy_client()
    end)

    after_each(function()
      if proxy_client then proxy_client:close() end
    end)

    -- run
    for _, VECTORDB_STRATEGY in ipairs(COMPATIBLE_VECTORDB) do
      for _, EMBEDDINGS_STRATEGY in ipairs(COMPATIBLE_EMBEDDINGS) do
          for _, TEST_SCENARIO in ipairs(TEST_SCANARIOS) do

            it("[#" .. VECTORDB_STRATEGY.. "] [#" .. EMBEDDINGS_STRATEGY .. "] " .. TEST_SCENARIO.desc, function()
              -- clear the vectordb for this test
              -- it has to run in here, because we can't get the plugin config from the before_each function
              local vector_connector = vectordb.new(VECTORDB_STRATEGY, fmt("kong_semantic_cache:%s", TEST_SCENARIO.id), {
                strategy = VECTORDB_STRATEGY,
                dimensions = DIMENSIONS_LOOKUP[TEST_SCENARIO.embeddings_config],
                distance_metric = "cosine",
                threshold = 0.7,
                redis = VECTORDB_STRATEGY == "redis" and {
                  host = REDIS_HOST,
                  port = REDIS_PORT,  -- use the "other" redis, that includes RediSearch
                } or {},
              })

              vector_connector:drop_index(true)
 
              local r = proxy_client:get(fmt("/%s/%s/%s", VECTORDB_STRATEGY, EMBEDDINGS_STRATEGY, TEST_SCENARIO.id), {
                headers = {
                  ["content-type"] = "application/json",
                  ["accept"] = "application/json",
                },
              })

              if TEST_SCENARIO.expect == 200 then
                assert.res_status(200 , r)
                local x_cache_status = assert.header("X-Cache-Status", r)
                assert.equals("Miss", x_cache_status)

              elseif TEST_SCENARIO.expect == 400 then
                if TEST_SCENARIO.embeddings_config == "bad_too_few_dimensions" then
                  local body = assert.res_status(400 , r)
                  body = cjson.decode(body)

                  assert.equal(body.message, "Embedding dimensions do not match the configured vector database")
                else
                  assert.res_status(400 , r)
                end

                return
              end

              wait_until_key_in_cache(vector_connector, "kong_semantic_cache:" .. TEST_SCENARIO.id .. ":*")

              -- read again, should be cached now
              if TEST_SCENARIO.stream_response then
                local httpc = http.new()

                local ok, err, _ = httpc:connect({
                  scheme = "http",
                  host = helpers.get_proxy_ip(),
                  port = helpers.get_proxy_port(),
                })
                if not ok then
                  assert.is_nil(err)
                end

                -- Then send using `request`, supplying a path and `Host` header instead of a
                -- full URI.
                local res, err = httpc:request({
                    path = fmt("/%s/%s/%s", VECTORDB_STRATEGY, EMBEDDINGS_STRATEGY, TEST_SCENARIO.id),
                    headers = {
                      ["content-type"] = "application/json",
                      ["accept"] = "text/event-stream",
                      ["x-test-stream-mode"] = "true",
                    },
                })
                if not res then
                  assert.is_nil(err)
                end

                local reader = res.body_reader
                local buffer_size = 35536
                local events = {}
                local buf = buffer.new()

                -- extract event
                repeat
                  -- receive next chunk
                  local buffer, err = reader(buffer_size)
                  if err then
                    assert.is_falsy(err and err ~= "closed")
                  end

                  if buffer then
                    -- we need to rip each message from this chunk
                    for s in buffer:gmatch("[^\r\n]+") do
                      local s_copy = s
                      s_copy = string.sub(s_copy,7)
                      s_copy, err = cjson.decode(s_copy)

                      if not err then  -- ignore [DONE] and other comment markers
                        buf:put(s_copy
                              and s_copy.choices
                              and s_copy.choices
                              and s_copy.choices[1]
                              and s_copy.choices[1].delta
                              and s_copy.choices[1].delta.content
                              or "")

                        table.insert(events, s)
                      end
                    end
                  end
                until not buffer

                assert.equal(#events, 2)  -- there's always 2 events in this setup, because we put the WHOLE response in one frame
                assert.equal(string.sub(buf:get(), 0, 30), "A train is a mode of transport")
              else
                local r = proxy_client:get(fmt("/%s/%s/%s", VECTORDB_STRATEGY, EMBEDDINGS_STRATEGY, TEST_SCENARIO.id), {
                  headers = {
                    ["content-type"] = "application/json",
                    ["accept"] = "application/json",
                  },
                })

                if TEST_SCENARIO.expect == 200 then
                  assert.res_status(200 , r)
                  local x_cache_status = assert.header("X-Cache-Status", r)
                  local x_cache_ttl = assert.header("X-Cache-Ttl", r)
                  local x_cache_key = assert.header("X-Cache-Key", r)
                  assert.equals("Hit", x_cache_status)
                  assert.equals("300", x_cache_ttl)
                  assert.equals("kong_semantic_cache", split(x_cache_key, ":")[1])
                elseif TEST_SCENARIO.expect == 400 then
                  assert.res_status(400 , r)
                end
              end
            end)

          end -- end for each TEST SCENARIO

      end -- end for each EMBEDDINGS
    end -- end for each VECTORDB
  end)
end end -- end for each db_strategy, end if not cassandra
