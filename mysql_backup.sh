#!/bin/sh
#===================================================================================================
## 备份工具：
##    percona-xtrabackup-2.2.8
##
## 备份策略：
##    (1)、每天凌晨04:20点进行全量备份一次；
##    (2)、每隔2小时增量备份一次；
##
#===================================================================================================
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin
 
## DB备份基路径
## $1为MYSQL port
BACKUP_BASE_DIR="/data/backup/$1"
 
## 增量备份时，用到的基准目录列表文件
## 内容格式：基准目录|本次备份目录|备份类型【full|inc】
INC_BASE_LIST="${BACKUP_BASE_DIR}/incremental_basedir_list.txt"
 
## 备份工具路径
XTRABACKUP_PATH="/usr/bin/innobackupex"
 
## MySQL配置路径
MYSQL_CNF_PATH="/etc/my_$1.cnf"
 
## 线程数
THREAD_CNT=6
 
#===================================================================================================
function print_help_info()
{
    echo "--------------------------------------------------------------"
    echo "Usage: $0 mysql_port full | inc | help"
    echo "--------------------------------------------------------------"
    echo ""
    exit 1
}
 
[[ $# -lt 1 ]] && print_help_info
[[ -d ${BACKUP_BASE_DIR} ]] || mkdir -p ${BACKUP_BASE_DIR}
 
 
## 只允许一个副本运行，以避免全量备份与增量备份出现交叉，发生数据错乱的可能性
##[[ -n `ps uax | grep innobackupex | grep -v grep` ]] && exit 1
 
## 目录名默认精确到分钟，为避免意外情况，导致备份任务失败，可以精确到秒
CURRENT_BAK_PATH="${BACKUP_BASE_DIR}/"`date +%F_%H-%M`
[[ -d ${CURRENT_BAK_PATH} ]] && CURRENT_BAK_PATH="${BACKUP_BASE_DIR}/"`date +%F_%H-%M-%S`
 
#===================================================================================================
## 全量备份
if [[ "$2" == "full" ]]; then
    ${XTRABACKUP_PATH} --user=root --defaults-file=${MYSQL_CNF_PATH} --socket=/data/mysql/mysql_$1/mysql.sock   --parallel=${THREAD_CNT} --no-timestamp ${CURRENT_BAK_PATH}
    echo "NULL|${CURRENT_BAK_PATH}|full" >> ${INC_BASE_LIST}
 
## 增量备份
elif [[ "$2" == "inc" ]]; then
    ## 基准目录列表文件不存在或者为空的情况，需要做一次全量备份
    if [[ ! -f ${INC_BASE_LIST} || `sed '/^$/d' ${INC_BASE_LIST} | wc -l` -eq 0 ]]; then
        ${XTRABACKUP_PATH} --user=root --defaults-file=${MYSQL_CNF_PATH} --socket=/data/mysql/mysql_$1/mysql.sock --parallel=${THREAD_CNT} --no-timestamp ${CURRENT_BAK_PATH}
        echo "NULL|${CURRENT_BAK_PATH}|full" >> ${INC_BASE_LIST}
     
    ## 不存在任何目录的情况，需要做一次全量备份，以避免增量备份失败
    elif [[ `find ${BACKUP_BASE_DIR} -maxdepth 1 -type d | wc -l` -eq 1 ]]; then
        ${XTRABACKUP_PATH} --user=root --defaults-file=${MYSQL_CNF_PATH} --socket=/data/mysql/mysql_$1/mysql.sock --parallel=${THREAD_CNT} --no-timestamp ${CURRENT_BAK_PATH}
        echo "NULL|${CURRENT_BAK_PATH}|full" >> ${INC_BASE_LIST}
     
    ## 在上一次备份的基础上，进行增量备份
    else
        PREV_BACKUP_DIR=`sed '/^$/d' ${INC_BASE_LIST} | tail -1  | awk -F '|' '{print $2}'`
        ## 上次的备份目录不存在或者目录为空的情况，以避免人为删除的可能性【针对部分恶意删除的情况，目前还没有较好的检查方法】
        if [[ ! -d ${PREV_BACKUP_DIR} || -z `ls ${PREV_BACKUP_DIR}` ]]; then
            ${XTRABACKUP_PATH} --user=root --defaults-file=${MYSQL_CNF_PATH} --socket=/data/mysql/mysql_$1/mysql.sock --parallel=${THREAD_CNT} --no-timestamp ${CURRENT_BAK_PATH}
            echo "NULL|${CURRENT_BAK_PATH}|full" >> ${INC_BASE_LIST}
        else
            ${XTRABACKUP_PATH} --user=root --defaults-file=${MYSQL_CNF_PATH} --socket=/data/mysql/mysql_$1/mysql.sock --parallel=${THREAD_CNT} --no-timestamp --incremental ${CURRENT_BAK_PATH} --incremental-basedir=${PREV_BACKUP_DIR}
            echo "${PREV_BACKUP_DIR}|${CURRENT_BAK_PATH}|inc" >> ${INC_BASE_LIST}
        fi
    fi
 
elif [[ "$2" == "help" ]]; then
    print_help_info
 
else
    print_help_info
fi
 
## 删除4周前的数据备份
rm -rf ${BACKUP_BASE_DIR}/`date -d '30 days ago' +'%F'`_*
sed -i "/`date -d '30 days ago' +'%F'`/d" ${INC_BASE_LIST}
 
#===================================================================================================
##The End
 
####################################################################################################
## 需要添加的crontab信息：
##     (1)、全量备份
##     20 04 * * * /data/scripts/mysql_backup.sh port full >/dev/null 2>&1
##
##     (2)、增量备份
##     00 */2 * * * /data/scripts/mysql_backup.sh port inc >/dev/null 2>&1
##
####################################################################################################
 
####################################################################################################
## DB数据恢复步骤：
##    (1)、应用基准
##    innobackupex --user=root --defaults-file=/etc/my.cnf --use-memory=8G --apply-log --redo-only /data/mysql_backup/full
##
##    (2)、应用第一个增量备份
##    innobackupex --user=root --defaults-file=/etc/my.cnf --use-memory=8G --apply-log --redo-only /data/mysql_backup/full --incremental-dir=/data/mysql_backup/inc_one
##
##    (3)、应用第二个增量备份
##    innobackupex --user=root --defaults-file=/etc/my.cnf --use-memory=8G --apply-log /data/mysql_backup/full --incremental-dir=/data/mysql_backup/inc_two
##
##    (4)、再次应用基准
##    innobackupex --user=root --defaults-file=/etc/my.cnf --use-memory=8G --apply-log /data/mysql_backup/full
##
##    (5)、恢复
##    innobackupex --user=root --defaults-file=/etc/my.cnf --copy-back /data/mysql_backup/full
####################################################################################################

