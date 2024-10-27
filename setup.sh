#!/bin/bash

# Удаление контейнеров, если они уже существуют
docker rm -f centos1 centos2 2>/dev/null

# Функция для настройки контейнера с обновленными репозиториями и запуском nginx и haproxy
setup_container() {
    container_name=$1
    haproxy_port=$2

    # Запуск контейнера с командой, чтобы он оставался активным
    docker run -d --name "$container_name" centos:7 tail -f /dev/null

    # Обновление репозиториев до архива
    docker exec "$container_name" bash -c 'sed -i "s|mirrorlist=http://mirrorlist.centos.org|#mirrorlist=http://mirrorlist.centos.org|g" /etc/yum.repos.d/CentOS-Base.repo'
    docker exec "$container_name" bash -c 'sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-Base.repo'

    # Установка EPEL репозитория
    docker exec "$container_name" yum install -y epel-release

    # Установка пакетов nginx и haproxy
    docker exec "$container_name" yum clean all
    docker exec "$container_name" yum makecache fast
    docker exec "$container_name" yum install -y nginx haproxy

    # Создание конфигурационного файла для haproxy
    docker exec "$container_name" bash -c "cat <<EOL > /etc/haproxy/haproxy.cfg
defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http-in
    bind *:${haproxy_port}
    default_backend servers

backend servers
    server server1 127.0.0.1:8080 maxconn 32
EOL"

    # Запуск nginx и haproxy
    docker exec "$container_name" nginx
    docker exec "$container_name" haproxy -f /etc/haproxy/haproxy.cfg
}

# Функция для проверки доступности веб-серверов
check_availability() {
    for container in "$@"; do
        echo "Проверка доступности веб-серверов в контейнере $container..."
        if docker exec "$container" curl -s --head http://127.0.0.1:80 | grep "200 OK" > /dev/null; then
            echo "Веб-сервер в контейнере $container доступен."
        else
            echo "Веб-сервер в контейнере $container недоступен."
        fi
    done
}

# Вызов функции для настройки контейнеров с уникальными портами для haproxy
setup_container "centos1" 8081
setup_container "centos2" 8082

# Проверка доступности веб-серверов
check_availability "centos1" "centos2"

echo "Настройка завершена."
