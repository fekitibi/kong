-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

_G.kong = {
  -- XXX EE: kong.version is used in some warning messages in
  -- clustering/control_plane.lua and fail if nil
  version = "w.x.y.z",
  configuration = {
      cluster_max_payload = 4194304
    }
}

local calculate_config_hash = require("kong.clustering.config_helper").calculate_config_hash
local version = require("kong.clustering.compat.version")

describe("kong.clustering.compat.version", function()
  it("correctly parses 3 or 4 digit version numbers", function()
    assert.equal(3000000000, version.string_to_number("3.0.0"))
    assert.equal(3000001000, version.string_to_number("3.0.1"))
    assert.equal(3000000000, version.string_to_number("3.0.0.0"))
    assert.equal(3000000001, version.string_to_number("3.0.0.1"))
    assert.equal(333333333001, version.string_to_number("333.333.333.1"))
    assert.equal(333333333333, version.string_to_number("333.333.333.333"))
  end)
end)

describe("kong.clustering.compat.version", function()
  it("correctly parses 3 or 4 digit version numbers", function()
    assert.equal(3000000000, version.string_to_number("3.0.0"))
    assert.equal(3000001000, version.string_to_number("3.0.1"))
    assert.equal(3000000000, version.string_to_number("3.0.0.0"))
    assert.equal(3000000001, version.string_to_number("3.0.0.1"))
    assert.equal(333333333001, version.string_to_number("333.333.333.1"))
    assert.equal(333333333333, version.string_to_number("333.333.333.333"))
  end)
end)

local DECLARATIVE_EMPTY_CONFIG_HASH = require("kong.constants").DECLARATIVE_EMPTY_CONFIG_HASH


describe("kong.clustering", function()
  describe(".calculate_config_hash()", function()
    it("calculating hash for nil", function()
      local hash = calculate_config_hash(nil)
      assert.equal(DECLARATIVE_EMPTY_CONFIG_HASH, hash)
    end)

    it("calculates hash for null", function()
      local value = ngx.null

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("5bf07a8b7343015026657d1108d8206e", hash)
      end

      local correct = ngx.md5("/null/")
      assert.equal("5bf07a8b7343015026657d1108d8206e", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for number", function()
      local value = 10

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("d3d9446802a44259755d38e6d163e820", hash)
      end

      local correct = ngx.md5("10")
      assert.equal("d3d9446802a44259755d38e6d163e820", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for double", function()
      local value = 0.9

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("a894124cc6d5c5c71afe060d5dde0762", hash)
      end

      local correct = ngx.md5("0.9")
      assert.equal("a894124cc6d5c5c71afe060d5dde0762", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for empty string", function()
      local value = ""

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("d41d8cd98f00b204e9800998ecf8427e", hash)
      end

      local correct = ngx.md5("")
      assert.equal("d41d8cd98f00b204e9800998ecf8427e", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for string", function()
      local value = "hello"

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("5d41402abc4b2a76b9719d911017c592", hash)
      end

      local correct = ngx.md5("hello")
      assert.equal("5d41402abc4b2a76b9719d911017c592", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for boolean false", function()
      local value = false

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("68934a3e9455fa72420237eb05902327", hash)
      end

      local correct = ngx.md5("false")
      assert.equal("68934a3e9455fa72420237eb05902327", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculates hash for boolean true", function()
      local value = true

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("b326b5062b2f0e69046810717534cb09", hash)
      end

      local correct = ngx.md5("true")
      assert.equal("b326b5062b2f0e69046810717534cb09", correct)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal(correct, hash)
      end
    end)

    it("calculating hash for function errors", function()
      local pok = pcall(calculate_config_hash, function() end)
      assert.falsy(pok)
    end)

    it("calculating hash for thread errors", function()
      local pok = pcall(calculate_config_hash, coroutine.create(function() end))
      assert.falsy(pok)
    end)

    it("calculating hash for userdata errors", function()
      local pok = pcall(calculate_config_hash, io.tmpfile())
      assert.falsy(pok)
    end)

    it("calculating hash for cdata errors", function()
      local pok = pcall(calculate_config_hash, require "ffi".new("char[6]", "foobar"))
      assert.falsy(pok)
    end)

    it("calculates hash for empty table", function()
      local value = {}

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("88f54953aeb10a1ca6ebb47bf843f4c4", hash)
      end

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("88f54953aeb10a1ca6ebb47bf843f4c4", hash)
      end
    end)

    it("calculates hash for complex table", function()
      local value = {
        plugins = {
          { name = "0", config = { param = "value"}},
          { name = "1", config = { param = { "v1", "v2", "v3", "v4", "v5", "v6" }}},
          { name = "2", config = { param = { "v1", "v2", "v3", "v4", "v5" }}},
          { name = "3", config = { param = { "v1", "v2", "v3", "v4" }}},
          { name = "4", config = { param = { "v1", "v2", "v3" }}},
          { name = "5", config = { param = { "v1", "v2" }}},
          { name = "6", config = { param = { "v1" }}},
          { name = "7", config = { param = {}}},
          { name = "8", config = { param = "value", array = { "v1", "v2", "v3", "v4", "v5", "v6" }}},
          { name = "9", config = { bool1 = true, bool2 = false, number = 1, double = 1.1, empty = {}, null = ngx.null,
                                   string = "test", hash = { k = "v" }, array = { "v1", "v2", "v3", "v4", "v5", "v6" }}},
        },
        consumers = {}
      }

      for i = 1, 1000 do
        value.consumers[i] = { username = "user-" .. tostring(i) }
      end

      local h = calculate_config_hash(value)

      for _ = 1, 10 do
        local hash = calculate_config_hash(value)
        assert.is_string(hash)
        assert.equal("cea33f80da546963fe35936b0cb00809", hash)
        assert.equal(h, hash)
      end
    end)

    describe("granular hashes", function()
      it("filled with empty hash values for missing config fields", function()
        local value = {}

        for _ = 1, 10 do
          local hash, hashes = calculate_config_hash(value)
          assert.is_string(hash)
          assert.equal("88f54953aeb10a1ca6ebb47bf843f4c4", hash)
          assert.is_table(hashes)
          assert.same({
            config = "88f54953aeb10a1ca6ebb47bf843f4c4",
            routes = DECLARATIVE_EMPTY_CONFIG_HASH,
            services = DECLARATIVE_EMPTY_CONFIG_HASH,
            plugins = DECLARATIVE_EMPTY_CONFIG_HASH,
            custom_plugins = DECLARATIVE_EMPTY_CONFIG_HASH,
            upstreams = DECLARATIVE_EMPTY_CONFIG_HASH,
            targets = DECLARATIVE_EMPTY_CONFIG_HASH,
          }, hashes)
        end
      end)

      it("has sensible values for existing fields", function()
        local value = {
          routes = {},
          services = {},
          plugins = {},
        }

        for _ = 1, 10 do
          local hash, hashes = calculate_config_hash(value)
          assert.is_string(hash)
          assert.equal("385a31a3ae9740f680a49b217f3a1bba", hash)
          assert.is_table(hashes)
          assert.same({
            config = "385a31a3ae9740f680a49b217f3a1bba",
            routes = "99914b932bd37a50b983c5e7c90ae93b",
            services = "99914b932bd37a50b983c5e7c90ae93b",
            plugins = "99914b932bd37a50b983c5e7c90ae93b",
            custom_plugins = DECLARATIVE_EMPTY_CONFIG_HASH,
            upstreams = DECLARATIVE_EMPTY_CONFIG_HASH,
            targets = DECLARATIVE_EMPTY_CONFIG_HASH,
          }, hashes)
        end

        value = {
          upstreams = {},
          targets = {},
        }

        for _ = 1, 10 do
          local hash, hashes = calculate_config_hash(value)
          assert.is_string(hash)
          assert.equal("99125c50d50878e3ee3dd48bed6f8008", hash)
          assert.is_table(hashes)
          assert.same({
            config = "99125c50d50878e3ee3dd48bed6f8008",
            routes = DECLARATIVE_EMPTY_CONFIG_HASH,
            services = DECLARATIVE_EMPTY_CONFIG_HASH,
            plugins = DECLARATIVE_EMPTY_CONFIG_HASH,
            custom_plugins = DECLARATIVE_EMPTY_CONFIG_HASH,
            upstreams = "99914b932bd37a50b983c5e7c90ae93b",
            targets = "99914b932bd37a50b983c5e7c90ae93b",
          }, hashes)
        end
      end)
    end)

  end)
end)
