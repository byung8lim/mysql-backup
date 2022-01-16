FROM kube-01.byung8.com:5000/backup-base:0.1

RUN mkdir -p /mbs/logs
ADD conf /mbs/conf
ADD aws /mbs/.aws
ADD scripts /mbs/scripts
RUN useradd -s /bin/bash -d /mbs -u 1001 mbs
RUN chown -R mbs /mbs
RUN touch /mbs/logs/cron.log

RUN crontab -u root /mbs/conf/mbs.cron

ENTRYPOINT service cron start && tail -f /mbs/logs/cron.log

