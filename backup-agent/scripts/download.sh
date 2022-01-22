#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
BACKUP_DIR="$BASE/backups"
DEFAULTS_FILE="$HOME/conf/client.cnf"

unset BACKUP_SOURCE
unset BACKUP_DESTINATION
unset BINLOG_DESTINATION
unset OBJ_STORAGE_URL
unset BUCKET_NAME
if [ $# -eq 0 ];then
  echo "Backup Source should be defined as argument of download_backup.sh"
  exit 1
else
  BACKUP_SOURCE=$1
fi

OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')

S3_DIR="binlog"
BINLOG_DIR="$BASE/logs"

echo "NAMESPACE: $NAMESPACE"
echo "BACKUP_SOURCE: $BACKUP_SOURCE"
echo "backup downoad path: $BACKUP_DIR/$BACKUP_SOURCE"
echo "binglog download path: $BACKUP_DIR/binlog"

aws --endpoint-url=$OBJ_STORAGE_URL s3 cp s3://$BUCKET_NAME/$NAMESPACE/backups/$BACKUP_SOURCE $BACKUP_DIR/$BACKUP_SOURCE --recursive
aws --endpoint-url=$OBJ_STORAGE_URL s3 cp s3://$BUCKET_NAME/$NAMESPACE/binlog $BACKUP_DIR/binlog --recursive
