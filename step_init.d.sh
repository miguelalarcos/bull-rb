sudo cp etc_init.d/webrick /etc/init.d
sudo chmod +x /etc/init.d/webrick
sudo cp sh/webrick /usr/sbin
sudo chmod +x /usr/sbin/webrick
update-rc.d webrick defaults

sudo cp etc_init.d/websocket /etc/init.d
sudo chmod +x /etc/init.d/websocket
sudo cp sh/websocket /usr/sbin
sudo chmod +x /usr/sbin/websocket
update-rc.d websocket defaults

sudo cp instance1.conf /etc/rethinkdb/instances.d/
update-rc.d rethinkdb defaults