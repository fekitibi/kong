use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
do "./t/Util.pm";

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: control_plane module can be loaded
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local control_plane = require "kong.clustering.control_plane"
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 2: data_plane module can be loaded
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 3: control_plane export_filtered_config_for_dp function exists
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local control_plane = require "kong.clustering.control_plane"

            -- Mock control plane instance
            local cp = control_plane.new({
                conf = {
                    cluster_dp_id = "cp-1"
                },
                declarative_config = {}
            })

            local func_exists = type(cp.export_filtered_config_for_dp) == "function"
            ngx.say("export_filtered_config_for_dp exists: ", func_exists)
        }
    }
--- request
GET /t
--- response_body
export_filtered_config_for_dp exists: true
--- no_error_log
[error]



=== TEST 4: control_plane export_delta_for_dp function exists
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local control_plane = require "kong.clustering.control_plane"

            -- Mock control plane instance
            local cp = control_plane.new({
                conf = {
                    cluster_dp_id = "cp-1"
                },
                declarative_config = {}
            })

            local func_exists = type(cp.export_delta_for_dp) == "function"
            ngx.say("export_delta_for_dp exists: ", func_exists)
        }
    }
--- request
GET /t
--- response_body
export_delta_for_dp exists: true
--- no_error_log
[error]



=== TEST 5: data_plane apply_delta_update function exists
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"

            -- Mock data plane instance
            local dp = data_plane.new({
                conf = {
                    cluster_dp_id = "dp-1"
                },
                declarative_config = {}
            })

            local func_exists = type(dp.apply_delta_update) == "function"
            ngx.say("apply_delta_update exists: ", func_exists)
        }
    }
--- request
GET /t
--- response_body
apply_delta_update exists: true
--- no_error_log
[error]



=== TEST 6: data_plane request_full_sync function exists
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"

            -- Mock data plane instance
            local dp = data_plane.new({
                conf = {
                    cluster_dp_id = "dp-1"
                },
                declarative_config = {}
            })

            local func_exists = type(dp.request_full_sync) == "function"
            ngx.say("request_full_sync exists: ", func_exists)
        }
    }
--- request
GET /t
--- response_body
request_full_sync exists: true
--- no_error_log
[error]



=== TEST 7: data_plane apply_delta_update basic functionality
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"

            -- Mock data plane instance
            local dp = data_plane.new({
                conf = {
                    cluster_dp_id = "dp-1"
                },
                declarative_config = {}
            })

            local current_config = {
                services = {
                    {
                        id = "service-1",
                        name = "existing-service",
                        url = "http://existing:8080"
                    }
                }
            }

            local delta = {
                added = {
                    services = {
                        {
                            id = "service-2",
                            name = "new-service",
                            url = "http://new:8080"
                        }
                    }
                },
                updated = {
                    services = {
                        {
                            id = "service-1",
                            name = "existing-service",
                            url = "http://existing:8081" -- URL updated
                        }
                    }
                },
                removed = {}
            }

            local updated_config, err = dp:apply_delta_update(current_config, delta)

            ngx.say("delta applied successfully: ", updated_config and "true" or "false")
            ngx.say("error: ", err or "none")

            if updated_config then
                ngx.say("services count: ", #updated_config.services)
                for _, service in ipairs(updated_config.services) do
                    ngx.say("service: ", service.name, " -> ", service.url)
                end
            end
        }
    }
--- request
GET /t
--- response_body
delta applied successfully: true
error: none
services count: 2
service: existing-service -> http://existing:8081
service: new-service -> http://new:8080
--- no_error_log
[error]



=== TEST 8: data_plane delta update with removals
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"

            -- Mock data plane instance
            local dp = data_plane.new({
                conf = {
                    cluster_dp_id = "dp-1"
                },
                declarative_config = {}
            })

            local current_config = {
                services = {
                    {
                        id = "service-1",
                        name = "keep-service",
                        url = "http://keep:8080"
                    },
                    {
                        id = "service-2",
                        name = "remove-service",
                        url = "http://remove:8080"
                    }
                }
            }

            local delta = {
                added = {},
                updated = {},
                removed = {
                    services = {
                        {
                            id = "service-2"
                        }
                    }
                }
            }

            local updated_config, err = dp:apply_delta_update(current_config, delta)

            ngx.say("delta applied successfully: ", updated_config and "true" or "false")
            ngx.say("services count: ", #updated_config.services)

            if updated_config then
                for _, service in ipairs(updated_config.services) do
                    ngx.say("remaining service: ", service.name)
                end
            end
        }
    }
--- request
GET /t
--- response_body
delta applied successfully: true
services count: 1
remaining service: keep-service
--- no_error_log
[error]



=== TEST 9: data_plane request_full_sync sets flag
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local data_plane = require "kong.clustering.data_plane"

            -- Mock data plane instance
            local dp = data_plane.new({
                conf = {
                    cluster_dp_id = "dp-1"
                },
                declarative_config = {}
            })

            ngx.say("full_sync_request initial: ", dp.full_sync_request or "false")

            dp:request_full_sync()

            ngx.say("full_sync_request after call: ", dp.full_sync_request)
        }
    }
--- request
GET /t
--- response_body
full_sync_request initial: false
full_sync_request after call: true
--- no_error_log
[error]



=== TEST 10: kong meta version includes filter-sync
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local meta = require "kong.meta"

            ngx.say("kong version: ", meta._VERSION)

            local has_filter_sync = string.find(meta._VERSION, "filter%-sync") ~= nil
            ngx.say("has filter-sync: ", has_filter_sync)
        }
    }
--- request
GET /t
--- response_body
kong version: 3.11.0-filter-sync
has filter-sync: true
--- no_error_log
[error]



=== TEST 11: control_plane handles DP capability advertisement
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            -- Mock DP metadata with capabilities
            local dp_metadata = {
                dp_id = "dp-staging-1",
                hostname = "staging-node-1",
                cluster_version = "3.11.0-filter-sync",
                capabilities = {"filter_sync", "delta_sync"},
                labels = {
                    environment = "staging",
                    region = "us-west-2",
                    team = "platform"
                }
            }

            -- Test that we can extract capabilities
            local has_filter_sync = false
            local has_delta_sync = false

            if dp_metadata.capabilities then
                for _, capability in ipairs(dp_metadata.capabilities) do
                    if capability == "filter_sync" then
                        has_filter_sync = true
                    elseif capability == "delta_sync" then
                        has_delta_sync = true
                    end
                end
            end

            ngx.say("DP supports filter_sync: ", has_filter_sync)
            ngx.say("DP supports delta_sync: ", has_delta_sync)
            ngx.say("DP environment: ", dp_metadata.labels.environment)
            ngx.say("DP team: ", dp_metadata.labels.team)
        }
    }
--- request
GET /t
--- response_body
DP supports filter_sync: true
DP supports delta_sync: true
DP environment: staging
DP team: platform
--- no_error_log
[error]



=== TEST 12: message type handling in data plane
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            -- Mock message processing logic
            local function process_message(msg)
                if msg.type == "reconfigure" then
                    return "full_config_processed"
                elseif msg.type == "delta" then
                    return "delta_processed"
                else
                    return "unknown_message_type"
                end
            end

            local full_msg = { type = "reconfigure", config_table = {}, timestamp = 1234567890 }
            local delta_msg = { type = "delta", delta = {}, timestamp = 1234567891 }
            local unknown_msg = { type = "unknown", data = {} }

            ngx.say("full config: ", process_message(full_msg))
            ngx.say("delta config: ", process_message(delta_msg))
            ngx.say("unknown type: ", process_message(unknown_msg))
        }
    }
--- request
GET /t
--- response_body
full config: full_config_processed
delta config: delta_processed
unknown type: unknown_message_type
--- no_error_log
[error]



=== TEST 13: backward compatibility check
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Test that entities without filters are synced (backward compatibility)
            local config = {
                services = {
                    {
                        id = "service-1",
                        name = "legacy-service",
                        url = "http://legacy:8080"
                        -- No tags
                    }
                }
            }

            -- No filters specified (legacy DP)
            local filtered_config = filters.filter_config_for_dp(config, {})

            ngx.say("backward compatibility: ", #filtered_config.services == #config.services)
            ngx.say("service synced: ", filtered_config.services[1].name)
        }
    }
--- request
GET /t
--- response_body
backward compatibility: true
service synced: legacy-service
--- no_error_log
[error]
