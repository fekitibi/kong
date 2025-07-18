local config_filter = require "kong.tools.config_filter"

describe("config_filter", function()
  local config = {
    workspaces = {
      { name = "ws1" },
      { name = "ws2" },
    },
    services = {
      { name = "svc1" },
      { name = "svc2" },
    },
    routes = {
      { name = "route1", tags = { "tag1", "tag2" } },
      { name = "route2", tags = { "tag3" } },
    },
  }

  it("filters by workspace", function()
    local filtered = config_filter.filter_config(config, { workspaces = { ws1 = true } })
    assert.is_table(filtered.workspaces)
    assert.equals(1, #filtered.workspaces)
    assert.equals("ws1", filtered.workspaces[1].name)
  end)

  it("filters by service", function()
    local filtered = config_filter.filter_config(config, { services = { svc2 = true } })
    assert.is_table(filtered.services)
    assert.equals(1, #filtered.services)
    assert.equals("svc2", filtered.services[1].name)
  end)

  it("filters by tag", function()
    local filtered = config_filter.filter_config(config, { tags = { tag3 = true } })
    assert.is_table(filtered.routes)
    assert.equals(1, #filtered.routes)
    assert.equals("route2", filtered.routes[1].name)
  end)

  it("returns empty if no match", function()
    local filtered = config_filter.filter_config(config, { workspaces = { ws3 = true } })
    assert.is_table(filtered.workspaces)
    assert.equals(0, #filtered.workspaces)
  end)
end)
