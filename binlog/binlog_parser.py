#!/usr/bin/python
# -*- coding: utf-8 -*-
from __future__ import print_function
import pymysql
from pymysqlreplication import BinLogStreamReader
from pymysqlreplication.row_event import (
    DeleteRowsEvent,
    UpdateRowsEvent,
    WriteRowsEvent
)
from pymysqlreplication.event import (QueryEvent, XidEvent)

host = "192.168.244.10"
port = 3306
user = "repl_user"
passwd = "repl_pass"

mysql_settings = {'host': host, 'port': port, 'user': user, 'passwd': passwd}

stream = BinLogStreamReader(connection_settings=mysql_settings, server_id=100, blocking=True)

conn = pymysql.connect(host, user, passwd, port=port, charset='utf8', autocommit=False)
cursor = conn.cursor()

for binlog_event in stream:
    if isinstance(binlog_event, QueryEvent) and binlog_event.query == "BEGIN":
        print("BEGIN;")
    elif isinstance(binlog_event, (DeleteRowsEvent, UpdateRowsEvent, WriteRowsEvent)):
        table_schema = binlog_event.schema
        table_name = binlog_event.table
        rows = binlog_event.rows
        if isinstance(binlog_event, DeleteRowsEvent):
            for each_row in rows:
                col_name = ' AND '.join(
                    ['`%s`=%%s' % (k) if v != None else '`%s` is %%s' % (k) for k, v in each_row['values'].iteritems()])
                delete_sql = "DELETE FROM `{0}`.`{1}` WHERE {2};".format(table_schema, table_name, col_name)
                print(cursor.mogrify(delete_sql, each_row['values'].values()))
        elif isinstance(binlog_event, WriteRowsEvent):
            for each_row in rows:
                col_name = ','.join('`%s`' % (k) for k in each_row['values'].keys())
                format_str = ','.join('%s' for k in each_row['values'].keys())
                insert_sql = 'INSERT INTO `{0}`.`{1}` ({2}) VALUES ({3});'.format(table_schema, table_name, col_name,
                                                                                  format_str)
                print(cursor.mogrify(insert_sql, each_row['values'].values()))
        elif isinstance(binlog_event, UpdateRowsEvent):
            for each_row in rows:
                before_values = each_row["before_values"]
                after_values = each_row["after_values"]
                set_str = ','.join(
                    ['`%s`=%%s' % (k) for k, v in after_values.iteritems()])
                where_str = ' AND '.join(
                    ['`%s`=%%s' % (k) if v != None else '`%s` is %%s' % (k) for k, v in before_values.iteritems()])
                update_sql = "UPDATE `{0}`.`{1}` SET {2} WHERE {3};".format(table_schema, table_name, set_str,
                                                                            where_str)
                values = list(after_values.values()) + list(before_values.values())
                print(cursor.mogrify(update_sql, values))
    elif isinstance(binlog_event, XidEvent):
        print("COMMIT;\n")
stream.close()
cursor.close()
conn.close()
