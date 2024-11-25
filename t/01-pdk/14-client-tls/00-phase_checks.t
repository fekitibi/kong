use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
do "./t/Util.pm";

$ENV{TEST_NGINX_CERT_DIR} ||= File::Spec->catdir(server_root(), '..', 'certs');
$ENV{TEST_NGINX_NXSOCK}   ||= html_dir();

plan tests => repeat_each() * (blocks() * 2);

run_tests();

__DATA__

=== TEST 1: verify phase checking in kong.client.tls
--- http_config eval
qq{
    $t::Util::HttpConfig

    server {
        listen unix:$ENV{TEST_NGINX_NXSOCK}/nginx.sock ssl;
        ssl_certificate $ENV{TEST_NGINX_CERT_DIR}/test.crt;
        ssl_certificate_key $ENV{TEST_NGINX_CERT_DIR}/test.key;

        ssl_certificate_by_lua_block {
            phase_check_functions(phases.certificate)
        }


        ssl_client_hello_by_lua_block {
            phase_check_functions(phases.client_hello)
        }

        location / {
            set \$upstream_uri '/t';
            set \$upstream_scheme 'https';

            rewrite_by_lua_block {
                phase_check_functions(phases.rewrite)
            }

            access_by_lua_block {
                phase_check_functions(phases.access)
                phase_check_functions(phases.response)
                phase_check_functions(phases.admin_api)
            }

            header_filter_by_lua_block {
                phase_check_functions(phases.header_filter)
            }

            body_filter_by_lua_block {
                phase_check_functions(phases.body_filter)
            }

            log_by_lua_block {
                phase_check_functions(phases.log)
            }

            return 200;
        }
    }

    init_worker_by_lua_block {
        _G.kong = {
            configuration = {
                nginx_events_worker_connections = 1000
            }
        }
        ngx.ctx = {
            ja4_fingerprint = "t13d1516h2_8daaf6152771_e5627efa2ab1"
        }
        ngx.var = {connection = 1}

        phases = require("kong.pdk.private.phases").phases

        phase_check_module = "client.tls"
        phase_check_data = {
            {
                method        = "request_client_certificate",
                args          = {},
                init_worker   = "forced false",
                certificate   = true,
                client_hello  = "forced false",
                rewrite       = "forced false",
                access        = "forced false",
                header_filter = "forced false",
                response      = "forced false",
                body_filter   = "forced false",
                log           = "forced false",
                admin_api     = "forced false",
            }, {
                method        = "disable_session_reuse",
                args          = {},
                init_worker   = false,
                certificate   = true,
                client_hello  = false,
                rewrite       = false,
                access        = false,
                header_filter = false,
                response      = false,
                body_filter   = false,
                log           = false,
                admin_api     = false,
            }, {
                method        = "get_full_client_certificate_chain",
                args          = {},
                init_worker   = false,
                certificate   = false,
                client_hello  = false,
                rewrite       = true,
                access        = true,
                response      = true,
                header_filter = false,
                body_filter   = false,
                log           = true,
                admin_api     = false,
            }, {
                method        = "set_client_verify",
                args          = { "SUCCESS", },
                init_worker   = "forced false",
                client_hello  = "forced false",
                certificate   = "forced false",
                rewrite       = nil,
                access        = nil,
                header_filter = "forced false",
                response      = false,
                body_filter   = "forced false",
                log           = "forced false",
                admin_api     = false,
            }, {
                method        = "disable_http2_alpn",
                args          = {},
                init_worker   = false,
                client_hello  = true,
                certificate   = false,
                rewrite       = false,
                access        = false,
                header_filter = false,
                response      = false,
                body_filter   = false,
                log           = false,
                admin_api     = false,
            }, {
                method           = "compute_client_ja4",
                args             = {},
                init_worker      = "forced false",
                client_hello     = true,
                certificate      = "forced false",
                rewrite          = false,
                access           = false,
                response         = false,
                header_filter    = "forced false",
                body_filter      = "forced false",
                log              = "forced false",
                admin_api        = false,
            }, {
                method           = "get_computed_client_ja4",
                args             = {},
                init_worker      = "forced false",
                client_hello     = "forced false",
                certificate      = true,
                rewrite          = true,
                access           = true,
                response         = true,
                header_filter    = true,
                body_filter      = true,
                log              = true,
                admin_api        = false,
            }
        }

        phase_check_functions(phases.init_worker)
    }
}
--- config
    location /t {
        proxy_pass https://unix:$TEST_NGINX_NXSOCK/nginx.sock;
    }
--- request
GET /t
--- no_error_log
[error]
