info=$(
  gcloud compute instances describe "${EIRINI_STATION_USERNAME}-eirini-station" \
    --project cff-eirini-peace-pods \
    --zone="europe-west2-a" \
    --format="value(status, networkInterfaces[0].accessConfigs[0].natIP)"
)

export STATION_STATUS=$(cut -f 1 -d ' ' <<<$info)
export STATION_IP=$(cut -f 2 -d ' ' <<<$info)
export STATION_HISTORY_BACKUP="$HOME/eirini-station-history-backup"