#!/usr/bin/env bash

sudo cp etc_init.d/rethinkdbdaemon /etc/init.d
sudo chmod +x /etc/init.d/rethinkdbdaemon
sudo cp sh/rethinkdbdaemon /usr/sbin
sudo chmod +x /usr/sbin/rethinkdbdaemon
sudo update-rc.d rethinkdbdaemon defaults

sudo cp etc_init.d/webrickdaemon /etc/init.d
sudo chmod +x /etc/init.d/webrickdaemon
sudo cp sh/webrickdaemon /usr/sbin
sudo chmod +x /usr/sbin/webrickdaemon
sudo update-rc.d webrickdaemon defaults

sudo cp etc_init.d/websocketdaemon /etc/init.d
sudo chmod +x /etc/init.d/websocketdaemon
sudo cp sh/websocketdaemon /usr/sbin
sudo chmod +x /usr/sbin/websocketdaemon
sudo update-rc.d websocketdaemon defaults


