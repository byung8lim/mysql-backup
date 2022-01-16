FROM openjdk:11

RUN apt-get update

ARG TIMEZONE="Asia/Seoul"

ARG DEBIAN_FROMTEND=noninteracive
ENV TZ=Asia/Seoul
RUN apt-get install -y tzdata
RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

ADD awscli-bundle /awscli-bundle
RUN apt-get install -y python-is-python3 default-mysql-client
RUN apt-get install -y python3-pip default-mysql-client
RUN apt-get install -y python3-venv
RUN apt-get install -y cron vim

RUN /awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
RUN rm -rf /awscli-bundle
RUN ln -s /root/.local/bin/aws /usr/bin/aws

