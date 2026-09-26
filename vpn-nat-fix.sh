#!/bin/bash

# 1. Принудительно включаем UFW, который отключил VPN-сервер
ufw --force enable

# 2. Включаем форвардинг в ядре
sysctl -w net.ipv4.ip_forward=1

# 3. Полностью вычищаем любые старые правила маскарадинга для VPN подсетей
while iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -j MASQUERADE 2>/dev/null; do true; done
while iptables -t nat -D POSTROUTING -s 192.168.43.0/24 -j MASQUERADE 2>/dev/null; do true; done
while iptables -t nat -D POSTROUTING -s 192.168.43.0/24 -m policy --dir out --pol none -j MASQUERADE 2>/dev/null; do true; done
while iptables -t nat -D POSTROUTING -s 192.168.43.0/24 -o ens192 -m policy --dir out --pol none -j MASQUERADE 2>/dev/null; do true; done

# 4. Добавляем наше правильное правило маскарадинга через ens224
iptables -t nat -A POSTROUTING -s 192.168.43.0/24 -o ens224 -j MASQUERADE

# 5. Исправление размера MTU (правило автора)
iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -s 192.168.43.0/24 -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -s 192.168.43.0/24 -j TCPMSS --clamp-mss-to-pmtu

# 6. Очищаем и вставляем разрешающие правила FORWARD в самый верх, чтобы UFW их не блокировал
while iptables -D FORWARD -s 192.168.43.0/24 -j ACCEPT 2>/dev/null; do true; done
while iptables -D FORWARD -d 192.168.43.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; do true; done

iptables -I FORWARD 1 -s 192.168.43.0/24 -j ACCEPT
iptables -I FORWARD 2 -d 192.168.43.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "UFW enabled and VPN NAT fixed successfully!"
