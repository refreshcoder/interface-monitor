module("luci.controller.interface_monitor", package.seeall)

function index()
    entry({"admin","status","interface_monitor"}, firstchild(), _("Interface Monitor"), 90).dependent=false
    entry({"admin","status","interface_monitor","logs"}, template("interface_monitor/logs"), _("Logs"), 1)
    entry({"admin","status","interface_monitor","config"}, cbi("interface_monitor/config"), _("Settings"), 2).leaf = true
    entry({"admin","status","interface_monitor","graph"}, template("interface_monitor/graph"), _("Connectivity Graph"), 3).leaf = true
    entry({"admin","status","interface_monitor","iface"}, template("interface_monitor/iface"), _("Interface Graph"), 4).leaf = true
    entry({"admin", "status", "interface_monitor", "clear_logs"}, call("action_clear_logs"), nil).leaf = true
end

function action_clear_logs()
    local fs = require "nixio.fs"
    local log_dir = "/tmp/log/interface_monitor"
    for f in fs.dir(log_dir) do
        if f:match("^conn_.*%.log$") or f:match("^iface_.*%.log$") then
            fs.remove(log_dir .. "/" .. f)
        end
    end
    luci.http.write_json({result = "ok"})
end
