#FROM mysql
FROM mysql:8.0.26

ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.26-1debian10

VOLUME /var/lib/mysql

COPY ./init_script/*.sql /docker-entrypoint-initdb.d/
COPY ./conf/my.cnf /etc/mysql/my.cnf

RUN apt-get update ; apt-get install -y procps

RUN chmod 664 /etc/mysql/my.cnf

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]

