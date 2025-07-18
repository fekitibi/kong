use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
do "./t/Util.pm";

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: filters module can be loaded
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"
            ngx.say("ok")
        }
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]



=== TEST 2: tag_matches function - exact match
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local result1 = filters.tag_matches("env:production", "env:production")
            local result2 = filters.tag_matches("env:production", "env:staging")

            ngx.say("exact match: ", result1)
            ngx.say("no match: ", result2)
        }
    }
--- request
GET /t
--- response_body
exact match: true
no match: false
--- no_error_log
[error]



=== TEST 3: tag_matches function - wildcard match
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local result1 = filters.tag_matches("env:production", "env:*")
            local result2 = filters.tag_matches("env:staging", "env:*")
            local result3 = filters.tag_matches("team:platform", "env:*")

            ngx.say("wildcard match 1: ", result1)
            ngx.say("wildcard match 2: ", result2)
            ngx.say("wildcard no match: ", result3)
        }
    }
--- request
GET /t
--- response_body
wildcard match 1: true
wildcard match 2: true
wildcard no match: false
--- no_error_log
[error]



=== TEST 4: tag_matches function - prefix match
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local result1 = filters.tag_matches("env:production", "env:")
            local result2 = filters.tag_matches("env:staging", "env:")
            local result3 = filters.tag_matches("team:platform", "env:")

            ngx.say("prefix match 1: ", result1)
            ngx.say("prefix match 2: ", result2)
            ngx.say("prefix no match: ", result3)
        }
    }
--- request
GET /t
--- response_body
prefix match 1: true
prefix match 2: true
prefix no match: false
--- no_error_log
[error]



=== TEST 5: parse_dp_filters from labels
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local dp_metadata = {
                dp_id = "test-dp",
                labels = {
                    environment = "staging",
                    team = "platform",
                    region = "us-west"
                }
            }

            local parsed_filters = filters.parse_dp_filters(dp_metadata)

            ngx.say("filter count: ", #parsed_filters)
            for i, filter in ipairs(parsed_filters) do
                ngx.say("filter ", i, " type: ", filter.type)
                if filter.config.include then
                    for j, tag in ipairs(filter.config.include) do
                        ngx.say("  include: ", tag)
                    end
                end
            end
        }
    }
--- request
GET /t
--- response_body
filter count: 3
filter 1 type: tags
  include: env:staging
filter 2 type: tags
  include: team:platform
filter 3 type: tags
  include: region:us-west
--- no_error_log
[error]



=== TEST 6: filter_config_for_dp basic filtering
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local config = {
                services = {
                    {
                        id = "service-1",
                        name = "staging-api",
                        url = "http://staging:8080",
                        tags = {"env:staging", "team:platform"}
                    },
                    {
                        id = "service-2",
                        name = "prod-api",
                        url = "http://prod:8080",
                        tags = {"env:production", "team:platform"}
                    },
                    {
                        id = "service-3",
                        name = "global-api",
                        url = "http://global:8080"
                        -- No tags = global
                    }
                }
            }

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            local filtered_config = filters.filter_config_for_dp(config, dp_filters)

            ngx.say("original services: ", #config.services)
            ngx.say("filtered services: ", #filtered_config.services)

            for _, service in ipairs(filtered_config.services) do
                ngx.say("service: ", service.name)
            end
        }
    }
--- request
GET /t
--- response_body
original services: 3
filtered services: 2
service: staging-api
service: global-api
--- no_error_log
[error]



=== TEST 7: should_sync_entity with no filters (backward compatibility)
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local entity = {
                id = "service-1",
                name = "test-service",
                tags = {"env:production"}
            }

            local result = filters.should_sync_entity(entity, {})

            ngx.say("sync without filters: ", result)
        }
    }
--- request
GET /t
--- response_body
sync without filters: true
--- no_error_log
[error]



=== TEST 8: service-specific filtering
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local config = {
                services = {
                    {
                        id = "svc-1",
                        name = "api-service",
                        url = "http://api:8080"
                    },
                    {
                        id = "svc-2",
                        name = "auth-service",
                        url = "http://auth:8080"
                    },
                    {
                        id = "svc-3",
                        name = "payment-service",
                        url = "http://payment:8080"
                    }
                }
            }

            local dp_filters = {
                {
                    type = "service",
                    config = {
                        names = {"api-service", "payment-service"}
                    }
                }
            }

            local filtered_config = filters.filter_config_for_dp(config, dp_filters)

            ngx.say("filtered services: ", #filtered_config.services)
            for _, service in ipairs(filtered_config.services) do
                ngx.say("service: ", service.name)
            end
        }
    }
--- request
GET /t
--- response_body
filtered services: 2
service: api-service
service: payment-service
--- no_error_log
[error]



=== TEST 9: workspace filtering
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local config = {
                services = {
                    {
                        id = "svc-1",
                        name = "prod-service",
                        url = "http://prod:8080",
                        ws_id = "production"
                    },
                    {
                        id = "svc-2",
                        name = "dev-service",
                        url = "http://dev:8080",
                        ws_id = "development"
                    },
                    {
                        id = "svc-3",
                        name = "default-service",
                        url = "http://default:8080"
                        -- No workspace = default
                    }
                }
            }

            local dp_filters = {
                {
                    type = "workspace",
                    config = {
                        workspaces = {"production", "default"}
                    }
                }
            }

            local filtered_config = filters.filter_config_for_dp(config, dp_filters)

            ngx.say("filtered services: ", #filtered_config.services)
            for _, service in ipairs(filtered_config.services) do
                ngx.say("service: ", service.name)
            end
        }
    }
--- request
GET /t
--- response_body
filtered services: 2
service: prod-service
service: default-service
--- no_error_log
[error]



=== TEST 10: delta calculation
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local old_config = {
                services = {
                    {
                        id = "service-1",
                        name = "api-service",
                        url = "http://api:8080",
                        tags = {"env:staging"}
                    }
                }
            }

            local new_config = {
                services = {
                    {
                        id = "service-1",
                        name = "api-service",
                        url = "http://api:8081", -- URL changed
                        tags = {"env:staging"}
                    },
                    {
                        id = "service-2", -- New service
                        name = "auth-service",
                        url = "http://auth:8080",
                        tags = {"env:staging"}
                    }
                }
            }

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            local delta = filters.calculate_dp_delta("test-dp", new_config, old_config, dp_filters)

            ngx.say("added services: ", delta.added.services and #delta.added.services or 0)
            ngx.say("updated services: ", delta.updated.services and #delta.updated.services or 0)
            ngx.say("removed services: ", delta.removed.services and #delta.removed.services or 0)

            if delta.added.services then
                for _, service in ipairs(delta.added.services) do
                    ngx.say("added: ", service.name)
                end
            end

            if delta.updated.services then
                for _, service in ipairs(delta.updated.services) do
                    ngx.say("updated: ", service.name)
                end
            end
        }
    }
--- request
GET /t
--- response_body
added services: 1
updated services: 1
removed services: 0
added: auth-service
updated: api-service
--- no_error_log
[error]



=== TEST 11: caching functionality
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local dp_id = "test-dp"
            local config = {services = {}}
            local hash = "test-hash"

            -- Initially no cache
            local cached = filters.get_cached_dp_config(dp_id)
            ngx.say("initial cache: ", cached and "exists" or "nil")

            -- Set cache
            filters.set_cached_dp_config(dp_id, config, hash)

            -- Retrieve from cache
            cached = filters.get_cached_dp_config(dp_id)
            ngx.say("after set cache: ", cached and "exists" or "nil")
            ngx.say("cached hash: ", cached and cached.hash or "nil")

            -- Clear cache
            filters.clear_dp_cache(dp_id)
            cached = filters.get_cached_dp_config(dp_id)
            ngx.say("after clear cache: ", cached and "exists" or "nil")
        }
    }
--- request
GET /t
--- response_body
initial cache: nil
after set cache: exists
cached hash: test-hash
after clear cache: nil
--- no_error_log
[error]



=== TEST 12: empty delta detection
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            local config = {
                services = {
                    {
                        id = "service-1",
                        name = "api-service",
                        tags = {"env:staging"}
                    }
                }
            }

            local dp_filters = {
                {
                    type = "tags",
                    config = {
                        include = {"env:staging"}
                    }
                }
            }

            -- Calculate delta with same config
            local delta = filters.calculate_dp_delta("test-dp", config, config, dp_filters)
            local is_empty = filters.is_delta_empty(delta)

            ngx.say("delta is empty: ", is_empty)
        }
    }
--- request
GET /t
--- response_body
delta is empty: true
--- no_error_log
[error]



=== TEST 13: custom filter registration
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local filters = require "kong.clustering.filters"

            -- Register custom filter
            filters.register_custom_filter("test_filter", function(entity, config)
                return entity.name == config.target_name
            end)

            local config = {
                services = {
                    {
                        id = "svc-1",
                        name = "target-service"
                    },
                    {
                        id = "svc-2",
                        name = "other-service"
                    }
                }
            }

            local dp_filters = {
                {
                    type = "test_filter",
                    config = {
                        target_name = "target-service"
                    }
                }
            }

            local filtered_config = filters.filter_config_for_dp(config, dp_filters)

            ngx.say("filtered services: ", #filtered_config.services)
            ngx.say("service name: ", filtered_config.services[1].name)
        }
    }
--- request
GET /t
--- response_body
filtered services: 1
service name: target-service
--- no_error_log
[error]
