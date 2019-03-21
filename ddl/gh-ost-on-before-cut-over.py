#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os,yagmail
GH_OST_MIGRATED_HOST=os.environ.get('GH_OST_MIGRATED_HOST')
GH_OST_DATABASE_NAME=os.environ.get('GH_OST_DATABASE_NAME')
GH_OST_TABLE_NAME=os.environ.get('GH_OST_TABLE_NAME')
GH_OST_DDL=os.environ.get('GH_OST_DDL')

message_head="Before cut-over:"+"h="+GH_OST_MIGRATED_HOST+",D="+GH_OST_DATABASE_NAME+",t="+GH_OST_TABLE_NAME+"DDL: "+GH_OST_DDL
yag = yagmail.SMTP(user='slowtech@126.com',password='******',host='smtp.126.com')
contents = [message_head]
yag.send('ivictor@foxmail.com', message_head, contents)
