#!/bin/bash

MBL=/usr/bin/mysqlbinlog
MYSQL_HOST=192.168.244.10
MYSQL_PORT=3306
MYSQL_USER=repl
MYSQL_PASS=repl123
BACKUP_DIR=/media/binlogs/server1/
FIRST_BINLOG=mysql-bin.000001

# time to wait before reconnecting after failure
RESPAWN=10

# create BACKUP_DIR if necessary
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

echo "Backup dir: $BACKUP_DIR"

while :
do
  if [ `ls -A "$BACKUP_DIR" |wc -l` -eq 0 ];then
      LAST_FILE="$FIRST_BINLOG"
  else
      LAST_FILE=`ls -l $BACKUP_DIR | tail -n 1 |awk '{print $9}'`
  fi

  echo "`date +"%Y/%m/%d %H:%M:%S"` starting binlog backup from $LAST_FILE"
  $MBL --read-from-remote-server --raw --stop-never --host=$MYSQL_HOST --port=$MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASS $LAST_FILE 
  echo "`date +"%Y/%m/%d %H:%M:%S"` mysqlbinlog exited with $? trying to reconnect in $RESPAWN seconds."
  sleep $RESPAWN
done