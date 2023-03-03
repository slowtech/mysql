#!/usr/bin/python
# -*- coding:UTF-8 -*-
import pymysql, threading, time

node1 = "192.168.244.10"
node2 = "192.168.244.20"
port = 3306
user = "root"
password = "123456"


def execute(host, sql):
    conn = pymysql.connect(host=host, port=port, user=user, password=password,
                           autocommit=False)
    cursor = conn.cursor()
    cursor.execute(sql)
    result = cursor.fetchall()
    return conn, cursor, result


def commit(host, conn, cursor):
    try:
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(host, e)


i = 0
while True:
    conn1, cursor1, _ = execute(node1, "update slowtech.t1 set c1=%d where id=1" % (2 * i))
    conn2, cursor2, _ = execute(node2, "update slowtech.t1 set c1=%d where id=1" % (2 * i + 1))
    t1 = threading.Thread(target=commit, args=(node1, conn1, cursor1,))
    t2 = threading.Thread(target=commit, args=(node2, conn2, cursor2,))
    t1.start()
    #time.sleep(0.05)
    t2.start()
    t1.join()
    t2.join()
    i = i + 1
    time.sleep(0.2)
    _, _, result1 = execute(node1, "select c1 from slowtech.t1 where id=1")
    _, _, result2 = execute(node2, "select c1 from slowtech.t1 where id=1")
    print(result1[0][0], result2[0][0])
