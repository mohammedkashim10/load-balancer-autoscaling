#! /bin/bash

cd /home/ubuntu/app

pm2 start app.js

export DB_HOST=${db_host}
