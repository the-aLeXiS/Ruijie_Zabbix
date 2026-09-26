#!/bin/bash

# Включаем форвардинг в ядре
sysctl -w net.ipv4.ip_forward=1

# Находим и удаляем абсолютно любые правила MASQUERADE для подсетей VPN,
# чтобы не подбирать ключи под синтаксис libreswan
while iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -j MASQUERADE 2>/dev/null; do true; done
while iptables -t nat -D POSTROUTING -s 192.168.43.0/24 -j MASQUERADE 2>/dev/null; do true; done

# Добавляем чистое и единственное правило маскарадинга через нужный ens224
iptables -t nat -A POSTROUTING -s 192.168.43.0/24 -o ens224 -j MASQUERADE

# Исправление размера MTU (оригинальное правило автора)
iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -s 192.168.43.0/24 -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -s 192.168.43.0/24 -j TCPMSS --clamp-mss-to-pmtu

# Очищаем старые разрешающие правила FORWARD, чтобы не дублировать их при перезапусках
while iptables -D FORWARD -s 192.168.43.0/24 -j ACCEPT 2>/dev/null; do true; done
while iptables -D FORWARD -d 192.168.43.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; do true; done

# Вставляем правила строго на первые позиции цепочки FORWARD
iptables -I FORWARD 1 -s 192.168.43.0/24 -j ACCEPT
iptables -I FORWARD 2 -d 192.168.43.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "VPN NAT fixed successfully!"
