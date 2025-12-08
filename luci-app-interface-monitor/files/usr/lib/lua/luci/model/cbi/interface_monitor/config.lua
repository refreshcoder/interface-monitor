local map = Map("interface_monitor", translate("Interface Monitor Settings"))

local s = map:section(TypedSection, "settings", translate("General Settings"))
s.anonymous = true

-- Interface Monitor Settings
local enable_svc = s:option(Flag, "enabled", translate("Enable Service"))
enable_svc.rmempty = false

local ifaces = s:option(DynamicList, "interfaces", translate("Monitored Interfaces"))
ifaces.datatype = "string"
ifaces.description = translate("Interfaces to monitor (e.g. eth0)")

local mon_int = s:option(Value, "monitor_interval", translate("Interface Check Interval (s)"))
mon_int.datatype = "uinteger"
mon_int.default = "60"

-- Connectivity Monitor Settings
local enable = s:option(Flag, "connectivity_enable", translate("Enable Connectivity Monitor"))
enable.rmempty = false

local ip = s:option(DynamicList, "target_ip", translate("Target IP"))
ip.datatype = "ip4addr"
ip:depends("connectivity_enable", "1")

local ping_int = s:option(Value, "ping_interval", translate("Ping Interval (s)"))
ping_int.datatype = "uinteger"
ping_int.default = "60"
ping_int:depends("connectivity_enable", "1")

local verbose = s:option(Flag, "connectivity_verbose", translate("Log Heartbeat Every Interval"))
verbose.rmempty = false
verbose:depends("connectivity_enable", "1")

return map
