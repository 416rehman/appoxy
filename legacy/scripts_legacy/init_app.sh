#!/bin/sh
# This script does the following:
# 1. Generates an APP_ID and APP_NAME (using a verb and noun)
# 2. Creates a new directory named APP_ID in the /var/appoxy/apps directory
# 3. Using envsubst, it replaces the APP_ID, APP_NAME, PORT, and DOMAIN variables in the nginx.conf file and copies it to the new app directory

# Help function
Help() {
  # Display Help
  echo 'Setup a new appoxy app for deployment. Initializes a new app directory and clones the repo.'
  echo
  echo 'Syntax: setup_new_app.sh [options]'
  echo 'options:'
  echo '-g: Github source code repo URL.'
  echo '-v: Verbose output.'
  echo '-n: App name.'
  echo
}

# Get the options
while getopts ":v:g:n:" option; do
  case $option in
  v) # Verbose output
    VERBOSE=true
    ;;
  g) # Github source code repo URL
    REPO_URL=$OPTARG
    if [ "$VERBOSE" = true ]; then
      echo "Github source code repo URL: $REPO_URL"
    fi
    ;;
  n) # App name
    APP_NAME=$OPTARG
    if [ "$VERBOSE" = true ]; then
      echo "App name: $APP_NAME"
    fi
    ;;
  \? | h | *) # Display Help
    Help
    exit
    ;;
  esac
done

if [ $# -eq 0 ]; then
  Help
  exit
fi

# Generate a random app ID
GenerateAppId() {
  APP_ID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
}

CreateDirectory() {
  APP_DIR="/var/appoxy/apps/$APP_ID"
  mkdir -p $APP_DIR/repo
}

CloneSourceCodeRepo() {
  if [ "$VERBOSE" = true ]; then
    echo "Cloning source code repo..."
  fi
#  Git clone and auto accept host key
  git clone $REPO_URL $APP_DIR/repo
}

main() {
  GenerateAppId
  CreateDirectory
  CloneSourceCodeRepo
    if [ $? -ne 0 ]; then
      echo "An error occurred while cloning the source code repo. Please check the URL and try again." >&2
      rm -rf /var/appoxy/apps/$APP_ID
      exit 1
    fi
  echo "$APP_ID|$APP_NAME|$APP_DIR"
}

main
