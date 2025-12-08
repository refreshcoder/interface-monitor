module("luci.controller.interface_monitor", package.seeall)

function index()
    entry({"admin","status","interface_monitor"}, firstchild(), _("Interface Monitor"), 90).dependent=false
    entry({"admin","status","interface_monitor","logs"}, template("interface_monitor/logs"), _("Logs"), 1)
    entry({"admin","status","interface_monitor","config"}, cbi("interface_monitor/config"), _("Settings"), 2).leaf = true
    entry({"admin","status","interface_monitor","graph"}, template("interface_monitor/graph"), _("Connectivity Graph"), 3).leaf = true
    entry({"admin","status","interface_monitor","iface"}, template("interface_monitor/iface"), _("Interface Graph"), 4).leaf = true
end
