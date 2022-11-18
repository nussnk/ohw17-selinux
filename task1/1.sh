#!/bin/bash
exec > >(tee -i ohw17.log)
echo === отправим весь вывод в лог файл ohw17.log - "exec > >(tee -i ohw17.log)"
echo === ошибки тоже в лог файл - "exec 2>&1"
exec 2>&1

echo === на ВМ созданной через vagrant через провиженинг делаем:
echo === ставим epel-release - yum install epel-release -y
yum install epel-release -y
echo === ставим nginx и policycoreutils-python - yum install -y nginx policycoreutils-python
yum install -y nginx policycoreutils-python
echo === ===========================================================================================
echo === меняем порт на 9091 - sed -i 's/80;/9091;/g' /etc/nginx/nginx.conf
sed -i 's/80;/9091;/g' /etc/nginx/nginx.conf
echo === проверяем, что конфиг nginx в порядке - nginx -t 
nginx -t
echo === проверим, что firewall не запущен - systemctl status firewalld
systemctl status firewalld
echo === перезапускаем nginx - systemctl restart nginx
systemctl restart nginx
echo === в результате получим ошибку запуска
echo === проанализируем лог с помощью audit2why - "cat /var/log/audit/audit.log | grep 9091 | audit2why"
cat /var/log/audit/audit.log | grep 9091 | audit2why
echo === посмотрим в каком статусе selinux - getenforce
getenforce
echo === ===========================================================================================
echo === отрабатываем первый вариант - через setsebool
echo === зададим значение параметра nis_enabled равное единице - setsebool -P nis_enabled on
setsebool -P nis_enabled on
echo === проверим, что значение поменялось - "getsebool -a | grep nis_enabled"
getsebool -a | grep nis_enabled
echo === запускаем nginx и проверяем статус - "systemctl start nginx && systemctl status nginx"
systemctl start nginx && systemctl status nginx
echo === меняем значение параметра nis_enabled на 0 - setsebool -P nis_enabled off
setsebool -P nis_enabled off
echo === пробуем перезапустить nginx, должны получить ошибку - systemctl restart nginx
systemctl restart nginx
systemctl status nginx

echo === ===========================================================================================
echo === отрабатываем второй вариант исправления проблемы - с помощью добавление порта в имеющийся тип
echo === убедимся, что nginx не работает
systemctl status nginx
echo === проверяем имеющийся тип - "semanage port -l | grep http"
semanage port -l | grep http
echo === добавляем наш порт - semanage port -a -t http_port_t -p tcp 9091
semanage port -a -t http_port_t -p tcp 9091
echo === проверяем снова имеющийся тип - "semanage port -l | grep http"
semanage port -l | grep http
echo === запускаем nginx и проверяем статус - "systemctl start nginx && systemctl status nginx"
systemctl start nginx && systemctl status nginx
echo === теперь удалим порт и списка 
semanage port -d -t http_port_t -p tcp 9091
echo === проверяем имеющийся тип - "semanage port -l | grep http"
semanage port -l | grep http
echo === перезапускаем nginx, должны получить ошибку - systemctl restart nginx
systemctl restart nginx
systemctl status nginx
echo === ===========================================================================================
echo === отрабатываем третий вариант исправления проблемы - с помощью формирования и установки модуля SElinux
echo === убедимся, что nginx не работает
systemctl status nginx
echo === поменяем порт на 9092, чтобы отловить свежие ошибки запуска nginx - sed -i 's/9091;/9092;/g' /etc/nginx/nginx.conf
sed -i 's/9091;/9092;/g' /etc/nginx/nginx.conf
echo === теперь попробуем запустить nginx, чтобы получить свежую запись в audit.log - systemctl start nginx
systemctl start nginx
echo === грепаем ошибку и отправляем ее в audit2allow - "grep src=9092 /var/log/audit/audit.log | audit2allow -M nginx"
grep src=9092 /var/log/audit/audit.log | audit2allow -M nginx
echo === подключим созданный модуль - semodule -i nginx.pp
semodule -i nginx.pp
echo === запускаем nginx и проверяем статус - "systemctl start nginx && systemctl status nginx"

