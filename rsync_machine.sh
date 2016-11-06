#!/bin/bash
# Backup script that uses rsync with link-dest option (for a 'Time Machine'-like
# backup) and zenity to notify progress.
# To disable zenity set ZENITY variable to false in backup.cfg.
# Note: progress monitoring was tested with rsync version >= 3.1.1.

# configuration directory for this script
CONFIG_DIR=~/.rsync_machine

# main configuration file
CONFIG_FILE=$CONFIG_DIR/backup.cfg

if [ ! -d $CONFIG_DIR ]; then
    echo "Config dir '$CONFIG_DIR' does not exist!"
    exit 1
fi

if [ ! -f $CONFIG_FILE ]; then
    echo "Config file '$CONFIG_FILE' does not exist!"
    exit 1
fi

# read configuration file
source $CONFIG_FILE

err_msg ()
{
    if $ZENITY; then
        zenity --error --text "$1"
    else
        echo "$1"
    fi
}

conf_var ()
{
    COMBINED=${1}_${2}
    echo ${!COMBINED}
}

IFS=";" read -ra CONFS <<< ${CONFIGURATIONS}
if [ ${#CONFS[@]} -eq 0 ]; then
    err_msg "Missing CONFIGURATIONS variable in configuration file!"
    exit 1
elif [ ${#CONFS[@]} -eq 1 ]; then
    CONF_CHOSEN=${CONFS[0]}
else
    CONFS_AND_DESCS=()
    for c in ${CONFS[@]}
    do
        CONFS_AND_DESCS+=($c)
        CONFS_AND_DESCS+=($(conf_var CONFIGURATION_NAME $c))
    done
    CONF_CHOSEN=$(zenity --text="Choose configuration:" --list --column="Configuration" --column="Name" "${CONFS_AND_DESCS[@]}")
fi

if [ -z ${CONF_CHOSEN} ]; then
    err_msg "No backup configuration chosen!"
    exit 1
fi


PASSWORD_FILENAME=$(conf_var RSYNC_PASSWORD_FILE_NAME ${CONF_CHOSEN})
if [ ! -z ${PASSWORD_FILENAME} ]; then
    # rsync password file (plain-text)
    RSYNC_PASSWORD_FILE=${CONFIG_DIR}/${PASSWORD_FILENAME}
    PASSWORD_FILE_OPT="--password-file=${RSYNC_PASSWORD_FILE}"
fi

# rsync exclude patterns (plain text file, one pattern per line)
RSYNC_EXCLUDES_FILE="$CONFIG_DIR/$(conf_var RSYNC_EXCLUDES_FILE_NAME ${CONF_CHOSEN})"

LAST_SUCCESSFUL_BACKUP=$CONFIG_DIR/last_success_${CONF_CHOSEN}

LOG_FILE=$CONFIG_DIR/log_${CONF_CHOSEN}

#DATE_FMT="%Y-%m-%d_%H:%M:%S"
DATE_FMT="%Y-%m-%d_%H_%M_%S"

THIS_BACKUP_DATE=$(date "+$DATE_FMT")

# uncomment to rest rsync
#DRY_RUN=--dry-run


if [ ! -f "$RSYNC_EXCLUDES_FILE" ]; then
    MSG="Exclude patterns file '$RSYNC_EXCLUDES_FILE' does not exist!"
    err_msg "$MSG"
    exit 1
fi

RSYNC_BASEDIR=$(conf_var RSYNC_BASEDIR ${CONF_CHOSEN})
if [ -z "${RSYNC_BASEDIR}" ]; then
    MSG="Rsync base backup directory '${RSYNC_BASEDIR}' missing in configuration file!"
    err_msg "$MSG"
    exit 1
fi

RSYNC_DEST=$(conf_var RSYNC_DEST ${CONF_CHOSEN})
if [ -z "${RSYNC_DEST}" ]; then
    MSG="Rsync destination '${RSYNC_DEST}' missing in configuration file!"
    err_msg "$MSG"
    exit 1
fi

if $ZENITY; then
    zenity --question --text "Do you want to backup now?"
    if [ $? -ne 0 ]; then
        exit 0
    fi
fi

LINK_DEST_BASE_DIR=$(conf_var RSYNC_LINK_DEST ${CONF_CHOSEN})

if [ -f $LAST_SUCCESSFUL_BACKUP ]; then
    LINK_DEST="--link-dest=${LINK_DEST_BASE_DIR}$(<$LAST_SUCCESSFUL_BACKUP)"
fi

echo "Starting backup at: $(date)" >> $LOG_FILE

rsync $DRY_RUN --progress --out-format "# %n" --info=progress2 --archive --hard-links --human-readable --inplace --numeric-ids --delete --delete-excluded --exclude-from="$RSYNC_EXCLUDES_FILE" $LINK_DEST $PASSWORD_FILE_OPT "${RSYNC_BASEDIR}" "${RSYNC_DEST}/$THIS_BACKUP_DATE" 2>> $LOG_FILE |
if $ZENITY; then sed 's/^[^#].* \([0-9]\{1,2\}\)%.*/\1/' | (
    #trap "kill `ps --ppid $$ | grep rsync | awk '{print $1}'`" HUP
    trap "pkill -P $$" HUP
    zenity --width=800 --progress --title "Backup" "Processing..." --percentage 0 --auto-kill --auto-close
); else cat; fi
#if $ZENITY; then sed 's/^[^#].* \([0-9]\{1,2\}\)%.*/\1/' | zenity --width=800 --progress --title "Backup" "Processing..." --percentage 0 --auto-kill --auto-close; else cat; fi

#if [ $? -ne 0 ]; then
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    MSG="Rsync error! See logfile at $LOG_FILE"
    echo "FAILURE at $(date)" >> $LOG_FILE
    err_msg "$MSG"
    exit 2
fi

echo $THIS_BACKUP_DATE > $LAST_SUCCESSFUL_BACKUP
echo "SUCCESS at $(date)" >> $LOG_FILE

if $ZENITY; then
    zenity --info --title "Backup" --text "Backup successfully completed!"
fi
