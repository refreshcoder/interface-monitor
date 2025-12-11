module("luci.controller.admin.interface_monitor", package.seeall)

function index()
    entry({"admin", "status", "interface_monitor"}, alias("admin", "status", "interface_monitor", "iface"), _("Interface Monitor"), 90)
    entry({"admin", "status", "interface_monitor", "iface"}, template("interface_monitor/iface"), _("Interface Graph"), 1)
    entry({"admin", "status", "interface_monitor", "logs"}, template("interface_monitor/logs"), _("Logs"), 2)
    entry({"admin", "status", "interface_monitor", "get_log_data"}, call("get_log_data"), nil, 3)
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
