use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
do "./t/Util.pm";

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: concurrent DP filtering stress test
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Generate test configuration
            local test_config = {services = {}, routes = {}}
            for i = 1, 500 do
                local env = (i % 4 == 0) and "staging" or ((i % 4 == 1) and "production" or ((i % 4 == 2) and "testing" or "development"))
                table.insert(test_config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    url = "http://api" .. i .. ":8080",
                    tags = {"env:" .. env, "version:v1"}
                })

                table.insert(test_config.routes, {
                    id = "route-" .. i,
                    service = {id = "service-" .. i},
                    paths = {"/api/" .. i},
                    tags = {"env:" .. env}
                })
            end

            -- Different filter sets for different DPs
            local filter_sets = {
                staging = {
                    {
                        type = "tags",
                        config = {
                            include = {"env:staging"}
                        }
                    }
                },
                production = {
                    {
                        type = "tags",
                        config = {
                            include = {"env:production"}
                        }
                    }
                },
                testing = {
                    {
                        type = "tags",
                        config = {
                            include = {"env:testing", "env:development"}
                        }
                    }
                }
            }

            local start_time = ngx.now()
            local success_count = 0
            local error_count = 0

            -- Simulate concurrent filtering for multiple DPs
            for dp_type, dp_filters in pairs(filter_sets) do
                for dp_num = 1, 10 do  -- 10 DPs per type
                    local dp_id = dp_type .. "-dp-" .. dp_num

                    local ok, result = pcall(function()
                        return filters.filter_config_for_dp(test_config, dp_filters)
                    end)

                    if ok then
                        success_count = success_count + 1
                        -- Cache the result
                        filters.set_cached_dp_config(dp_id, result, "test-hash-" .. dp_type)
                    else
                        error_count = error_count + 1
                        ngx.log(ngx.ERR, "Filtering error for ", dp_id, ": ", result)
                    end
                end
            end

            local total_time = ngx.now() - start_time
            local avg_time_per_dp = total_time / (success_count + error_count)

            ngx.say("total DPs processed: ", success_count + error_count)
            ngx.say("successful: ", success_count)
            ngx.say("errors: ", error_count)
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("avg time per DP: ", string.format("%.6f", avg_time_per_dp), "s")
            ngx.say("stress test passed: ", error_count == 0 and avg_time_per_dp < 0.1 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
total DPs processed: 30
successful: 30
errors: 0
total time: \d+\.\d{3}s
avg time per DP: 0\.\d{6}s
stress test passed: true
--- no_error_log
[error]



=== TEST 2: rapid configuration changes stress test
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

            local success_count = 0
            local error_count = 0
            local start_time = ngx.now()

            -- Simulate rapid config changes (50 iterations)
            for iteration = 1, 50 do
                local old_config = {services = {}}
                local new_config = {services = {}}

                -- Generate old config
                for i = 1, 20 do
                    table.insert(old_config.services, {
                        id = "service-" .. i,
                        name = "api-" .. i,
                        url = "http://api" .. i .. ":8080",
                        tags = {"env:staging", "iteration:" .. (iteration - 1)}
                    })
                end

                -- Generate new config (modified)
                for i = 1, 25 do -- Add 5 more services
                    table.insert(new_config.services, {
                        id = "service-" .. i,
                        name = "api-" .. i,
                        url = "http://api" .. i .. ":8080",
                        tags = {"env:staging", "iteration:" .. iteration}
                    })
                end

                local ok, result = pcall(function()
                    return filters.calculate_dp_delta("test-dp", new_config, old_config, dp_filters)
                end)

                if ok then
                    success_count = success_count + 1

                    -- Validate delta structure
                    if not result.added or not result.updated or not result.removed then
                        error_count = error_count + 1
                        ngx.log(ngx.ERR, "Invalid delta structure at iteration ", iteration)
                    end
                else
                    error_count = error_count + 1
                    ngx.log(ngx.ERR, "Delta calculation error at iteration ", iteration, ": ", result)
                end
            end

            local total_time = ngx.now() - start_time
            local avg_time_per_change = total_time / 50

            ngx.say("configuration changes: 50")
            ngx.say("successful: ", success_count)
            ngx.say("errors: ", error_count)
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("avg time per change: ", string.format("%.6f", avg_time_per_change), "s")
            ngx.say("rapid changes test passed: ", error_count == 0 and avg_time_per_change < 0.05 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
configuration changes: 50
successful: 50
errors: 0
total time: \d+\.\d{3}s
avg time per change: 0\.\d{6}s
rapid changes test passed: true
--- no_error_log
[error]



=== TEST 3: memory pressure under heavy load
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local large_config = {services = {}, routes = {}, plugins = {}}

            -- Generate very large configuration
            for i = 1, 1000 do
                local env = (i % 3 == 0) and "staging" or ((i % 3 == 1) and "production" or "testing")
                local team = (i % 2 == 0) and "platform" or "product"

                table.insert(large_config.services, {
                    id = "service-" .. i,
                    name = "api-service-" .. i,
                    url = "http://api-" .. i .. ":8080",
                    tags = {"env:" .. env, "team:" .. team, "load:heavy"}
                })

                table.insert(large_config.routes, {
                    id = "route-" .. i,
                    service = {id = "service-" .. i},
                    paths = {"/api/" .. i},
                    tags = {"env:" .. env, "load:heavy"}
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

            -- Force garbage collection and measure initial memory
            collectgarbage("collect")
            local initial_memory = collectgarbage("count")

            local start_time = ngx.now()
            local success_count = 0
            local error_count = 0

            -- Perform heavy filtering operations
            for i = 1, 30 do
                local ok, result = pcall(function()
                    return filters.filter_config_for_dp(large_config, dp_filters)
                end)

                if ok then
                    success_count = success_count + 1

                    -- Cache some results
                    if i % 5 == 0 then
                        filters.set_cached_dp_config("stress-dp-" .. i, result, "stress-hash-" .. i)
                    end
                else
                    error_count = error_count + 1
                    ngx.log(ngx.ERR, "Heavy load error at iteration ", i, ": ", result)
                end

                -- Periodic cleanup
                if i % 10 == 0 then
                    collectgarbage("collect")
                end
            end

            local total_time = ngx.now() - start_time

            -- Final memory check
            collectgarbage("collect")
            local final_memory = collectgarbage("count")
            local memory_increase = final_memory - initial_memory

            ngx.say("heavy load operations: 30")
            ngx.say("successful: ", success_count)
            ngx.say("errors: ", error_count)
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("initial memory: ", string.format("%.1f", initial_memory), "KB")
            ngx.say("final memory: ", string.format("%.1f", final_memory), "KB")
            ngx.say("memory increase: ", string.format("%.1f", memory_increase), "KB")
            ngx.say("memory pressure test passed: ", error_count == 0 and memory_increase < 500 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
heavy load operations: 30
successful: 30
errors: 0
total time: \d+\.\d{3}s
initial memory: \d+\.\d+KB
final memory: \d+\.\d+KB
memory increase: \d+\.\d+KB
memory pressure test passed: true
--- no_error_log
[error]



=== TEST 4: cache invalidation under stress
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local base_config = {services = {}}
            for i = 1, 100 do
                table.insert(base_config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    url = "http://api" .. i .. ":8080",
                    tags = {"env:staging", "version:v1"}
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
            local cache_hits = 0
            local cache_misses = 0
            local invalidations = 0

            -- Stress test with cache operations
            for iteration = 1, 100 do
                local dp_id = "stress-dp-" .. (iteration % 20) -- 20 different DPs

                -- Try to get from cache first
                local cached_result = filters.get_cached_dp_config(dp_id)

                if cached_result then
                    cache_hits = cache_hits + 1
                else
                    cache_misses = cache_misses + 1

                    -- Filter and cache new result
                    local filtered = filters.filter_config_for_dp(base_config, dp_filters)
                    filters.set_cached_dp_config(dp_id, filtered, "stress-hash-" .. iteration)
                end

                -- Randomly invalidate cache to simulate config changes
                if iteration % 10 == 0 then
                    local dp_to_invalidate = "stress-dp-" .. ((iteration / 10) % 20)
                    filters.invalidate_dp_cache(dp_to_invalidate)
                    invalidations = invalidations + 1
                end

                -- Occasionally clear all cache
                if iteration % 50 == 0 then
                    filters.clear_dp_cache()
                    invalidations = invalidations + 1
                end
            end

            local total_time = ngx.now() - start_time
            local cache_hit_ratio = cache_hits / (cache_hits + cache_misses)

            ngx.say("cache operations: 100")
            ngx.say("cache hits: ", cache_hits)
            ngx.say("cache misses: ", cache_misses)
            ngx.say("invalidations: ", invalidations)
            ngx.say("hit ratio: ", string.format("%.2f", cache_hit_ratio))
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("cache stress test passed: ", cache_hit_ratio > 0.3 and total_time < 1.0 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
cache operations: 100
cache hits: \d+
cache misses: \d+
invalidations: \d+
hit ratio: 0\.\d{2}
total time: \d+\.\d{3}s
cache stress test passed: true
--- no_error_log
[error]



=== TEST 5: complex filter combinations stress
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Generate complex configuration
            local complex_config = {
                services = {},
                routes = {},
                plugins = {},
                consumers = {}
            }

            for i = 1, 200 do
                local env = (i % 4 == 0) and "staging" or ((i % 4 == 1) and "production" or ((i % 4 == 2) and "testing" or "development"))
                local team = (i % 3 == 0) and "platform" or ((i % 3 == 1) and "product" or "infrastructure")
                local region = (i % 2 == 0) and "us-west" or "us-east"

                table.insert(complex_config.services, {
                    id = "service-" .. i,
                    name = "api-" .. i,
                    url = "http://api" .. i .. ":8080",
                    tags = {"env:" .. env, "team:" .. team, "region:" .. region}
                })

                table.insert(complex_config.routes, {
                    id = "route-" .. i,
                    service = {id = "service-" .. i},
                    paths = {"/api/" .. i},
                    tags = {"env:" .. env, "region:" .. region}
                })

                table.insert(complex_config.plugins, {
                    id = "plugin-" .. i,
                    name = "rate-limiting",
                    service = {id = "service-" .. i},
                    tags = {"env:" .. env}
                })

                table.insert(complex_config.consumers, {
                    id = "consumer-" .. i,
                    username = "user-" .. i,
                    tags = {"env:" .. env, "team:" .. team}
                })
            end

            -- Complex filter combinations
            local complex_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging", "team:platform"},
                        exclude = {"region:us-east"}
                    }
                },
                {
                    type = "workspace",
                    config = {
                        include = {"default"}
                    }
                }
            }

            local start_time = ngx.now()
            local success_count = 0
            local error_count = 0

            -- Test complex filtering multiple times
            for i = 1, 20 do
                local ok, result = pcall(function()
                    return filters.filter_config_for_dp(complex_config, complex_filters)
                end)

                if ok then
                    success_count = success_count + 1

                    -- Validate filtered result has expected structure
                    if not result.services or not result.routes or not result.plugins or not result.consumers then
                        error_count = error_count + 1
                        ngx.log(ngx.ERR, "Missing entity types in filtered result at iteration ", i)
                    end
                else
                    error_count = error_count + 1
                    ngx.log(ngx.ERR, "Complex filtering error at iteration ", i, ": ", result)
                end
            end

            local total_time = ngx.now() - start_time
            local avg_time = total_time / 20

            ngx.say("complex filter operations: 20")
            ngx.say("successful: ", success_count)
            ngx.say("errors: ", error_count)
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("avg time per operation: ", string.format("%.6f", avg_time), "s")
            ngx.say("complex filter stress passed: ", error_count == 0 and avg_time < 0.1 and "true" or "false")
        }
    }
--- request
GET /t
--- response_body_like
complex filter operations: 20
successful: 20
errors: 0
total time: \d+\.\d{3}s
avg time per operation: 0\.\d{6}s
complex filter stress passed: true
--- no_error_log
[error]



=== TEST 6: edge case resilience under stress
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local success_count = 0
            local error_count = 0
            local start_time = ngx.now()

            -- Test various edge cases under stress
            local edge_cases = {
                -- Empty config
                {
                    config = {services = {}, routes = {}, plugins = {}},
                    filters = {{type = "tags", config = {include = {"env:staging"}}}}
                },
                -- Empty filters
                {
                    config = {services = {{id = "1", name = "test", tags = {"env:staging"}}}},
                    filters = {}
                },
                -- Invalid filter type (should be handled gracefully)
                {
                    config = {services = {{id = "1", name = "test", tags = {"env:staging"}}}},
                    filters = {{type = "invalid_type", config = {include = {"env:staging"}}}}
                },
                -- Missing tags
                {
                    config = {services = {{id = "1", name = "test"}}},
                    filters = {{type = "tags", config = {include = {"env:staging"}}}}
                },
                -- Very long tag names
                {
                    config = {
                        services = {{
                            id = "1",
                            name = "test",
                            tags = {"very_long_tag_name_that_exceeds_normal_length_" .. string.rep("x", 100)}
                        }}
                    },
                    filters = {{type = "tags", config = {include = {"very_long_tag_name_that_exceeds_normal_length_" .. string.rep("x", 100)}}}}
                }
            }

            -- Run each edge case multiple times
            for case_num, case_data in ipairs(edge_cases) do
                for iteration = 1, 10 do
                    local ok, result = pcall(function()
                        return filters.filter_config_for_dp(case_data.config, case_data.filters)
                    end)

                    if ok then
                        success_count = success_count + 1

                        -- Validate result structure
                        if type(result) ~= "table" then
                            error_count = error_count + 1
                            ngx.log(ngx.ERR, "Invalid result type for case ", case_num, " iteration ", iteration)
                        end
                    else
                        error_count = error_count + 1
                        ngx.log(ngx.ERR, "Edge case error - case ", case_num, " iteration ", iteration, ": ", result)
                    end
                end
            end

            local total_time = ngx.now() - start_time
            local total_operations = #edge_cases * 10

            ngx.say("edge case operations: ", total_operations)
            ngx.say("successful: ", success_count)
            ngx.say("errors: ", error_count)
            ngx.say("total time: ", string.format("%.3f", total_time), "s")
            ngx.say("error rate: ", string.format("%.1f", (error_count / total_operations) * 100), "%")
            ngx.say("edge case resilience passed: ", error_count <= 1 and "true" or "false") -- Allow 1 error for invalid filter type
        }
    }
--- request
GET /t
--- response_body_like
edge case operations: 50
successful: \d+
errors: \d+
total time: \d+\.\d{3}s
error rate: \d+\.\d+%
edge case resilience passed: true
--- no_error_log
[error]
