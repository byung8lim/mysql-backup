#FROM openjdk:11
FROM kube-01.byung8.com:5000/mysql:0.2

USER root
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 467B942D3A79BD29
RUN apt-get update && apt-get install -y software-properties-common
RUN apt-get install -y openjdk-11-jdk

ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.26-1debian10

RUN apt-get update
ARG TIMEZONE="Asia/Seoul"

ARG DEBIAN_FROMTEND=noninteracive
ENV TZ=Asia/Seoul
RUN apt-get install -y tzdata
RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

ADD awscli-bundle /awscli-bundle
#RUN apt-get install -y python-is-python3 default-mysql-client
#RUN apt-get install -y python3-pip default-mysql-client
#RUN apt-get install -y python3-venv
RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN apt-get install -y python3-venv
RUN apt-get install -y cron vim
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 0
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 0
RUN chmod +x /awscli-bundle/install
RUN /awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
RUN rm -rf /awscli-bundle
RUN ln -s /root/.local/bin/aws /usr/bin/aws

