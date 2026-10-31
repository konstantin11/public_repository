#!/bin/bash
set -Eeuo pipefail

LOG=/var/log/install_zapret.log
exec > >(tee -a "$LOG") 2>&1

export DEBIAN_FRONTEND=noninteractive

echo "=== Начало установки Zapret ==="

apt-get update
apt-get install -y curl ca-certificates tar expect

cd /tmp

V=$(curl -fsSL https://api.github.com/repos/bol-van/zapret/releases/latest |
    grep -m1 '"tag_name"' | cut -d '"' -f4)

if [ -z "$V" ]; then
    echo "ОШИБКА: версия Zapret не определена"
    exit 1
fi

echo "Устанавливается Zapret $V"

curl -fL "https://github.com/bol-van/zapret/releases/download/${V}/zapret-${V}.tar.gz" -o zapret.tar.gz

rm -rf /tmp/zapret-install
mkdir -p /tmp/zapret-install
tar -xzf zapret.tar.gz -C /tmp/zapret-install

D=$(find /tmp/zapret-install -type f -name install_easy.sh -printf '%h\n' | head -n1)

if [ -z "$D" ]; then
    echo "ОШИБКА: install_easy.sh не найден"
    exit 1
fi

cd "$D"

spawn ./install_easy.sh

expect {
    -re {select firewall type.*} {
        send "2\r"
        exp_continue
    }
    -re {your choice.*default.*nftables.*} {
        send "\r"
        exp_continue
    }
    -re {copy it for you.*\(Y/N\)} {
        send "Y\r"
        exp_continue
    }
    eof {
        catch wait result
        exit [lindex $result 3]
    }
}
EXPECT

echo "=== Установщик завершил работу ==="
systemctl status zapret --no-pager || true