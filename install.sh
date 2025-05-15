#!/bin/sh

### Установка curl и русификаторов
opkg update
opkg install curl luci-i18n-base-ru luci-i18n-commands-ru luci-i18n-firewall-ru luci-i18n-opkg-ru luci-i18n-ttyd-ru kmod-nls-cp866 kmod-nls-utf8 kmod-nls-cp1251

### Фикс DPI-дурилок (Zapret, YouTubeUnblock) с Hardware/Software Offloading и Отключение QUIC на роутере (решает проблемы с видеопотоком, dpi обходами)
curl -fsSL https://raw.githubusercontent.com/gfreemoon/openwrt_autosetup/refs/heads/main/dpi_fix.sh | sh

### 🔧 Скрипт для отключения IPv6
curl -fsSL https://raw.githubusercontent.com/ilnur1111/routerr/refs/heads/main/disable_ipv6.sh | sh

### 🚀 Установка Podkop
sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)

### 🚀 Универсальный скрипт для YouTubeUnblock + config
curl -fsSL https://raw.githubusercontent.com/gfreemoon/install_youtubeunblock_universal/refs/heads/main/install%2Bconfig.sh | sh


curl -fsSL https://raw.githubusercontent.com/gfreemoon/openwrt_autosetup/refs/heads/main/tailscale.sh | sh
