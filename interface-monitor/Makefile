include $(TOPDIR)/rules.mk

PKG_NAME:=interface-monitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=$(if $(BUILD_NUMBER),$(BUILD_NUMBER),$(shell date +%Y%m%d%H%M))

include $(INCLUDE_DIR)/package.mk

define Package/interface-monitor
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Interface monitor script
  DEPENDS:=+ethtool +libuci
endef

define Package/interface-monitor/description
A simple interface monitor that logs speed and link changes without modifying original behavior.
endef


define Build/Compile
endef

define Package/interface-monitor/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/interface_monitor.sh $(1)/usr/bin/interface_monitor.sh
	$(INSTALL_BIN) ./files/usr/bin/connectivity_monitor.sh $(1)/usr/bin/connectivity_monitor.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/interface_monitor $(1)/etc/init.d/interface_monitor
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-interface-monitor $(1)/etc/uci-defaults/99-interface-monitor
endef

define Package/interface-monitor/postinst
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
    # Ensure config section exists before setting options
    if ! uci -q get interface_monitor.settings >/dev/null; then
        sec=$(uci add interface_monitor settings 2>/dev/null)
        [ -n "$sec" ] && uci rename interface_monitor.$sec=settings
    fi
    # Run uci-defaults to populate defaults immediately
    if [ -x /etc/uci-defaults/99-interface-monitor ]; then
        /etc/uci-defaults/99-interface-monitor >/dev/null 2>&1 || true
        rm -f /etc/uci-defaults/99-interface-monitor
    fi
    val=$(uci -q get interface_monitor.settings.enabled)
    [ -z "$val" ] && { uci set interface_monitor.settings.enabled='1'; uci commit interface_monitor; }
    /etc/init.d/interface_monitor enable
    /etc/init.d/interface_monitor start
}
exit 0
endef

define Package/interface-monitor/prerm
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
    /etc/init.d/interface_monitor stop >/dev/null 2>&1 || true
    /etc/init.d/interface_monitor disable >/dev/null 2>&1 || true
}
exit 0
endef

$(eval $(call BuildPackage,interface-monitor))
