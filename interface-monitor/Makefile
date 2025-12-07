include $(TOPDIR)/rules.mk

PKG_NAME:=interface-monitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

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

define Package/interface-monitor/conffiles
/etc/config/interface_monitor
endef

define Build/Compile
endef

define Package/interface-monitor/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/interface_monitor.sh $(1)/usr/bin/interface_monitor.sh
	$(INSTALL_BIN) ./files/usr/bin/connectivity_monitor.sh $(1)/usr/bin/connectivity_monitor.sh
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/interface_monitor $(1)/etc/init.d/interface_monitor
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/interface_monitor $(1)/etc/config/interface_monitor
endef

define Package/interface-monitor/postinst
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || {
    /etc/init.d/interface_monitor enable
    /etc/init.d/interface_monitor start
}
exit 0
endef

define Package/interface-monitor/prerm
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] || /etc/init.d/interface_monitor disable
exit 0
endef

$(eval $(call BuildPackage,interface-monitor))
