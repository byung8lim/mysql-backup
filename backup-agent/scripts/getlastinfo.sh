#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')
BACKUP_PREFIX=$(grep 'BACKUP_PREFIX' $CONF | awk -F '=' '{print $2}')
LOGFILE="$HOME/logs/list-$(date +%Y%m%d).log"
LASTINFO="$HOME/logs/last.txt"

function log() {
  echo "[$(date +%F.%T.%3N)][INFO] $*" >> $LOGFILE
}

function warn() {
  echo "[$(date +%F.%T.%3N)][WARN] $*" >> $LOGFILE
}

function error() {
  echo "[$(date +%F.%T.%3N)][ERROR] $*" >> $LOGFILE
}

if [ -f $LASTINFO ];then
  rm -f $LASTINFO
fi

echo "OBJ_STORAGE_URL: $OBJ_STORAGE_URL"
echo "BUCKET_NAME: $BUCKET_NAME"
echo "NAMESPACE: $NAMESPACE"

echo "aws --endpoint-url=$OBJ_STORAGE_URL s3 cp s3://$BUCKET_NAME/$NAMESPACE/backups/info.txt $LASTINFO"
aws --endpoint-url=$OBJ_STORAGE_URL s3 cp s3://$BUCKET_NAME/$NAMESPACE/backups/info.txt $LASTINFO
