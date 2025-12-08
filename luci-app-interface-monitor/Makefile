include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-interface-monitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=$(if $(BUILD_NUMBER),$(BUILD_NUMBER),$(shell date +%Y%m%d%H%M))

LUCI_TITLE:=Interface Monitor
LUCI_DEPENDS:=+luci-base +interface-monitor

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-interface-monitor
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
endef

define Package/luci-app-interface-monitor/description
LuCI UI to visualize interface and connectivity logs and configure connectivity monitoring.
endef

define Build/Compile
endef

define Package/luci-app-interface-monitor/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/interface_monitor.lua $(1)/usr/lib/lua/luci/controller/interface_monitor.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/interface_monitor
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/interface_monitor/config.lua $(1)/usr/lib/lua/luci/model/cbi/interface_monitor/config.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/interface_monitor
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/interface_monitor/logs.htm $(1)/usr/lib/lua/luci/view/interface_monitor/logs.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/interface_monitor/graph.htm $(1)/usr/lib/lua/luci/view/interface_monitor/graph.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/interface_monitor/iface.htm $(1)/usr/lib/lua/luci/view/interface_monitor/iface.htm
endef

$(eval $(call BuildPackage,luci-app-interface-monitor))
