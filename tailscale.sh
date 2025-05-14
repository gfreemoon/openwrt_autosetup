#!/bin/sh

# Установка необходимых пакетов
opkg update
opkg remove kmod-ipt-nat
opkg install kmod-nf-nat tailscale tailscaled

# Создание интерфейса tailscale через UCI
uci set network.tail=interface
uci set network.tail.ifname='tailscale0'
uci set network.tail.proto='none'
uci commit network
/etc/init.d/network reload

# Включение и запуск tailscale
/etc/init.d/tailscale enable
/etc/init.d/tailscale start
tailscale up

# Настройка фаервола
curl -fsSL https://raw.githubusercontent.com/ilnur1111/routerr/main/tailscale.sh | sh
