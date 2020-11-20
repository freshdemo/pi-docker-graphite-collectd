FROM   sdhibit/rpi-raspbian:jessie

# ---------------- #
#   Installation   #
# ---------------- #
#WORKDIR /sizer

RUN	apt-get update && apt-get upgrade -y

# Install all prerequisites
RUN  apt-get install --assume-yes apt-transport-https git libffi-dev wget nginx vim inetutils-ping collectd collectd-utils snmpd libapr1 libaprutil1 libaprutil1-dbd-sqlite3 python3 libpython3.4 python3-minimal libaprutil1-ldap memcached python-cairo-dev python-ldap python-memcache python-pysqlite2 python-dev sqlite3 erlang-os-mon erlang-snmp rabbitmq-server bzr expect ssh python-setuptools sudo python-setuptools python-pip python gcc libperl-dev

RUN  python -m pip install --upgrade pip &&\
     pip install --upgrade setuptools &&\
     pip install django==1.11.12 
#     pip install whisper==1.1.3 &&\
#     pip install carbon==1.1.3 &&\
#     pip install graphite-web==1.1.3 

RUN  git clone -b v0.8.0 --depth 1 https://github.com/etsy/statsd.git /opt/statsd

RUN  git clone -b 1.1.3 --depth 1 https://github.com/graphite-project/whisper.git /usr/local/src/whisper 
WORKDIR /usr/local/src/whisper
RUN  python ./setup.py install

RUN  git clone -b 1.1.3 --depth 1 https://github.com/graphite-project/carbon.git /usr/local/src/carbon
WORKDIR /usr/local/src/carbon
RUN  pip install -r requirements.txt && python ./setup.py install

RUN  git clone -b 1.1.3 --depth 1 https://github.com/graphite-project/graphite-web.git /usr/local/src/graphite-web
WORKDIR /usr/local/src/graphite-web
RUN  pip install -r requirements.txt && python ./setup.py install


# config graphite
ADD conf/opt/graphite/conf/*.conf /opt/graphite/conf/
ADD conf/opt/graphite/webapp/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
# ADD conf/opt/graphite/webapp/graphite/app_settings.py /opt/graphite/webapp/graphite/app_settings.py
WORKDIR /opt/graphite/webapp
RUN mkdir -p /var/log/graphite/ \
  && PYTHONPATH=/opt/graphite/webapp django-admin.py collectstatic --noinput --settings=graphite.settings

# config statsd
ADD conf/opt/statsd/config_*.js /opt/statsd/

# config nginx
RUN rm /etc/nginx/sites-enabled/default
ADD conf/etc/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/etc/nginx/sites-enabled/graphite-statsd.conf /etc/nginx/sites-enabled/graphite-statsd.conf

# init django admin
ADD conf/usr/local/bin/django_admin_init.exp /usr/local/bin/django_admin_init.exp
ADD conf/usr/local/bin/manage.sh /usr/local/bin/manage.sh
RUN chmod +x /usr/local/bin/manage.sh && /usr/local/bin/django_admin_init.exp

# config collectd
WORKDIR /root/
RUN wget http://sourceforge.net/projects/net-snmp/files/net-snmp/5.7.3/net-snmp-5.7.3.tar.gz &&\
    tar -xvzf net-snmp-5.7.3.tar.gz &&\
    cd net-snmp-5.7.3 &&\
    ./configure && make && make install
ADD conf/snmp/ /root/.snmp/mibs/


# logging support
RUN mkdir -p /var/log/carbon /var/log/graphite /var/log/nginx
ADD conf/etc/logrotate.d/graphite-statsd /etc/logrotate.d/graphite-statsd

# daemons
ADD conf/etc/service/carbon/run /etc/service/carbon/run
ADD conf/etc/service/carbon-aggregator/run /etc/service/carbon-aggregator/run
ADD conf/etc/service/graphite/run /etc/service/graphite/run
ADD conf/etc/service/statsd/run /etc/service/statsd/run
ADD conf/etc/service/nginx/run /etc/service/nginx/run

# default conf setup
ADD conf /etc/graphite-statsd/conf
ADD conf/etc/my_init.d/01_conf_init.sh /etc/my_init.d/01_conf_init.sh

RUN cp /usr/share/zoneinfo/Canada/Eastern /etc/localtime

ADD my_init /sbin/my_init

# cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# defaults
EXPOSE 80 2003-2004 2023-2024 8080 8125 8125/udp 8126
VOLUME ["/opt/graphite/conf", "/opt/graphite/storage", "/opt/graphite/webapp/graphite/functions/custom", "/etc/nginx", "/opt/statsd", "/etc/logrotate.d", "/var/log"]
WORKDIR /
ENV HOME /root
ENV STATSD_INTERFACE udp

#CMD ["/sbin/my_init"]
