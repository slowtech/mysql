#!/usr/bin/env python
# -*- coding: utf-8 -*-
import requests,json,time,datetime

API_URL = "http://192.168.244.128/zabbix/api_jsonrpc.php"
USER = "Admin"
PASSWORD = "zabbix"

class ZabbixAPI(object):
    def __init__(self, url, user, passwd, timeout=None):
        self.timeout = timeout
        self.url = url
        self.auth_id = self.get_auth_id(user, passwd)

    # HTTP请求
    def http_request(self, data, timeout=None):
        headers = {"Content-Type": "application/json"}
        request = requests.post(self.url, data=data, headers=headers, timeout=timeout)
        r = request.json()
        return r["result"]

    # 获取认证ID，所有的API请求都需要带上这个认证ID
    def get_auth_id(self, user, passwd):
        data = json.dumps({
            "jsonrpc": "2.0",
            "method": "user.login",
            "params": {
                "user": user,
                "password": passwd
            },
            "id": 0
        })
        return self.http_request(data=data)

    # 基于主机名获取hostid
    def host_get(self, host):
        data = json.dumps({
            "jsonrpc": "2.0",
            "method": "host.get",
            "params": {
                "output": ["hostid"],
                "filter": {"host": host}
            },
            "auth": self.auth_id,
            "id": 1,
        })
        result = self.http_request(data=data)
        return result[0].get('hostid')

    # 设置维护策略，其中，duration是维护周期，默认24h
    def maintenance_create(self, host, duration=24):
        data = json.dumps({
            "jsonrpc": "2.0",
            "method": "maintenance.create",
            "params": {
                "name": host,
                "active_since": int(time.time()),
                "active_till": int(time.time()) + duration * 3600,
                "hostids": [
                    self.host_get(host)
                ],
                "timeperiods": [
                    {
                        "timeperiod_type": 0,
                        "period": duration * 3600,
                    }
                ]
            },
            "auth": self.auth_id,
            "id": 1
        })
        return self.http_request(data=data)

    # 获取指定时间段的告警信息
    def problem_get(self,time_from):
        data = json.dumps({
            "jsonrpc": "2.0",
            "method": "problem.get",
            "params": {
                "output": ["eventid","objectid","clock","name","severity"],
                "sortfield": ["eventid"],
                "sortorder": "DESC", 
                "time_from": time_from,
                #"limit": 1001
            },
            "auth": self.auth_id,
            "id": 1
        })
        return self.http_request(data=data)

    # 基于triggerid获取触发对象
    def trigger_get(self,trigger_ids):
        data = json.dumps({
            "jsonrpc": "2.0",
            "method": "trigger.get",
            "params": {
                 "triggerids": trigger_ids,
                 "output": ['triggerid'],
                 "monitored": 1,
                 "skipDependent":1,
                 "selectHosts": ['name'],
                  "filter": {
                       "value": 1
                   }
          },
          "auth": self.auth_id,
          "id": 1
        })
        return self.http_request(data=data)

#格式化秒数
def format_second(seconds):
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)
    if days !=0:
      result="%dd %dh %dm %ds"%(days, hours, minutes, int(seconds))
    elif hours !=0:
      result="%dh %dm %ds"%(hours, minutes, int(seconds))
    elif minutes !=0:
      result="%dm %ds"%(minutes, int(seconds))
    else:
      result="%ds"%(int(seconds))
    return result

def main():
    zabbix_client=ZabbixAPI(API_URL,USER,PASSWORD)
    hostid=zabbix_client.host_get("node1")
    print hostid
    
    zabbix_client.maintenance_create("node1",12)

    time_from=int(time.mktime((datetime.datetime.now() - datetime.timedelta(days=10)).timetuple()))
    problem_result=zabbix_client.problem_get(time_from)

    trigger_ids=[each_problem["objectid"]for each_problem in problem_result] 

    trigger_info={}
    for each_trigger in zabbix_client.trigger_get(trigger_ids):
        triggerid=each_trigger['triggerid']
        hostname=each_trigger['hosts'][0]['name']
        trigger_info[triggerid]=hostname

    for each_problem in problem_result:
        problem_time=int(each_problem["clock"])
        trigger_id=each_problem["objectid"]
        problem_name=each_problem["name"]
        problem_time_format=datetime.datetime.fromtimestamp(problem_time).strftime('%Y-%m-%d %H:%M:%S')
        host=trigger_info[trigger_id]
        last_time=format_second(time.time()-problem_time)
        print problem_time_format,host,problem_name,last_time

if __name__ == "__main__":
    main()
