#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
CREATESTMP=$(date +%Y%m%d%H%M%S)
BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
BINLOG_DIR="$BASE/logs"
S3_DIR="$NAMESPACE/binlog"
LOGDIR="$HOME/logs"
LOGFILE="$LOGDIR/sync-$(date +%Y%m%d).log"

unset OBJ_STORAGE_URL
unset BUCKET_NAME
OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')
BACKUP_LOCK=$(grep 'BACKUP_LOCK' $CONF | awk -F '=' '{print $2}')
LOCK_FILE="$HOME/log/$BACKUP_LOCK"

INIT_SLEEP=$(expr $((0x$(sha1sum <<<$NAMESPACE | awk '{pos=length($1)-1;print substr($1,pos,2)}'))) % 60)

function log() {
  echo "[$(date +%F.%T.%3N)][INFO] $*" >> $LOGFILE
}

function warn() {
  echo "[$(date +%F.%T.%3N)][WARN] $*" >> $LOGFILE
}

function error() {
  echo "[$(date +%F.%T.%3N)][ERROR] $*" >> $LOGFILE
}

function end() {
  CD=$1
  exit $CD
}

function init_wait() {
  WAIT_CNT=0;
  MAX=$((INIT_SLEEP * 1))
  log "$NAMESPACE should wait for MAX($INIT_SLEEP:$MAX)"
  while [ $WAIT_CNT -lt $MAX ];do
    sleep 1
    WAIT_CNT=$((WAIT_CNT+1))
    log "$NAMESPACE waiting for $WAIT_CNT"
  done
}

if [ -z "$NAMESPACE" ];then
  error "NAMESPACE is empty :${NAMESPACE}"
  end 101
fi

if [ -z "$OBJ_STORAGE_URL" ];then
  error "OBJ_STORAGE_URL is empty :${OBJ_STORAGE_URL}"
  end 101
fi

if [ -z "$BUCKET_NAME" ];then
  error "BUCKET_NAME is empty :${BUCKET_NAME}"
  end 102
fi

if [ -z "$INIT_SLEEP" ];then
  error "INIT_SLEEP is empty :$INIT_SLEEP"
  end 103
fi

if [ -f $LOCK_FILE ];then
  warn "s3_sync.sh leaving, backup.sh is maybe running : $LOCK_FILE"
  end 104
fi

init_wait
unset CD
log "aws s3 sync $BINLOG_DIR  --endpoint-url=$OBJ_STORAGE_URL s3://$BUCKET_NAME/$S3_DIR"
aws s3 sync $BINLOG_DIR  --endpoint-url=$OBJ_STORAGE_URL s3://$BUCKET_NAME/$S3_DIR>/dev/null 2>$LOGFILE
CD=$?

if [ $CD -ne 0 ];then
  error "${NAMESPACE} FAILED: $CD"
else
  log "${NAMESPACE} SUCCESS: $CD"
fi

