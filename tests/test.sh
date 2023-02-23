#!/bin/bash

LOG_FILE="/local/scratch/gsamaem6/cq-author/adobeaem/logs/output.log"

COMPACTION_TIME=$(tac "$LOG_FILE" | grep -m 1 -oP 'Compaction succeeded in \K[\d\.]+ h \(.*\)')

SEGMENT_STORE_SIZE=$(tac "$LOG_FILE" | grep -m 1 -oP 'New segment store size is \K[\d.]+[KMG]')

BEFORE_COMPACTION_SIZE=$(tac "$LOG_FILE" | awk '/compacting/ {getline; if ($0 ~ /size/) {print $0; exit}}')

DATE_TIME=$(tac "$LOG_FILE" | grep -m 1 -oP '.*After compaction,.*' | grep -oP '^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}')

echo "Size Before Compaction is $BEFORE_COMPACTION_SIZE"
echo "Compaction succeeded in $COMPACTION_TIME"
echo "New segment store size is $SEGMENT_STORE_SIZE"
echo "Date of compaction is $DATE_TIME


