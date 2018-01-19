FROM ubuntu:trusty
MAINTAINER Will McKeigney <wmckeigney@gmail.com>

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get curl -y


#Tick Stack (Telegraf, InfluxDB, Chronograf & Kapacitor) Install

RUN curl -sL https://repos.influxdata.com/influxdb.key | apt-key add
RUN source /etc/lsb-release
RUN echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" tee /etc/apt/sources.list.d/influxdb.list

#update package list since influxdata repo was added
RUN apt-get update

#InfluxDB install
RUN apt-get install influxdb -y

#start influxDB
RUN systemctl start influxdb

#Configure user for influxDB
curl -i -XPOST http://localhost:8086/query --data-urlencode "q=CREATE USER "mdyson" WITH PASSWORD 'passw0rd' WITH ALL PRIVILEGES"

#Edit InfluxDB configuration file /etc/influxdb/influxdb.conf and enable authentication
RUN sed -i 's/# auth-enabled = false/auth-enabled = true/g' /etc/influxdb/influxdb.conf

#Start InfluxDB service
RUN systemctl restart influxdb

#Telegraf Install
RUN apt-get install telegraf -y

#Set username and password in /etc/telegraf/telegraf.conf to connect to InfluxDB
RUN sed -i 's/# username = "telegraf"/username = "mdyson"/g' /etc/telegraf/telegraf.conf
RUN sed -i 's/# password = "metricsmetricsmetricsmetrics"/password = "passw0rd"/g' /etc/telegraf/telegraf.conf

#Start Telegraf services
RUN systemctl restart telegraf

#Kapacitor Install
RUN apt-get install kapacitor

#Set username and password in /etc/kapacitor/kapacitor.conf to connect to InfluxDB
RUN sed -i 's/username = ""/username = "mdyson"/g' /etc/kapacitor/kapacitor.conf
RUN sed -i 's/password = ""/password = "passw0rd"/g' /etc/kapacitor/kapacitor.conf

#Start Kapacitor service
RUN systemctl start kapacitor

#Chronograf Install
RUN wget https://dl.influxdata.com/chronograf/releases/chronograf_1.3.10.0_amd64.deb

#Unpack deb file
RUN dpkg -i chronograf_1.3.10.0_amd64.deb

#Start Chronograf service
RUN systemctl start chronograf

#Open Ubuntu Firewall port for Chronofrag
RUN ufw allow 8888/tcp

EXPOSE 8086 8888
