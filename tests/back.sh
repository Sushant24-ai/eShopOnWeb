#!/bin/bash

while getopts U:T:H:A:E: opt
do
   case "$opt" in
        U) URL="$OPTARG";;
        T) TARGETDIR="$OPTARG";;
        A) AEM_TYPE="$OPTARG";;
        E) ENVIRONMENT="$OPTARG";;
        H) AEM_HOME="$OPTARG";;
       \?) help_options
           exit 1;;
   esac
done

#Setting up the Variable
#DL=gs-am-it-digital-infra@ny.email.gs.com
DL="karthikeyan.moorthy@gs.com,sanjeev.kumar@ny.email.gs.com,soni.pandey@ny.email.gs.com"
#AEM_HOME=/local/scratch/gsamaem6/$AEM_TYPE_FOLDER
BACKUPDIR=/home/aem_${AEM_TYPE}_backup/${AEM_TYPE}_`hostname`/$TARGETDIR
REPO_PATH=/system/console/jmx/com.adobe.granite%3Atype%3DRepository
AEMLOGFILE=${AEM_HOME}/adobeaem/logs/error.log
AUTOSYSLOGFILE=${AEM_HOME}/scripts/logs/online_backup_aem_$(date +%d-%m-%Y-%H-%m).log
export USERPASSWORD=`cat ${AEM_HOME}/scripts/.password`
export LOG_KEY="$ENVIRONMENT $URL $AEM_TYPE"

logCurrentBackupStatus() {
  ## adding logs in a single file
  echo "###################################################" >> $AUTOSYSLOGFILE
  grep -i "\[Backup Worker Thread\]" $AEMLOGFILE > $AUTOSYSLOGFILE;
}

echoMessage() {
        echo "${LOG_KEY} - $0";
}

#Initialize defaults and globals here

if [ -z "$URL" ]; then
        echo "URL and PORT not set - exiting"
        exit 1
fi
if [ -z "$TARGETDIR" ]; then
        echo "Targer Directory not set - exiting"
        exit 1
fi
if [ -z "$ENVIRONMENT" ]; then
        echo "ENVIRONMENT is not set to uat/prod - exiting"
        exit 1
fi
if [ -z "$AEM_TYPE" ]; then
        echo "AEM Publisher Type is not set  - exiting"
        exit 1
fi
if [ -z "$AEM_HOME" ]; then
        echo "AEM HOME dir is not set - exiting"
        exit 1
fi


#Validating the AEM instance is avaialble or not
curl -u $USERPASSWORD  ${URL}/content/gsam/us/en/advisors/homepage.html|grep "Goldman Sachs"
if [ $? != 0 ]
then
        echoMessage "ERROR : instance is not available, can't trigger online backup on NAS $BACKUPDIR" > $AUTOSYSLOGFILE
        mailx -s "ERROR : ${LOG_KEY} online backup failed(`date`) on NAS $BACKUPDIR" $DL < $AUTOSYSLOGFILE
        exit 1
fi
#validating Backup status befor triggering the backup
curl -u $USERPASSWORD ${URL}${REPO_PATH}|grep "Backup in progress"
if [ $? = 0 ]
then
        echoMessage "backup is already running skipping backup startup this time on NAS $BACKUPDIR" > $AUTOSYSLOGFILE
        mailx -s "${LOG_KEY}  Already Backup in Progress $(date +%d-%m-%Y-%H-%m)" $DL < $AUTOSYSLOGFILE
        exit -1
else
        #Starting the backup process
        echoMessage "starting backup"
        curl -u $USERPASSWORD -X POST "${URL}/system/console/jmx/com.adobe.granite:type=Repository/a/BackupDelay?value=0"
        curl -u $USERPASSWORD "${URL}${REPO_PATH}/op/startBackup/java.lang.String%2Cjava.lang.String" --data "installDir=$AEM_HOME&target=$BACKUPDIR"
        echoMessage "online backup triggered $(date +%d-%m-%Y-%H-%m) on NAS $BACKUPDIR" >> $AUTOSYSLOGFILE
        logCurrentBackupStatus
        mailx -s "${LOG_KEY} Online Backup Triggered " $DL < $AUTOSYSLOGFILE
        #monitoring the backup process
        BACKUP_STATUS=`grep -i "\[Backup Worker Thread\]" $AUTOSYSLOGFILE | awk -F'com.day.crx.core.backup.crx.Backup' '{print $2}' | awk '{print $1" "$2}' | tail -1`
        curl -u $USERPASSWORD ${URL}${REPO_PATH}|grep "Backup in progress"
        status=`echo $?`
        stages="Starting stage Finished copying Skipped copying Finished stage"
        if [ "$status" = 0 ] ||  echo "$BACKUP_STATUS" | grep -q $stages ; then
                runtime="300 minute"
                endtime=$(date -ud "$runtime" +%s)
                while [[ $(date -u +%s) -le $endtime ]]
                        do
                        echoMessage "Time Now: `date +%H:%M:%S`"
                        echoMessage "backup still running...."
                        logCurrentBackupStatus
                        BACKUP_STATUS=`grep -i "\[Backup Worker Thread\]" $AUTOSYSLOGFILE| awk -F'com.day.crx.core.backup.crx.Backup' '{print $2}' | awk '{print $1" "$2}' | tail -1`
                        curl -u $USERPASSWORD ${URL}${REPO_PATH}|grep "Backup in progress"
                        status=`echo $?`
                        if [[ $BACKUP_STATUS == "Backup completed." ]] && [[ $status -ne 0 ]]; then
                            echoMessage "online backup has been completed on $(date +%d-%m-%Y-%H-%m) NAS $BACKUPDIR" >> $AUTOSYSLOGFILE;
                            mailx -s "${LOG_KEY} online backup has been competed" $DL < $AUTOSYSLOGFILE
                            rm -f $BACKUPDIR/backupInProgress.txt
                            break;
                        fi
                        echo "Sleeping for 180 seconds"
                        sleep 180
                        done
        else
          echoMessage "online backup did not triggered $(date +%d-%m-%Y-%H-%m) NAS $BACKUPDIR" >> $AUTOSYSLOGFILE;
          mailx -s "${LOG_KEY} online backup did not triggered" $DL < $AUTOSYSLOGFILE
          exit -1
        fi

fi
