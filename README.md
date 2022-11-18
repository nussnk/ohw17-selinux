### ohw17-selinux

# Задача №1. Запустить nginx на нестандартном порту 3-мя разными способами
# Подготовка
Разворачиваем ВМ
Провиженинг запускает скрипт 1.sh, который установит все нужные пакеты и выполнит все три метода решения проблемы с нестандартным портом nginx
Результат работы скрипта, он же подробный лог решения задачи, можно прочитать в файле /home/vagrant/owh17.log

# Задача №2. Обеспечить работоспособность приложения при включенном selinux.
Второй таск домашнего задания по теме SElinux

Разворачиваем стенд с проблемными ВМ
создадим папку task2, зайдем в нее и скачаем репозиторий git-а
```
mkdir task2
cd task2
git clone https://github.com/mbfx/otus-linux-adm .
```
Перейдем в папку с нужным нам проектом otus-linux-adm/selinux_dns_problems
Развернем структуру ВМ с помощью vagrant up
посмотрим вывод vagrant status:
```
root@kim-test:/home/nikolay/otus/ohw17-selinux/task2# vagrant status    
Current machine states:

ns01                      running (virtualbox)
client                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
root@kim-test:/home/nikolay/otus/ohw17-selinux/task2#
```
Заходим на client ВМ
```vagrant ssh client

root@kim-test:/home/nikolay/otus/ohw17-selinux/task2# vagrant ssh client
Last login: Fri Nov 18 19:24:33 2022 from 10.0.2.2
###############################
### Welcome to the DNS lab! ###
###############################

- Use this client to test the enviroment
- with dig or nslookup. Ex:
    dig @192.168.50.10 ns01.dns.lab

- nsupdate is available in the ddns.lab zone. Ex:
    nsupdate -k /etc/named.zonetransfer.key
    server 192.168.50.10
    zone ddns.lab
    update add www.ddns.lab. 60 A 192.168.50.15
    send

- rndc is also available to manage the servers
    rndc -c ~/rndc.conf reload

###############################
### Enjoy! ####################
###############################
```

Попробуем выполнить обновление DNS зоны
```[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
```
Проверим журнал на ошибки
```[vagrant@client ~]$ sudo -i
[root@client ~]# cat /var/log/audit/audit.log | audit2why
[root@client ~]#
```
Ошибок нет. Переходим на сервер и проверим audit.log файл там
```[root@client ~]# logout
[vagrant@client ~]$ logout
Connection to 127.0.0.1 closed.
root@kim-test:/home/nikolay/otus/ohw17-selinux/task2# vagrant ssh ns01
Last login: Fri Nov 18 19:16:47 2022 from 10.0.2.2
[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1668799956.039:1881): avc:  denied  { create } for  pid=5019 comm="isc-worker0000" na
me="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0
tclass=file permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.

[root@ns01 ~]#
```
Видим ошибку в контексте безопасности. Указан контекст etc_t, вместо named_t
Перепроверим:
```[root@ns01 ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
[root@ns01 ~]#
```
Поменяем тип контекста безопасности для всей директории /etc/named
```sudo chcon -R -t named_zone_t /etc/named```

Возвращаемся в ВМ client
Пробуем еще раз обновить зону
```[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
>
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[vagrant@client ~]$
Все получается
[vagrant@client ~]$ nslookup www.ddns.lab
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   www.ddns.lab
Address: 192.168.50.15

[vagrant@client ~]$
```
Перезагружаемся, чтобы убедиться, что все работает и после растарта

```[vagrant@client ~]$ sudo reboot
Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
root@kim-test:/home/nikolay/otus/ohw17-selinux/task2# vagrant ssh ns01
Last login: Fri Nov 18 19:36:26 2022 from 10.0.2.2
[vagrant@ns01 ~]$ sudo reboot
Connection to 127.0.0.1 closed by remote host.
Connection to 127.0.0.1 closed.
root@kim-test:/home/nikolay/otus/ohw17-selinux/task2#
```

Заходим на client и проверяет еще раз
```dig @192.168.50.10 www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.10 <<>> @192.168.50.10 www.ddns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 37071
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; AUTHORITY SECTION:
ddns.lab.               3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10

;; Query time: 7 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Nov 18 21:40:57 UTC 2022
;; MSG SIZE  rcvd: 96

[vagrant@client ~]$
```
Восстановим дефолтные значения контекста безопасности для /etc/named и проверим через ls
```[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# restorecon -v -R /etc/named
restorecon reset /etc/named context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.dns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.dns.lab.view1 context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic context unconfined_u:object_r:named_zone_t:s0->unconfined_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab.view1 context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/dynamic/named.ddns.lab.view1.jnl context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.newdns.lab context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
restorecon reset /etc/named/named.50.168.192.rev context system_u:object_r:named_zone_t:s0->system_u:object_r:etc_t:s0
[root@ns01 ~]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
[root@ns01 ~]#
```

