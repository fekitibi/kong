use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
do "./t/Util.pm";

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: large configuration filtering performance
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Generate large configuration
            local large_config = {
                services = {},
                routes = {},
                plugins = {}
            }

            for i = 1, 1000 do
                local env = (i % 3 == 0) and "staging" or ((i % 3 == 1) and "production" or "testing")
                local team = (i % 2 == 0) and "platform" or "product"

                table.insert(large_config.services, {
                    id = "service-" .. i,
                    name = "api-service-" .. i,
                    url = "http://api-" .. i .. ":8080",
                    tags = {"env:" .. env, "team:" .. team}
                })

                table.insert(large_config.routes, {
                    id = "route-" .. i,
                    service = {id = "service-" .. i},
                    paths = {"/api/" .. i},
                    tags = {"env:" .. env}
                })

                table.insert(large_config.plugins, {
                    id = "plugin-" .. i,
                    name = "rate-limiting",
                    service = {id = "service-" .. i},
                    tags = {"env:" .. env}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            local start_time = ngx.now()
            local filtered_config = filters.filter_config_for_dp(large_config, dp_filters)
            local filter_time = ngx.now() - start_time

            ngx.say("original services: ", #large_config.services)
            ngx.say("filtered services: ", #filtered_config.services)
            ngx.say("filter time: ", string.format("%.3f", filter_time), "s")
            ngx.say("performance acceptable: ", filter_time < 0.1 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
original services: 1000
filtered services: \d+
filter time: 0\.\d{3}s
performance acceptable: true
--- no_error_log
[error]



=== TEST 2: delta calculation performance
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Generate old config (500 services)
            local old_config = {services = {}}
            for i = 1, 500 do
                local env = (i % 2 == 0) and "staging" or "production"
                table.insert(old_config.services, {
                    id = "service-" .. i,
                    name = "api-service-" .. i,
                    url = "http://api-" .. i .. ":8080",
                    tags = {"env:" .. env}
                })
            end

            -- Generate new config (1000 services)
            local new_config = {services = {}}
            for i = 1, 1000 do
                local env = (i % 2 == 0) and "staging" or "production"
                table.insert(new_config.services, {
                    id = "service-" .. i,
                    name = "api-service-" .. i,
                    url = "http://api-" .. i .. ":8080",
                    tags = {"env:" .. env}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            local start_time = ngx.now()
            local delta = filters.calculate_dp_delta("test-dp", new_config, old_config, dp_filters)
            local delta_time = ngx.now() - start_time

            ngx.say("delta calculation time: ", string.format("%.3f", delta_time), "s")
            ngx.say("performance acceptable: ", delta_time < 0.2 and "true" or "false")
            ngx.say("added services: ", delta.added.services and #delta.added.services or 0)
        }
    }
--- request
GET /t
--- response_body_like
delta calculation time: 0\.\d{3}s
performance acceptable: true
added services: \d+
--- no_error_log
[error]



=== TEST 3: caching performance improvement
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Generate test config
            local test_config = {services = {}}
            for i = 1, 100 do
                table.insert(test_config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    url = "http://api" .. i .. ":8080",
                    tags = {"env:staging"}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            -- First call (no cache)
            local start_time = ngx.now()
            local result1 = filters.filter_config_for_dp(test_config, dp_filters)
            local first_call_time = ngx.now() - start_time

            -- Cache the result
            filters.set_cached_dp_config("test-dp", result1, "test-hash")

            -- Second call using cache
            start_time = ngx.now()
            local cached_result = filters.get_cached_dp_config("test-dp")
            local cache_call_time = ngx.now() - start_time

            local speedup = first_call_time / cache_call_time

            ngx.say("first call time: ", string.format("%.6f", first_call_time), "s")
            ngx.say("cache call time: ", string.format("%.6f", cache_call_time), "s")
            ngx.say("speedup: ", string.format("%.1f", speedup), "x")
            ngx.say("cache effective: ", speedup > 10 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
first call time: 0\.\d{6}s
cache call time: 0\.\d{6}s
speedup: \d+\.\d+x
cache effective: true
--- no_error_log
[error]



=== TEST 4: memory usage stability
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local test_config = {services = {}}
            for i = 1, 50 do
                table.insert(test_config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    url = "http://api" .. i .. ":8080",
                    tags = {"env:staging"}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            -- Get initial memory
            collectgarbage("collect")
            local initial_memory = collectgarbage("count")

            -- Perform many filtering operations
            for i = 1, 100 do
                local filtered = filters.filter_config_for_dp(test_config, dp_filters)

                -- Occasionally clear cache
                if i % 20 == 0 then
                    filters.clear_dp_cache()
                end
            end

            -- Check final memory
            collectgarbage("collect")
            local final_memory = collectgarbage("count")
            local memory_increase = final_memory - initial_memory

            ngx.say("initial memory: ", string.format("%.1f", initial_memory), "KB")
            ngx.say("final memory: ", string.format("%.1f", final_memory), "KB")
            ngx.say("memory increase: ", string.format("%.1f", memory_increase), "KB")
            ngx.say("memory stable: ", memory_increase < 100 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
initial memory: \d+\.\d+KB
final memory: \d+\.\d+KB
memory increase: \d+\.\d+KB
memory stable: true
--- no_error_log
[error]



=== TEST 5: bandwidth reduction validation
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"
            local cjson = require "cjson"

            -- Generate mixed environment config
            local large_config = {services = {}}
            for i = 1, 300 do
                local env = (i % 3 == 0) and "staging" or ((i % 3 == 1) and "production" or "testing")
                table.insert(large_config.services, {
                    id = "service-" .. i,
                    name = "api-service-" .. i,
                    url = "http://api-" .. i .. ":8080",
                    tags = {"env:" .. env, "team:platform"}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            -- Calculate sizes
            local full_config_json = cjson.encode(large_config)
            local full_size = #full_config_json

            local filtered_config = filters.filter_config_for_dp(large_config, dp_filters)
            local filtered_config_json = cjson.encode(filtered_config)
            local filtered_size = #filtered_config_json

            local reduction_percent = (1 - (filtered_size / full_size)) * 100

            ngx.say("full config size: ", full_size, " bytes")
            ngx.say("filtered config size: ", filtered_size, " bytes")
            ngx.say("reduction: ", string.format("%.1f", reduction_percent), "%")
            ngx.say("significant reduction: ", reduction_percent > 50 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
full config size: \d+ bytes
filtered config size: \d+ bytes
reduction: \d+\.\d+%
significant reduction: true
--- no_error_log
[error]



=== TEST 6: scalability test - linear performance
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            local times = {}
            local sizes = {100, 200, 400}

            for _, size in ipairs(sizes) do
                local config = {services = {}}

                -- Generate config of specified size
                for i = 1, size do
                    local env = (i % 2 == 0) and "staging" or "production"
                    table.insert(config.services, {
                        id = "service-" .. i,
                        name = "api-" .. i,
                        url = "http://api" .. i .. ":8080",
                        tags = {"env:" .. env}
                    })
                end

                -- Measure filtering time
                local start_time = ngx.now()
                filters.filter_config_for_dp(config, dp_filters)
                local filter_time = ngx.now() - start_time

                times[size] = filter_time
                ngx.say("size ", size, ": ", string.format("%.6f", filter_time), "s")
            end

            -- Check scaling
            local scaling_ratio = times[400] / times[100]
            ngx.say("scaling ratio (400/100): ", string.format("%.1f", scaling_ratio), "x")
            ngx.say("reasonable scaling: ", scaling_ratio < 5 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
size 100: 0\.\d{6}s
size 200: 0\.\d{6}s
size 400: 0\.\d{6}s
scaling ratio \(400/100\): \d+\.\d+x
reasonable scaling: true
--- no_error_log
[error]



=== TEST 7: empty delta performance
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local config = {services = {}}
            for i = 1, 200 do
                table.insert(config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    tags = {"env:staging"}
                })
            end

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            -- Calculate delta with same config (should be empty)
            local start_time = ngx.now()
            local delta = filters.calculate_dp_delta("test-dp", config, config, dp_filters)
            local delta_time = ngx.now() - start_time

            local is_empty = filters.is_delta_empty(delta)

            ngx.say("delta calculation time: ", string.format("%.6f", delta_time), "s")
            ngx.say("delta is empty: ", is_empty)
            ngx.say("fast empty delta: ", delta_time < 0.01 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
delta calculation time: 0\.\d{6}s
delta is empty: true
fast empty delta: true
--- no_error_log
[error]
