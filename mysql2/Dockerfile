FROM mysql:8.0.26

ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.26-1debian10
ENV BINLOG_DIR /byung8/logs
ENV SOCKET_DIR /byung8/run
ENV BACKUP_DIR /byung8/backups

VOLUME /var/lib/mysql

COPY ./init_script/*.sql /docker-entrypoint-initdb.d/
COPY ./conf/my.cnf /etc/mysql/my.cnf

RUN apt-get update ; apt-get install -y procps

RUN chmod 664 /etc/mysql/my.cnf

RUN mkdir -p ${BINLOG_DIR} && \
    chmod 750 ${BINLOG_DIR} && \
    chown mysql:mysql ${BINLOG_DIR}

RUN mkdir -p ${SOCKET_DIR} && \
    chmod 750 ${SOCKET_DIR} && \
    chown mysql:mysql ${SOCKET_DIR}

RUN mkdir -p ${BACKUP_DIR} && \
    chmod 750 ${BACKUP_DIR} && \
    chown mysql:mysql ${BACKUP_DIR}

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]

