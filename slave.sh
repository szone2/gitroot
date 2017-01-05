#!/bin/bash
#--------------------------------------------------------------
#Author:               shen
#*Email:               376176572@qq.com
#*Last modified:       2016-12-29 11:23
#*Filename:            slave.sh
#*Description:         auto install mysql replication slave
#*Version:             v1.0  
#--------------------------------------------------------------
#set nagios_server_IP
master_IP='192.168.0.141'
##check last command is OK or not.
check_ok() {
if [ $? != 0 ]
then
echo "Error, Check the error log."
exit 1
fi
}
##get the archive of the system,i686 or x86_64.
ar=`arch`
##close seliux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
selinux_s=`getenforce`
if [ $selinux_s == "Enforcing"  -o $selinux_s == "enforcing" ]
then
setenforce 0
fi
##close iptables
iptables-save > /etc/sysconfig/iptables_`date +%s`
iptables -F
service iptables save
##if the packge installed ,then omit.
myum() {
if ! rpm -qa|grep -q "^$1"
then
yum install -y $1
check_ok
else
echo $1 already installed.
fi
}
##function of check service is running or not, example nginx, httpd, php-fpm.
#check_service() {
#n=`ps aux |grep "$1"|wc -l`
#if [ $n -gt 1 ]
#then
#echo "$1 service is already started."
#else
#if [ -f /etc/init.d/$1 ]
#then
#/etc/init.d/$1 start
#check_ok
#else
#install_$1
#fi
#}
##function of installing mysqld mysql-version5.6.35.
install_mysqld() {
cd /usr/local/src
[ -f mysql-5.6.35-linux-glibc2.5-$ar.tar.gz ] || wget http://mirrors.sohu.com/mysql/MySQL-5.6/mysql-5.6.35-linux-glibc2.5-$ar.tar.gz
tar zxf mysql-5.6.35-linux-glibc2.5-$ar.tar.gz
check_ok
[ -d /usr/local/mysql ] && /bin/mv /usr/local/mysql /usr/local/mysql_bak
mv mysql-5.6.35-linux-glibc2.5-$ar /usr/local/mysql
if ! grep '^mysql:' /etc/passwd
then
useradd -M mysql -s /sbin/nologin
fi
myum compat-libstdc++-33
[ -d /data/mysql ] && /bin/mv /data/mysql /data/mysql_bak
mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql
cd /usr/local/mysql
./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
check_ok
/bin/cp support-files/my-default.cnf /etc/my.cnf
check_ok
sed -i '/^\[mysqld\]$/a\socket = /tmp/mysql.sock' /etc/my.cnf
sed -i '/^\[mysqld\]$/a\server_id = 2' /etc/my.cnf
sed -i '/^\[mysqld\]$/a\port = 3306' /etc/my.cnf
sed -i '/^\[mysqld\]$/a\datadir = /data/mysql' /etc/my.cnf
sed -i '/^\[mysqld\]$/a\basedir = /usr/local/mysql' /etc/my.cnf


/bin/cp support-files/mysql.server /etc/init.d/mysqld
sed -i 's#^basedir=#basedir=/usr/local/mysql#' /etc/init.d/mysqld
sed -i 's#^datadir=#datadir=/data/mysql#' /etc/init.d/mysqld
chmod 755 /etc/init.d/mysqld
chkconfig --add mysqld
chkconfig mysqld on
service mysqld start
check_ok
mysql -S /tmp/mysql.sock -e "create database db1;"
mysql -S /tmp/mysql.sock -e "exit"
cd /usr/tmp/
/usr/local/mysql/bin/mysqldump -S /tmp/mysql.sock mysql > 123.sql
mysql -S /tmp/mysql.sock db1 < 123.sql
check_ok
MYSQL_DIR=/usr/local/mysql/bin
MYSQL_USER='repl'
MYSQL_PW='123456'
MYSQL_CMD="$MYSQL_DIR/mysql -h$master_IP -u$MYSQL_USER -p$MYSQL_PW"
m_file=`$MYSQL_CMD -e "show master status\G" |awk 'NR==2 {print $2}'`
m_position=`$MYSQL_CMD -e "show master status\G" |awk 'NR==3 {print $2}'`
mysql -S /tmp/mysql.sock -e "stop slave;"
mysql -S /tmp/mysql.sock -e "change master to master_host='$master_IP',master_port=3306,master_user='$MYSQL_USER',master_password='$MYSQL_PW',master_log_file='$m_file',master_log_pos=$m_position;"
mysql -S /tmp/mysql.sock -e "start slave;"
$MYSQL_CMD -e "unlock tables;"
#$MYSQL_CMD -e "start slave;"
check_ok
}

#--start--
echo "It will install mysql_client."
sleep 3

#--step 1: close seliux--
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
selinux_s=`getenforce`
if [ $selinux_s == "Enforcing"  -o $selinux_s == "enforcing" ]
then
setenforce 0
fi
echo "[1/5]:close seliux OK"

#--step 2: close iptables--
iptables-save > /etc/sysconfig/iptables_`date +%s`
iptables -F
service iptables save
echo "[2/5]:close iptables OK"

#--step 3: install some packges.
for p in gcc wget perl perl-devel libaio libaio-devel pcre-devel zlib-devel
do
myum $p
done
echo "[3/5]:install some packges OK"

#--step 4: install epel.
if rpm -qa epel-release >/dev/null
then
    rpm -e epel-release
fi
if ls /etc/yum.repos.d/epel-6.repo* >/dev/null 2>&1
then
    rm -f /etc/yum.repos.d/epel-6.repo*
fi
wget -P /etc/yum.repos.d/ http://mirrors.aliyun.com/repo/epel-6.repo
echo "[4/5]:install epel OK" 

#--step 5: install mysqld.
install_mysqld
echo "[5/5]:install mysqld OK" 

