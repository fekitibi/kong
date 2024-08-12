-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local _M = {}

-- Set disable_ai_proxy_response_transform if response is just a error message or has been generated
-- by plugin and should skip further transformation
function _M.disable_ai_proxy_response_transform()
  kong.ctx.shared.llm_disable_ai_proxy_response_transform = true
end

function _M.should_disable_ai_proxy_response_transform()
  return kong.ctx.shared.llm_disable_ai_proxy_response_transform == true
end

function _M.set_prompt_decorated()
  kong.ctx.shared.llm_prompt_decorated = true
end

function _M.is_prompt_decorated()
  return kong.ctx.shared.llm_prompt_decorated == true
end

function _M.set_prompt_guarded()
  kong.ctx.shared.llm_prompt_guarded = true
end

function _M.is_prompt_guarded()
  return kong.ctx.shared.llm_prompt_guarded == true
end

function _M.set_prompt_templated()
  kong.ctx.shared.llm_prompt_templated = true
end

function _M.is_prompt_templated()
  return kong.ctx.shared.llm_prompt_templated == true
end

function _M.set_streaming_mode()
  kong.ctx.shared.llm_streaming_mode = true
end

function _M.is_streaming_mode()
  return kong.ctx.shared.llm_streaming_mode == true
end

function _M.set_parsed_response(response)
  kong.ctx.shared.llm_parsed_response = response
end

function _M.get_parsed_response()
  return kong.ctx.shared.llm_parsed_response
end

function _M.set_request_body_table(body_t)
  kong.ctx.shared.llm_request_body_t = body_t
end

function _M.get_request_body_table()
  return kong.ctx.shared.llm_request_body_t
end

function _M.set_replacement_response(response)
  kong.ctx.shared.llm_replacement_response = response
end

function _M.get_replacement_response()
  return kong.ctx.shared.llm_replacement_response
end

function _M.set_request_analytics(tbl)
  kong.ctx.shared.llm_request_analytics = tbl
end

function _M.get_request_analytics()
  return kong.ctx.shared.llm_request_analytics
end

function _M.increase_prompt_tokens_count(by)
  local count = (kong.ctx.shared.llm_prompt_tokens_count or 0) + by
  kong.ctx.shared.llm_prompt_tokens_count = count
  return count
end

function _M.get_prompt_tokens_count()
  return kong.ctx.shared.llm_prompt_tokens_count
end

function _M.increase_response_tokens_count(by)
  local count = (kong.ctx.shared.llm_response_tokens_count or 0) + by
  kong.ctx.shared.llm_response_tokens_count = count
  return count
end

function _M.get_response_tokens_count()
  return kong.ctx.shared.llm_response_tokens_count
end

function _M.set_metrics(key, value)
  local m = kong.ctx.shared.llm_metrics or {}
  m[key] = value
  kong.ctx.shared.llm_metrics = m
end

function _M.get_metrics(key)
  return (kong.ctx.shared.llm_metrics or {})[key]
end

function _M.set_stream_body_buffer_needed()
  kong.ctx.shared.llm_stream_body_buffer_needed = true
end

function _M.is_stream_body_buffer_needed()
  return kong.ctx.shared.llm_stream_body_buffer_needed
end

-- EE

function _M.set_semantic_cache_hit(bool)
  kong.ctx.shared.llm_semantic_cache_hit = bool
end

function _M.is_semantic_cache_hit()
  return kong.ctx.shared.llm_semantic_cache_hit
end

function _M.set_ai_proxy_conf(conf)
  kong.ctx.shared.llm_ai_proxy_conf = conf
end

function _M.get_ai_proxy_conf()
  return kong.ctx.shared.llm_ai_proxy_conf
end

return _M