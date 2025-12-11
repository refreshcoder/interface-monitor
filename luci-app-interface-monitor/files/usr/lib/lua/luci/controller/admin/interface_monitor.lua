module("luci.controller.admin.interface_monitor", package.seeall)

function index()
    entry({"admin", "status", "interface_monitor"}, alias("admin", "status", "interface_monitor", "iface"), _("Interface Monitor"), 90)
    entry({"admin", "status", "interface_monitor", "iface"}, template("interface_monitor/iface"), _("Interface"), 1)
    entry({"admin", "status", "interface_monitor", "graph"}, template("interface_monitor/graph"), _("Connectivity"), 2)
    entry({"admin", "status", "interface_monitor", "config"}, cbi("interface_monitor/config"), _("Config"), 3)
    entry({"admin", "status", "interface_monitor", "logs"}, template("interface_monitor/logs"), _("Logs"), 4)

    entry({"admin", "status", "interface_monitor", "get_log_data"}, call("get_log_data"), nil)
    entry({"admin", "status", "interface_monitor", "clear_logs"}, call("clear_logs"), nil)
    entry({"admin", "status", "interface_monitor", "get_interface_status"}, call("get_interface_status"), nil)
    entry({"admin", "status", "interface_monitor", "get_configured_interfaces"}, call("get_configured_interfaces"), nil)
end

function get_configured_interfaces()
    local uci = require "luci.model.uci".cursor()
    local http = require "luci.http"
    local interfaces = uci:get_list("interface_monitor", "settings", "interfaces") or {}
    http.prepare_content("application/json")
    http.write_json(interfaces)
end

function get_log_data()
    local http = require "luci.http"
    local fs = require "nixio.fs"
    local log_dir = "/tmp/log/interface_monitor"
    local file = http.formvalue("file")
    local log_path = log_dir .. "/" .. file

    local page = tonumber(http.formvalue("page")) or 1
    local limit = tonumber(http.formvalue("limit")) or 50
    local since = http.formvalue("since")
    
    local all_lines = {}
    if file and fs.access(log_path) then
        local fp
        if since then
            local check_last_n = 200
            fp = io.popen(string.format("tail -n %d %s", check_last_n, log_path))
        else
            fp = io.open(log_path, "r")
        end

        if fp then
            for line in fp:lines() do
                if since then
                    local timestamp = line:match("^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)")
                    if timestamp and timestamp > since then
                        table.insert(all_lines, line)
                    end
                else
                    table.insert(all_lines, line)
                end
            end
            fp:close()
        end
    end

    local total_lines = #all_lines
    local logs_page = {}
    
    local start_index, end_index
    if since then
        start_index = 1
        end_index = total_lines
    else
        end_index = total_lines - ((page - 1) * limit)
        start_index = math.max(1, end_index - limit + 1)
    end

    if total_lines > 0 then
        for i = end_index, start_index, -1 do
            table.insert(logs_page, all_lines[i])
        end
    end

function clear_logs()
    local fs = require "nixio.fs"
    local http = require "luci.http"
    local log_dir = "/tmp/log/interface_monitor"
    for f in fs.dir(log_dir) do
        if f:match("%.log") then
            fs.remove(log_dir .. "/" .. f)
        end
    end
    http.prepare_content("application/json")
    http.write_json({ result = "ok" })
end

    local response = {
        logs = logs_page,
        total = total_lines,
        page = page,
        limit = limit
    }

    http.prepare_content("application/json")
    http.write_json(response)
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
