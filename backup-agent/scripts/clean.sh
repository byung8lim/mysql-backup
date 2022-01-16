#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace|awk -F '-' '{print $2}')
BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')
RETENTION_CNT=$(grep 'RETENTION_CNT' $CONF | awk -F '=' '{print $2}')
BACKUP_PREFIX=$(grep 'BACKUP_PREFIX' $CONF | awk -F '=' '{print $2}')
LOGDIR="$HOME/logs"
LOGFILE="$LOGDIR/clean-$(date +%Y%m%d).log"

function log() {
  echo "[$(date +%F.%T.%3N)][INFO] $*" >> $LOGFILE
}

function warn() {
  echo "[$(date +%F.%T.%3N)][WARN] $*" >> $LOGFILE
}

function error() {
  echo "[$(date +%F.%T.%3N)][ERROR] $*" >> $LOGFILE
}

function current_cnt() {
  NAMESPACE=$1
  aws --endpoint-url=$OBJ_STORAGE_URL s3 ls s3://$BUCKET_NAME/$NAMESPACE/backups/ | sed -e 's/\///g' | awk 'BEGIN{cnt=0}/PRE/{
    cnt++;
    print $2;
  } END {
    print "Total:"cnt;
  }'>>$LOGFILE
}

echo "[$(date +%F.%T.%3N)][INFO] Start check_tenant" >> $LOGFILE
log "find $LOG_DIR -name '*.log' -mtime 1 -exec rm {} \;"
find $LOG_DIR -name '*.log' -mtime 1 -exec rm {} \;

log "NAMESPACE: $NAMESPACE"
log "RETENTION_CNT: $RETENTION_CNT"
if [ -z "$BACKUP_PREFIX" ];then
  error "BACKUP_PREFIX is empty($BACKUP_PREFIX)"
  exit 101
fi

EXPIRED=$(aws --endpoint-url=$OBJ_STORAGE_URL s3 ls s3://$BUCKET_NAME/$NAMESPACE/backups/ | sed -e 's/\///g' | awk 'BEGIN{cnt=0;max="'"${RETENTION_CNT}"'";tenant="'"${NAMESPACE}"'"}/PRE/{
  array[cnt++]=$2;
} END {
  rmcnt=cnt-max;
  if (rmcnt > 0) {
    sort();
    for (i=0; i< rmcnt;i++) {
      print array[i];
    }
  }
} function sort() {
  for (i=0;i<cnt;i++) {
    for (j=i+1; j<cnt;j++) {
      if (array[i] > array[j]) {
        tmp=array[i];
        array[i]=array[j];
        array[j]=tmp;
          }
    }
  }
}')

if [ -z "$EXPIRED" ];then
  log "$NAMESPACE has no items"
  current_cnt $NAMESPACE
else
  for item in $EXPIRED;do
    OBJECT_NAME="$item"
    log "OBJECT_NAME: $OBJECT_NAME"
    log "aws --endpoint-url=$OBJ_STORAGE_URL s3 rm s3://$BUCKET_NAME/$NAMESPACE/backups/$OBJECT_NAME --recursive"
    aws --endpoint-url=$OBJ_STORAGE_URL s3 rm s3://$BUCKET_NAME/$NAMESPACE/backups/$OBJECT_NAME --recursive
  done
fi
log "$NAMESPACE Finished"

