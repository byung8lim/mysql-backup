#!/bin/bash

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

CREATESTAMP="$(date +%Y%m%d%H%M%S)"
BASE="/byung8"
HOME="/mbs"
CONF="$HOME/conf/mbs.conf"
BACKUP_DIR="$BASE/backups"
LOGDIR="$HOME/logs"
DEFAULTS_FILE="$HOME/conf/credential.cnf"
LOGFILE="$LOGDIR/backup-$(date +%Y%m%d).log"
BACKUP_ERROR_LOG="$HOME/logs/backup.err"

unset OBJ_STORAGE_URL
unset BUCKET_NAME
OBJ_STORAGE_URL=$(grep 'OBJ_STORAGE_URL' $CONF | awk -F '=' '{print $2}')
BUCKET_NAME=$(grep 'BUCKET_NAME' $CONF | awk -F '=' '{print $2}')
BACKUP_PREFIX=$(grep 'BACKUP_PREFIX' $CONF | awk -F '=' '{print $2}')
DB_NAME=$(grep 'DB_NAME' $CONF | awk -F '=' '{print $2}')
BACKUP_LOCK=$(grep 'BACKUP_LOCK' $CONF | awk -F '=' '{print $2}')
LOCK_FILE="$HOME/logs/$BACKUP_LOCK"

S3_DIR="binlog"
BINLOG_DIR="$BASE/logs"
FILE="$BACKUP_PREFIX-$CREATESTAMP.sql"
CHKSUM_FILE="$BACKUP_PREFIX-$CREATESTAMP.chksum"
TARBALL_FILE="$BACKUP_PREFIX-$CREATESTAMP.tar.gz"

function log () {
  echo "[$(date +%F.%T.%3N)][INFO] $*">>$LOGFILE
}

function warn () {
  echo "[$(date +%F.%T.%3N)][WARN] $*">>$LOGFILE
}

function error () {
  echo "[$(date +%F.%T.%3N)][ERROR] $*">>$LOGFILE
}

function end() {
  CD=$?
  if [ -f $LOCK_FILE ];then
    log "rm -f $LOCK_FILE before exit with CD:$CD"
    rm -f $LOCK_FILE
  fi
  exit $CD
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

log "$NAMESPACE start backup"
#Record Binary Log & Position before dump
# Vaildation of Backup variables 100 ~
log "CREATE_STMP=${CREATESTAMP}"

echo "$CREATESTAMP" > $LOCK_FILE

init_wait

echo "CREATE_STMP=${CREATESTAMP}" > $BACKUP_DIR/info.txt
if [ -z "$NAMESPACE" ];then
  error "NAMESPACE(101) is empty:$NAMESPACE"
  end 101
else
  log "NAMESPACE=${NAMESPACE}"
fi
echo "NAMESPACE=${NAMESPACE}" >> $BACKUP_DIR/info.txt

log "FILENAME=${FILE}"
echo "FILENAME=${FILE}" >> $BACKUP_DIR/info.txt

if [ -z "$OBJ_STORAGE_URL" ];then
  error "OBJ_STORAGE_URL(102) is empty:$OBJ_STORAGE_URL"
  end 102
else
  log "OBJ_STORAGE_URL=${OBJ_STORAGE_URL}"
fi
echo "OBJ_STORAGE_URL=${OBJ_STORAGE_URL}" >> $BACKUP_DIR/info.txt

if [ -z "$BUCKET_NAME" ];then
  error "BUCKET_NAME(103) is empty:$BUCKET_NAME"
  end 103
else
  log "BUCKET_NAME=${BUCKET_NAME}"
fi
echo "BUCKET_NAME=${BUCKET_NAME}" >> $BACKUP_DIR/info.txt

if [ -z "$BACKUP_PREFIX" ];then
  error "BACKUP_PREFIX(104) is empty:$BACKUP_PREFIX"
  end 104
fi

log "mysql --defaults-file=$DEFAULTS_FILE -e 'show master status \G' | awk '/File:/{print \"PRE_BACKUP_BIN=\"\$2} /Position:/{print \"PRE_BACKUP_POS=\"\$2}'"
mysql --defaults-file=$DEFAULTS_FILE -e 'show master status \G' | awk '/File:/{print "PRE_BACKUP_BIN="$2} /Position:/{print "PRE_BACKUP_POS="$2}' >> $BACKUP_DIR/info.txt

log "mysqldump --defaults-file=${DEFAULTS_FILE} --quick --flush-logs --single-transaction=TRUE --routines --triggers -F --master-data=2 -B $DB_NAME > $BACKUP_DIR/$FILE"
mysqldump --defaults-file=$DEFAULTS_FILE --quick --flush-logs --single-transaction=TRUE --routines --triggers -F --master-data=2 -B $DB_NAME > $BACKUP_DIR/$FILE

# if mysqldump return cd is not 0, 202

#Read and Record Binary Log & Position from dump file
grep "CHANGE MASTER" $BACKUP_DIR/$FILE | sed 's/\x27//g' | awk -F '=' '/MASTER_LOG_FILE/{
  printf "BACKUP_BIN_FILE=%s\n",substr($2,1,index($2,",")-1);
  printf "BACKUP_BIN_POS=%s\n",substr($3, 1, length($3)-1);
}' >> $BACKUP_DIR/info.txt

if [ ! -f $BACKUP_DIR/$FILE ];then
  error "Backup file not found : $BACKUP_DIR/$FILE"
  echo "RESULT_CD=201"
  end 201
fi

BACKUP_BIN_FILE=$(grep BACKUP_BIN_FILE $BACKUP_DIR/info.txt | awk -F '=' '{print $2}')
BACKUP_BIN_POS=$(grep BACKUP_BIN_POS $BACKUP_DIR/info.txt | awk -F '=' '{print $2}')

log "BACKUP_BIN_FILE = $BACKUP_BIN_FILE"
log "BACKUP_BIN_POS = $BACKUP_BIN_POS"

#Record Binary Log & Position after dump
log "mysql --defaults-file=$DEFAULTS_FILE -e 'show master status \G' | awk '/File:/{print "POST_BACKUP_BIN=\"\$2} /Position:/{print "POST_BACKUP_POS=\"\$2}'"
mysql --defaults-file=$DEFAULTS_FILE -e 'show master status \G' | awk '/File:/{print "POST_BACKUP_BIN="$2} /Position:/{print "POST_BACKUP_POS="$2}' >> $BACKUP_DIR/info.txt

#Backup File Size
DUMP_SIZE=$(du -sb $BACKUP_DIR/$FILE | awk '{print $1}')
if [ $DUMP_SIZE -lt 1 ];then
  warn "Size($DUMP_SIZE) of dump file is less than 1"
else
  log "DUMP_SIZE=$DUMP_SIZE"
fi
echo "DUMP_SIZE=$DUMP_SIZE">> $BACKUP_DIR/info.txt

#Backup File Checksum
sha1sum $BACKUP_DIR/$FILE | awk '{print $1}'> $BACKUP_DIR/$CHKSUM_FILE

log "DUMP_CHKSUM=\$(cat $BACKUP_DIR/$CHKSUM_FILE)"
DUMP_CHKSUM=$(cat $BACKUP_DIR/$CHKSUM_FILE)
log "DUMP_CHKSUM=$DUMP_CHKSUM"
echo "DUMP_CHKSUM=$DUMP_CHKSUM" >> $BACKUP_DIR/info.txt

unset PURGE_BIN
PRE_BACKUP_BIN=$(grep 'PRE_BACKUP_BIN' $BACKUP_DIR/info.txt | awk -F '=' '{print $2}')
#BACKUP_BIN_FILE=$(grep 'BACKUP_BIN_FILE' $BACKUP_DIR/info.txt | awk -F '=' '{print $2}')
POST_BACKUP_BIN=$(grep 'POST_BACKUP_BIN' $BACKUP_DIR/info.txt | awk -F '=' '{print $2}')

if [ -z "$BACKUP_BIN_FILE" ];then
  PURGE_BIN=$PRE_BACKUP_BIN
else
  PURGE_BIN=$BACKUP_BIN_FILE
fi

BINLOG_CNT=$(mysql --defaults-file=$DEFAULTS_FILE -e "show binary logs" | awk 'BEGIN{cnt=0;}/binlog.[0-9]+/{cnt+=1;}END{print cnt}')
log "PURGE_BIN=$PURGE_BIN"
log "BINLOG_CNT=$BINLOG_CNT before purging binlog"

log "mysql --defaults-file=$DEFAULTS_FILE -e purge binary logs to '${PURGE_BIN}'"
mysql --defaults-file=$DEFAULTS_FILE -e "purge binary logs to '${PURGE_BIN}'"
BINLOG_CNT=$(mysql --defaults-file=$DEFAULTS_FILE -e "show binary logs" | awk 'BEGIN{cnt=0;}/binlog.[0-9]+/{cnt+=1;}END{print cnt}')

log "BINLOG_CNT=$BINLOG_CNT after purging binlog"
echo "BINLOG_CNT=$BINLOG_CNT" >> $BACKUP_DIR/info.txt

cd $BACKUP_DIR
log "tar -zcf $TARBALL_FILE $FILE $CHKSUM_FILE info.txt"
tar -zcf $TARBALL_FILE $FILE $CHKSUM_FILE info.txt

# When faild to archive dump file, 101
if [ ! -f $BACKUP_DIR/$TARBALL_FILE ];then
  echo "RESULT_CD=202" >> $BACKUP_DIR/info.txt
  end 202
fi

sha1sum $BACKUP_DIR/$TARBALL_FILE | awk '{print "TARBALL_CHKSUM="$1}' >> $BACKUP_DIR/info.txt
du -sb $BACKUP_DIR/$TARBALL_FILE | awk '{print "TARBALL_SIZE="$1}' >> $BACKUP_DIR/info.txt

unset CD
log "aws --endpoint-url=$OBJ_STORAGE_URL s3 cp $BACKUP_DIR/$TARBALL_FILE s3://$BUCKET_NAME/$NAMESPACE/backups/$CREATESTAMP/$TARBALL"
aws --endpoint-url=$OBJ_STORAGE_URL s3 cp $BACKUP_DIR/$TARBALL_FILE s3://$BUCKET_NAME/$NAMESPACE/backups/$CREATESTAMP/$TARBALL
CD=$?
# When upload failed, 301
if [ $CD -ne 0 ];then
  echo "RESULT_CD=301" >> $BACKUP_DIR/info.txt
  warn "Probably Failed upload TARBALL"
else
  log "OK upload UPLOAD_CD=0"
  echo "UPLOAD_CD=0" >> $BACKUP_DIR/info.txt
fi

unset CD
log "aws --endpoint-url=$OBJ_STORAGE_URL s3 cp $BACKUP_DIR/info.txt s3://$BUCKET_NAME/$NAMESPACE/backups/info.txt"
aws --endpoint-url=$OBJ_STORAGE_URL s3 cp $BACKUP_DIR/info.txt s3://$BUCKET_NAME/$NAMESPACE/backups/info.txt
CD=$?
# When upload failed, 302
if [ $CD -ne 0 ];then
  error "RESULT_CD=302"
  echo "RESULT_CD=302" >> $BACKUP_DIR/info.txt
else
  log "RESULT_CD=0"
  echo "RESULT_CD=0" >> $BACKUP_DIR/info.txt
fi

log "aws --endpoint-url=$OBJ_STORAGE_URL s3 rm s3://$BUCKET_NAME/$NAMESPACE/$S3_DIR --recursive"
aws --endpoint-url=$OBJ_STORAGE_URL s3 rm s3://$BUCKET_NAME/$NAMESPACE/$S3_DIR --recursive

log "aws s3 sync $BINLOG_DIR  --endpoint-url=$OBJ_STORAGE_URL s3://$BUCKET_NAME/$NAMESPACE/$S3_DIR"
aws s3 sync $BINLOG_DIR  --endpoint-url=$OBJ_STORAGE_URL s3://$BUCKET_NAME/$NAMESPACE/$S3_DIR

log "rm -f $BACKUP_DIR/$FILE"
rm -f $BACKUP_DIR/$FILE

log "rm -f $BACKUP_DIR/$TARBALL_FILE"
rm -f $BACKUP_DIR/$TARBALL_FILE

log "rm -f $BACKUP_DIR/$CHKSUM_FILE"
rm -f $BACKUP_DIR/$CHKSUM_FILE
log "$NAMESPACE completed"
end 0
