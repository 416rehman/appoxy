#!/bin/sh
Help(){
  echo 'Deploy an existing app.'
  echo 'Syntax: deploy_app.sh <app_id> [options]'
  echo 'options:'
  echo '-f: Follow container logs.'
  echo '-h: Print this help message.'
}

# Get the options
while getopts ":hf" option; do
  case $option in
  f) # Follow container logs
    FOLLOW=true
    ;;
  \? | h | *) # Display Help
    Help
    exit
    ;;
  esac
done

#check if the app id is valid by checking it in the app.list file
if ! grep -qP "^$1 " /etc/appoxy/app.list; then
  echo "ERROR: App ID $1 is not valid."
  exit 1
fi

#get the host root (1 LINE ONLY) from the apx.app.list file, column 2
HOST_ROOT=$(grep -P "^$1 " /etc/appoxy/app.list | head -n 1 | cut -d ' ' -f 2)

#run the entrypoint script from the HOST_ROOT and display the live output
#$HOST_ROOT/apx.$1.entrypoint.sh | tee logs/apx.$1.log
echo "HOST_ROOT: $HOST_ROOT"
docker compose -f "$HOST_ROOT/apx.$1.compose.yml" up -d --build
# container_name format: id_*name*
echo "Container ID: $(docker ps -qf "name=$1")"

if [ "$FOLLOW" = true ]; then
  echo $("docker logs -f $(docker ps -qf "name=$1")")
  docker logs -f $(docker ps -qf "name=$1")
fi
