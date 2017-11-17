#!/bin/bash
SQL="/tmp/partition.sql"
HISTORY_KEEP_DAYS=30
TREND_KEEP_MONTHS=12
ZABBIX_VERSION=2

cur_year=`date +"%Y"`
next_year=$cur_year
cur_month=`date +"%m"|sed 's/^0*//'`
if [ $cur_month -eq 12 ]; then
	next_year=$((cur_year+1))
	cur_month=1
fi

DAILY="history history_log history_str history_text history_uint"
MONTHLY="trends trends_uint" 

echo "Use zabbix;" > $SQL
echo -en "\n" >>$SQL

if [ $ZABBIX_VERSION != 3 ]; then
cat >>$SQL <<_EOF_
ALTER TABLE history_log DROP KEY history_log_2;
ALTER TABLE history_log ADD KEY history_log_2(itemid, id);
ALTER TABLE history_log DROP PRIMARY KEY ;
ALTER TABLE history_log ADD KEY history_logid (id);
ALTER TABLE history_text DROP KEY history_text_2;
ALTER TABLE history_text ADD KEY history_text_2 (itemid, clock);
ALTER TABLE history_text DROP PRIMARY KEY ;
ALTER TABLE history_text ADD KEY history_textid (id);
_EOF_
fi

echo -en "\n" >>$SQL
for i in $MONTHLY; do
	echo "ALTER TABLE $i PARTITION BY RANGE( clock ) (" >>$SQL
	for y in `seq $cur_year $next_year`; do
		next_month=12
		[ $y -eq $next_year ] && next_month=$((cur_month+1))
		for m in `seq 1 $next_month`; do
			[ $m -lt 10 ] && m="0$m"
			ms=`date +"%Y-%m-01" -d "$m/01/$y +1 month"`
			pname="p${y}${m}"
			echo -n "PARTITION $pname  VALUES LESS THAN (UNIX_TIMESTAMP(\"$ms 00:00:00\"))" >>$SQL
			[ $m -ne $next_month -o $y -ne $next_year ] && echo -n "," >>$SQL
			echo -ne "\n" >>$SQL
		done
	done
	echo ");" >>$SQL
        echo -en "\n" >>$SQL
done

for i in $DAILY; do
	echo "ALTER TABLE $i PARTITION BY RANGE( clock ) (" >>$SQL
	for d in `seq -$HISTORY_KEEP_DAYS 2`; do
		ds=`date +"%Y-%m-%d" -d "$d day +1 day"`
		pname=`date +"%Y%m%d" -d "$d day"`
		echo -n "PARTITION p$pname  VALUES LESS THAN (UNIX_TIMESTAMP(\"$ds 00:00:00\"))" >>$SQL
		[ $d -ne 2 ] && echo -n "," >>$SQL
		echo -ne "\n" >>$SQL
	done
	echo ");" >>$SQL
        echo -en "\n" >>$SQL
done


###############################################################
echo -en "\n" >>$SQL
cat >>$SQL <<_EOF_
DELIMITER //
DROP PROCEDURE IF EXISTS zabbix.create_zabbix_partitions; //
CREATE PROCEDURE zabbix.create_zabbix_partitions ()
BEGIN
_EOF_

for i in $DAILY; do
	echo "	CALL zabbix.create_next_partitions(\"zabbix\",\"$i\");" >>$SQL
	echo "	CALL zabbix.drop_old_partitions(\"zabbix\",\"$i\");" >>$SQL
done

for i in $MONTHLY; do
	echo "	CALL zabbix.create_next_monthly_partitions(\"zabbix\",\"$i\");" >>$SQL
	echo "	CALL zabbix.drop_old_monthly_partitions(\"zabbix\",\"$i\");" >>$SQL
done

echo -en "\n" >>$SQL
cat >>$SQL <<_EOF_
END //

DROP PROCEDURE IF EXISTS zabbix.create_next_partitions; //
CREATE PROCEDURE zabbix.create_next_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE NEXTCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @totaldays = 7;
	SET @i = 1;
	createloop: LOOP
		SET NEXTCLOCK = DATE_ADD(NOW(),INTERVAL @i DAY);
		SET PARTITIONNAME = DATE_FORMAT( NEXTCLOCK, 'p%Y%m%d' );
		SET CLOCK = UNIX_TIMESTAMP(DATE_FORMAT(DATE_ADD( NEXTCLOCK ,INTERVAL 1 DAY),'%Y-%m-%d 00:00:00'));
		CALL zabbix.create_partition( SCHEMANAME, TABLENAME, PARTITIONNAME, CLOCK );
		SET @i=@i+1;
		IF @i > @totaldays THEN
			LEAVE createloop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.drop_old_partitions; //
CREATE PROCEDURE zabbix.drop_old_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE OLDCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @mindays = $HISTORY_KEEP_DAYS;
	SET @maxdays = @mindays+4;
	SET @i = @maxdays;
	droploop: LOOP
		SET OLDCLOCK = DATE_SUB(NOW(),INTERVAL @i DAY);
		SET PARTITIONNAME = DATE_FORMAT( OLDCLOCK, 'p%Y%m%d' );
		CALL zabbix.drop_partition( SCHEMANAME, TABLENAME, PARTITIONNAME );
		SET @i=@i-1;
		IF @i <= @mindays THEN
			LEAVE droploop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.create_next_monthly_partitions; //
CREATE PROCEDURE zabbix.create_next_monthly_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE NEXTCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @totalmonths = 3;
	SET @i = 1;
	createloop: LOOP
		SET NEXTCLOCK = DATE_ADD(NOW(),INTERVAL @i MONTH);
		SET PARTITIONNAME = DATE_FORMAT( NEXTCLOCK, 'p%Y%m' );
		SET CLOCK = UNIX_TIMESTAMP(DATE_FORMAT(DATE_ADD( NEXTCLOCK ,INTERVAL 1 MONTH),'%Y-%m-01 00:00:00'));
		CALL zabbix.create_partition( SCHEMANAME, TABLENAME, PARTITIONNAME, CLOCK );
		SET @i=@i+1;
		IF @i > @totalmonths THEN
			LEAVE createloop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.drop_old_monthly_partitions; //
CREATE PROCEDURE zabbix.drop_old_monthly_partitions (SCHEMANAME varchar(64), TABLENAME varchar(64))
BEGIN
	DECLARE OLDCLOCK timestamp;
	DECLARE PARTITIONNAME varchar(16);
	DECLARE CLOCK int;
	SET @minmonths = $TREND_KEEP_MONTHS;
	SET @maxmonths = @minmonths+24;
	SET @i = @maxmonths;
	droploop: LOOP
		SET OLDCLOCK = DATE_SUB(NOW(),INTERVAL @i MONTH);
		SET PARTITIONNAME = DATE_FORMAT( OLDCLOCK, 'p%Y%m' );
		CALL zabbix.drop_partition( SCHEMANAME, TABLENAME, PARTITIONNAME );
		SET @i=@i-1;
		IF @i <= @minmonths THEN
			LEAVE droploop;
		END IF;
	END LOOP;
END //

DROP PROCEDURE IF EXISTS zabbix.create_partition; //
CREATE PROCEDURE zabbix.create_partition (SCHEMANAME varchar(64), TABLENAME varchar(64), PARTITIONNAME varchar(64), CLOCK int)
BEGIN
	DECLARE RETROWS int;
	SELECT COUNT(1) INTO RETROWS
		FROM information_schema.partitions
		WHERE table_schema = SCHEMANAME AND table_name = TABLENAME AND partition_name = PARTITIONNAME;

	IF RETROWS = 0 THEN
		SELECT CONCAT( "create_partition(", SCHEMANAME, ",", TABLENAME, ",", PARTITIONNAME, ",", CLOCK, ")" ) AS msg;
     		SET @sql = CONCAT( 'ALTER TABLE ', SCHEMANAME, '.', TABLENAME, 
				' ADD PARTITION (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', CLOCK, '));' );
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	END IF;
END //

DROP PROCEDURE IF EXISTS zabbix.drop_partition; //
CREATE PROCEDURE zabbix.drop_partition (SCHEMANAME varchar(64), TABLENAME varchar(64), PARTITIONNAME varchar(64))
BEGIN
	DECLARE RETROWS int;
	SELECT COUNT(1) INTO RETROWS
		FROM information_schema.partitions
		WHERE table_schema = SCHEMANAME AND table_name = TABLENAME AND partition_name = PARTITIONNAME;

	IF RETROWS = 1 THEN
		SELECT CONCAT( "drop_partition(", SCHEMANAME, ",", TABLENAME, ",", PARTITIONNAME, ")" ) AS msg;
     		SET @sql = CONCAT( 'ALTER TABLE ', SCHEMANAME, '.', TABLENAME,
				' DROP PARTITION ', PARTITIONNAME, ';' );
		PREPARE STMT FROM @sql;
		EXECUTE STMT;
		DEALLOCATE PREPARE STMT;
	END IF;
END //
DELIMITER ;

SET @@global.event_scheduler = on;

CREATE EVENT maintain_partition
    ON SCHEDULE
      EVERY 1 DAY
    COMMENT 'maintain zabbix partition tables every day'
    DO CALL zabbix.create_zabbix_partitions();

_EOF_

echo "Bingo! Do not forget to set event_scheduler=on in my.cnf and disable Housekeeping"
