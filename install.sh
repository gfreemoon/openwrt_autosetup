#!/bin/sh

# Функция для запроса подтверждения установки
ask_install() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Пожалуйста, ответьте y или n.";;
        esac
    done
}

# Установка необходимых пакетов для работы с русским текстом
echo "🚀 Установка базовых пакетов для поддержки русского языка..."
opkg update
opkg install curl kmod-nls-cp866 kmod-nls-utf8 kmod-nls-cp1251

# Переменные для хранения выбора пользователя
INSTALL_DPI_FIX=false
INSTALL_DISABLE_IPV6=false
INSTALL_PODKOP=false
INSTALL_TAILSCALE=false
INSTALL_YOUTUBEUNBLOCK=false
INSTALL_YOUTUBEUNBLOCK_CONFIG=false

# Запрос выбора функций для установки
echo "Выберите функции для установки:"
ask_install "Применить фикс DPI + отключение QUIC?" && INSTALL_DPI_FIX=true
ask_install "Отключить IPv6?" && INSTALL_DISABLE_IPV6=true
ask_install "Установить Podkop?" && INSTALL_PODKOP=true
ask_install "Настроить удалённый доступ через Tailscale?" && INSTALL_TAILSCALE=true
ask_install "Установить YouTubeUnblock?" && INSTALL_YOUTUBEUNBLOCK=true
ask_install "Установить конфиг для YouTubeUnblock?" && INSTALL_YOUTUBEUNBLOCK_CONFIG=true

# Установка выбранных функций

# Фикс DPI + отключение QUIC
if $INSTALL_DPI_FIX; then
    echo "🔧 Применение фикса DPI и отключение QUIC..."
    sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc
    fw4 restart
    
    uci add firewall rule
    uci set firewall.@rule[-1].name='Block_UDP_80'
    uci set firewall.@rule[-1].src='*'
    uci set firewall.@rule[-1].dest_port='80'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].target='REJECT'

    uci add firewall rule
    uci set firewall.@rule[-1].name='Block_UDP_443'
    uci set firewall.@rule[-1].src='*'
    uci set firewall.@rule[-1].dest_port='443'
    uci set firewall.@rule[-1].proto='udp'
    uci set firewall.@rule[-1].target='REJECT'

    uci commit firewall
    /etc/init.d/firewall restart
    echo "✅ Фикс DPI и отключение QUIC применены успешно"
fi

# Отключение IPv6
if $INSTALL_DISABLE_IPV6; then
    echo "🔧 Отключение IPv6..."
    # Шаг 1. Отключение IPv6 на LAN и WAN
    uci set 'network.lan.ipv6=0'
    uci set 'network.wan.ipv6=0'
    
    # Шаг 2. Отключение DHCPv6 на LAN
    uci set 'dhcp.lan.dhcpv6=disabled'
    
    # Шаг 3. Удаляем параметры DHCPv6 и RA
    uci -q delete dhcp.lan.dhcpv6
    uci -q delete dhcp.lan.ra
    
    # Шаг 4. Отключение делегирования LAN
    uci set network.lan.delegate="0"
    
    # Шаг 5. Удаление ULA префикса
    uci -q delete network.globals.ula_prefix
    
    # Шаг 6. Отключение и остановка odhcpd
    /etc/init.d/odhcpd disable
    /etc/init.d/odhcpd stop
    
    # Шаг 7. Настройка dnsmasq для фильтрации AAAA записей
    uci set dhcp.@dnsmasq[0].filter_aaaa='1'
    uci commit
    
    # Шаг 8. Отключение IPv6 через sysctl и /proc
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1
    
    echo "✅ IPv6 отключен успешно"
fi

# Установка Podkop
if $INSTALL_PODKOP; then
    echo "🚀 Установка Podkop..."
    sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)
    echo "✅ Podkop установлен успешно"
fi

# Установка Tailscale
if $INSTALL_TAILSCALE; then
    echo "🌐 Настройка удалённого доступа через Tailscale..."
    opkg update
    opkg remove kmod-ipt-nat
    opkg install kmod-nf-nat tailscale tailscaled
    
    uci set network.tail=interface
    uci set network.tail.ifname='tailscale0'
    uci set network.tail.proto='none'
    uci commit network
    /etc/init.d/network reload
    
    /etc/init.d/tailscale enable
    /etc/init.d/tailscale start
    tailscale up
    
    sh <(wget -O - https://raw.githubusercontent.com/ilnur1111/routerr/main/tailscale.sh)
    echo "✅ Tailscale настроен успешно"
fi

# Установка YouTubeUnblock
if $INSTALL_YOUTUBEUNBLOCK; then
    echo "📺 Установка YouTubeUnblock..."
    ARCH=$(uname -m)
    LUCI_PKG="luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk"

    case "$ARCH" in
        aarch64) PKG="youtubeUnblock-1.0.0-10-f37c3dd-aarch64_generic-openwrt-23.05.ipk" ;;
        armv7) PKG="youtubeUnblock-1.0.0-10-f37c3dd-armv7-static.tar.gz" ;;
        armv7sf) PKG="youtubeUnblock-1.0.0-10-f37c3dd-armv7sf-static.tar.gz" ;;
        armv6l) PKG="youtubeUnblock-1.0.0-10-f37c3dd-arm_arm1176jzf-s_vfp-openwrt-23.05.ipk" ;;
        armv5te) PKG="youtubeUnblock-1.0.0-10-f37c3dd-arm_arm926ej-s-openwrt-23.05.ipk" ;;
        x86_64) PKG="youtubeUnblock-1.0.0-10-f37c3dd-x86_64-openwrt-23.05.ipk" ;;
        mips) PKG="youtubeUnblock-1.0.0-10-f37c3dd-mips-static.tar.gz" ;;
        mipsel) PKG="youtubeUnblock-1.0.0-10-f37c3dd-mipsel-static.tar.gz" ;;
        *) echo "❌ Ошибка: архитектура '$ARCH' не поддерживается"; exit 1 ;;
    esac

    opkg update
    opkg install kmod-nft-queue kmod-nfnetlink-queue
    
    wget -O "/tmp/$PKG" "https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/$PKG"
    opkg install "/tmp/$PKG"
    
    wget -O "/tmp/$LUCI_PKG" "https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/$LUCI_PKG"
    opkg install "/tmp/$LUCI_PKG"
    
    /etc/init.d/youtubeUnblock enable
    echo "✅ YouTubeUnblock установлен успешно"
fi

# Установка конфига для YouTubeUnblock
if $INSTALL_YOUTUBEUNBLOCK_CONFIG; then
    echo "⚙️ Установка конфигурации для YouTubeUnblock..."
    cp /etc/config/youtubeUnblock /etc/config/youtubeUnblock.bak
    
    cat > /etc/config/youtubeUnblock << 'EOF'
config youtubeUnblock 'youtubeUnblock'
    option conf_strat 'ui_flags'
    option packet_mark '32768'
    option queue_num '537'
    option no_ipv6 '1'
EOF

    URLS="
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/anime.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/block.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/news.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/porn.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/telegram.lst
    https://raw.githubusercontent.com/GhostRooter0953/discord-voice-ips/refs/heads/master/main_domains/discord-main-domains-list
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/hdrezka.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/meta.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/twitter.lst
    https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/youtube.lst
    https://raw.githubusercontent.com/HotCakeX/MicrosoftDomains/refs/heads/main/Microsoft%20Domains.txt
    "

    for url in $URLS; do
        author=$(echo "$url" | cut -d'/' -f4)
        filename=$(echo "$url" | awk -F/ '{print $NF}' | sed 's/\.lst$//;s/\.txt$//;s/%20/-/g;s/%//g')

        if [ "$filename" = "Microsoft_Domains" ]; then
            final_name="xbox-full-list"
        else
            final_name="${filename}-${author}"
        fi

        curl -s -o /tmp/temp_list.txt "$url" || continue

        cat >> /etc/config/youtubeUnblock << EOF
config section
    option name '$final_name'
    option tls_enabled '1'
    option fake_sni '1'
    option faking_strategy 'pastseq'
    option fake_sni_seq_len '1'
    option fake_sni_type 'default'
    option frag 'tcp'
    option frag_sni_reverse '1'
    option frag_sni_faked '0'
    option frag_middle_sni '1'
    option frag_sni_pos '1'
    option seg2delay '0'
    option fk_winsize '0'
    option synfake '0'
    option all_domains '0'
    option sni_detection 'parse'
    option udp_mode 'fake'
    option udp_faking_strategy 'none'
    option udp_fake_seq_len '6'
    option udp_fake_len '64'
    option udp_filter_quic 'disabled'
    option enabled '1'
EOF

        if [ "$final_name" = "discord-main-domains-list-GhostRooter0953" ]; then
            echo "    list udp_dport_filter '50000-50100'" >> /etc/config/youtubeUnblock
        fi

        if [ "$final_name" = "youtube-itdoginfo" ]; then
            echo "    option quic_drop '0'" >> /etc/config/youtubeUnblock
        fi

        while read -r domain; do
            [ -n "$domain" ] && echo "    list sni_domains '$domain'" >> /etc/config/youtubeUnblock
        done < /tmp/temp_list.txt

        case $final_name in
            "hdrezka-itdoginfo")
                echo "    list sni_domains 'hdrezka.es'" >> /etc/config/youtubeUnblock
                ;;
            "youtube-itdoginfo")
                echo "    list sni_domains 'play.google.com'" >> /etc/config/youtubeUnblock
                ;;
            "Microsoft-Domains-HotCakeX")
                echo "    list udp_dport_filter '88'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '3074'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '53'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '80'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '500'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '3544'" >> /etc/config/youtubeUnblock
                echo "    list udp_dport_filter '4500'" >> /etc/config/youtubeUnblock
                ;;
        esac

        rm -f /tmp/temp_list.txt
    done
    echo "✅ Конфигурация YouTubeUnblock установлена успешно"
fi

# Установка русификаторов
if ask_install "Установить русификаторы для Luci?"; then
    echo "🇷🇺 Установка русификаторов..."
    opkg install luci-i18n-base-ru luci-i18n-commands-ru luci-i18n-firewall-ru luci-i18n-opkg-ru luci-i18n-ttyd-ru
    echo "✅ Русификаторы установлены успешно"
fi

# Перезагрузка сети и сервисов
if ask_install "Перезагрузить сетевые интерфейсы и сервисы? (рекомендуется)"; then
    echo "🔄 Перезагрузка сетевых интерфейсов и сервисов..."
    /etc/init.d/network restart
    /etc/init.d/firewall restart
    /etc/init.d/dnsmasq restart
    echo "✅ Сетевые интерфейсы и сервисы перезагружены"
fi

echo "🎉 Установка завершена успешно!"
echo "⚠️ Для применения некоторых изменений может потребоваться перезагрузка роутера"
