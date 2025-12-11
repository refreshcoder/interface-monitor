module("luci.controller.admin.interface_monitor", package.seeall)

function index()
    entry({"admin", "status", "interface_monitor"}, alias("admin", "status", "interface_monitor", "iface"), _("Interface Monitor"), 90)
    entry({"admin", "status", "interface_monitor", "iface"}, template("interface_monitor/iface"), _("Interface Graph"), 1)
    entry({"admin", "status", "interface_monitor", "graph"}, template("interface_monitor/graph"), _("Connectivity Graph"), 2)
    entry({"admin", "status", "interface_monitor", "config"}, cbi("interface_monitor/config"), _("Configuration"), 3)
    entry({"admin", "status", "interface_monitor", "logs"}, template("interface_monitor/logs"), _("Logs"), 4)

    entry({"admin", "status", "interface_monitor", "get_log_data"}, call("get_log_data"), nil)
    entry({"admin", "status", "interface_monitor", "clear_logs"}, call("clear_logs"), nil)
    entry({"admin", "status", "interface_monitor", "get_interface_status"}, call("get_interface_status"), nil)
end

function get_log_data()
    local http = require "luci.http"
    local fs = require "nixio.fs"
    local log_dir = "/tmp/log/interface_monitor"
    local file = http.formvalue("file")
    local content = {}

    if file and fs.access(log_dir .. "/" .. file) then
        local fp = io.open(log_dir .. "/" .. file, "r")
        if fp then
            for line in fp:lines() do
                table.insert(content, line)
            end
            fp:close()
        end
    end

    http.prepare_content("application/json")
    http.write_json(content)
end

function get_interface_status()
    local ubus = require "ubus"
    local http = require "luci.http"
    local conn = ubus.connect()
    if not conn then
        http.prepare_content("application/json")
        http.write_json({ error = "Failed to connect to ubus" })
        return
    end

    local status = conn:call("network.device", "status", {})
    conn:close()

    http.prepare_content("application/json")
    http.write_json(status)
end
