#!/bin/bash
# batchjob.sh

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
LOGDIR="$HOME/logs"
LOGFILE="$LOGDIR/batchjob-$(date +%Y%m%d).log"
BATCH_DIR="$HOME/current"

unset OBJ_STORAGE_URL
unset BUCKET_NAME
OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')
BATCHJOS="batchjos/$(date +%H%m)"
function log() {
  echo "[$(date +%F.%T.%3N)][INFO] $*" >> $LOGFILE
}

function warn() {
  echo "[$(date +%F.%T.%3N)][WARN] $*" >> $LOGFILE
}

function error() {
  echo "[$(date +%F.%T.%3N)][ERROR] $*" >> $LOGFILE
}

INIT_SLEEP=$(expr $((0x$(sha1sum <<<$NAMESPACE | awk '{pos=length($1)-1;print substr($1,pos,2)}'))) % 60)
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

log "start ${NAMESPACE}"

init_wait
log "aws --endpoint-url=$OBJ_STORAGE_URL ls s3://$BUCKET_NAME/$BATCHJOS/"
CURRENT=$(aws --endpoint-url=$OBJ_STORAGE_URL ls s3://$BUCKET_NAME/$BATCHJOS/ | awk '{print $NF}')
if [ -z "$CURRENT" ];then
  log "No batchjob"
  exit 101
fi

log "aws --endpoint-url=$OBJ_STORAGE_URL cp s3://$BUCKET_NAME/$BATCHJOS/$CURRENT /tmp/$CURRENT"
aws --endpoint-url=$OBJ_STORAGE_URL cp s3://$BUCKET_NAME/$BATCHJOS/$CURRENT /tmp/$CURRENT
TARBALL=$(find /tmp -name '$CURRENT')

if [ ! -f /tmp/$CURRENT ];then
  log "Failed to download $CURRENT"
  exit 101
fi

log "cd $BATCH_DIR"
cd $BATCH_DIR
log "tar zxf /tmp/$CURRENT"
tar zxf /tmp/$CURRENT

BATCHINFO=$(find $BATCH_DIR -name 'batch.info')
log "BATCHINFO:$BATCHINFO"
if [ -z "$BATCHINFO" ];then
  log "NO BATCH INFO : $BATCHINFO"
  exit 102
elif [ ! -f "$BATCHINFO" ];then
  log "batch.info not found: $BATCHINFO"
  exit 103
else
  log "OK to find batch.info from $BATCH_DIR"
fi

BATCH_TYPE=$(grep 'BATCH_TYPE' $BATCHINFO | awk -F '=' '{print $2}')
log "BATCH_TYPE: $BATCH_TYPE"

case $BATCH_TYPE in
  jar*)
    EXEC=$(which java)
    log "Run batch TYPE=$TYPE from file:$TARBALL"
    log "read variables from $BATCHINFO"
    BATCH_NAME=$(grep 'BATCH_NAME=' $BATCHINFO | awk -F '=' '{print $2}')
    log "BATCH_NAME: $BATCH_NAME"
    BATCH_TYPE=$(grep 'BATCH_TYPE=' $BATCHINFO | awk -F '=' '{print $2}')
    log "BATCH_TYPE: $BATCH_TYPE"
    FILE_NAME=$(grep "FILE_NAME=" $BATCHINFO | awk -F '=' '{print $2}')
    log "FILE_NAME: $FILE_NAME"
    FILE_PATH=$(find $BATCH_DIR -name "$FILE_NAME")
    log "FILE_PATH: $FILE_PATH"
    log "ENVS: $(grep 'ENVS=' $BATCHINFO | awk -F '=' '{print $2}')"
    ENV_VALS=$(grep ENV $BATCHINFO | awk -F ':=' '{printf "-D%s ",$2}')
    log "ENV_VALS: $ENV_VALS"

    log "$EXEC -jar $FILE_PATH $ENV_VALS"
    $EXEC -jar $FILE_PATH $ENV_VALS
    ;;
  shell*)
    log "Run batch TYPE=$TYPE from file:$TARBALL"
    log "read variables from $BATCHINFO"
    BATCH_NAME=$(grep 'BATCH_NAME=' $BATCHINFO | awk -F '=' '{print $2}')
    BATCH_TYPE=$(grep 'BATCH_TYPE=' $BATCHINFO | awk -F '=' '{print $2}')
    FILE_NAME=$(grep "FILE_NAME=" $BATCHINFO | awk -F '=' '{print $2}')
    log "FILE_NAME: $FILE_NAME"
    FILE_PATH=$(find $BATCH_DIR -name "$FILE_NAME")
    log "FILE_PATH: $FILE_PATH"
    log "ARGS: $(grep 'ARG:' $BATCHINFO | awk -F ':' '{printf "%s ",$2}')"
    ARGS=$(grep 'ARG:' $BATCHINFO | awk -F ':' '{printf "%s ",$2}')
    log "ARGS: $ARGS"

    log "$FILE_PATH $ARGS"
    $FILE_PATH $ARGS
    ;;
  *)
    log "Can't exec TYPE=$TYPE from file:$TARBALL"
  esac

log "BATCH JOB COMPLETE: $NAMESPACE"
exit 0

log "rm -rf /tmp/$CURRENT"
rm -rf /tmp/$CURRENT
log "rm -rf $BATCH_DIR/*"
rm -rf $BATCH_DIR/*

log "completed ${NAMESPACE}"

