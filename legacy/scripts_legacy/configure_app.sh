#!/bin/sh
Verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "$1"
  fi
}

Help() {
  # Display Help
  echo 'Configure an existing app.'
  echo
  echo 'Syntax: setup_new_app.sh [options]'
  echo 'options:'
  echo '-i <id>*: ID of the app to configure.'
  echo '-t <type>*: Type of app to configure. (Options: node, frontend, static)'
  echo '-n <name>*: App name to configure.'
  echo '-p <port>: App port to configure. (node)'
  echo '-b <build_cmd>: Build Command to configure. This is the command that will run after the app is cloned. (frontend, node [optional])'
  echo '-d <publish_dir>: The directory that will be published to the web. (frontend, static)'
  echo '-s <start_cmd>: Start Command to configure. This is the command to start the app. (node)'
  echo '-r <root_dir>: Root Directory to run the commands in. This is the directory where the above commands will be run.'
  echo '-e <env_file>: Environment variables file override. This is a newline separated file containing environment variables in the format KEY=VALUE.'
  echo '-v: Verbose mode.'
  echo '-h: Print this help message.'
  echo
}

ValidTypes(){
  echo "Valid types are:"
  echo "- node: Node.js app with a start command and port, i.e Discord Bots, Express Servers, etc."
  echo "- frontend: Frontend app with a build command and publish directory, i.e. Angular, React, Vue, etc."
  echo "- static: Static files ready to be served, i.e. HTML/CSS/JS, Prebuilt React/Angular/Vue/etc apps."
}
# Get the options
while getopts ':i:t:n:p:b:d:s:r:e:vh' option; do
  case $option in
  v) # Verbose mode
    VERBOSE=true
    ;;
  i) # App ID
    APX_APP_ID=$OPTARG
    Verbose "App ID: $APX_APP_ID"
    ;;
  t) # App type
    APX_APP_TYPE=$OPTARG
#    if it is not one of the three types, exit
    if [ "$APX_APP_TYPE" != "node" ] && [ "$APX_APP_TYPE" != "frontend" ] && [ "$APX_APP_TYPE" != "static" ]; then
      ValidTypes
      exit 1
    fi
    Verbose "App type: $APX_APP_TYPE"
    ;;
  n) # App name
    APX_APP_NAME=$OPTARG
    Verbose "App name: $APX_APP_NAME"
    ;;
  p) # App port
    APX_PORT_OVERRIDE=$OPTARG
    Verbose "App port: $APX_PORT_OVERRIDE"
    ;;
  b) # Build Command
    APX_BUILD_COMMAND=$OPTARG
    Verbose "Build Command: $APX_BUILD_COMMAND"
    ;;
  d) # Build directory
    APX_PUBLISH_DIR=$OPTARG
    Verbose "Publish directory: $APX_PUBLISH_DIR"
    ;;
  s) # Start Command
    APX_START_COMMAND=$OPTARG
    Verbose "Start Command: $APX_START_COMMAND"
    ;;
  r) # Root Directory to run the commands in
    APX_ROOT_DIR=$OPTARG
    Verbose "Root Directory: $APX_ROOT_DIR"
    ;;
  e) # Environment variables overridefile
    APX_ENV_VARS_FILE=$OPTARG
    Verbose "Environment variables file: $APX_ENV_VARS_FILE"
    ;;
  \? | h | *) # Display Help
    echo "ERROR: Invalid option."
    Help
    exit 1
    ;;
  esac
done

if [ $# -eq 0 ]; then
  Help
  exit 1
fi

# Default Vars
DefaultVars() {
  APX_APP_DIR="/var/appoxy/apps/$APX_APP_ID"
  APX_DOMAIN="$APX_APP_NAME.appoxy.com $APX_APP_NAME.localhost"
  APX_PORT_OVERRIDE=${APX_PORT_OVERRIDE:="80"}

  if [ "$APX_PUBLISH_DIR" = "." ] || [ "$APX_PUBLISH_DIR" = "./" ] || [ "$APX_PUBLISH_DIR" = "/" ] || [ "$APX_PUBLISH_DIR" = "~" ]; then
    APX_PUBLISH_DIR=""
  else
    APX_PUBLISH_DIR=$(echo $APX_PUBLISH_DIR | sed -e 's/^\.\///' -e 's/^\///' -e 's/^~\///' -e 's/^~//' -e 's/\/$//')
  fi

  if [ "$APX_ROOT_DIR" = "." ] || [ "$APX_ROOT_DIR" = "./" ] || [ "$APX_ROOT_DIR" = "/" ] || [ "$APX_ROOT_DIR" = "~" ]; then
    APX_ROOT_DIR=""
  else
    APX_ROOT_DIR=$(echo $APX_ROOT_DIR | sed -e 's/^\.\///' -e 's/^\///' -e 's/^~\///' -e 's/^~//' -e 's/\/$//')
  fi

  Verbose "APX_APP_DIR: $APX_APP_DIR"
  Verbose "APX_ROOT_DIR: $APX_ROOT_DIR"
  Verbose "APX_PUBLISH_DIR: $APX_PUBLISH_DIR"
  Verbose "APX_DOMAIN: $APX_DOMAIN"
  Verbose "APX_PORT_OVERRIDE: $APX_PORT_OVERRIDE"

  HOST_ROOT=$APX_APP_DIR/repo$([ -n "$APX_ROOT_DIR" ] && echo "/$APX_ROOT_DIR")
  CONTAINER_ROOT="/usr/share/nginx/html"
}

# Validate Vars
ValidateVars() {
  if [ -z "$APX_APP_ID" ]; then
    echo "ERROR: App ID is required."
    exit 1
  fi
 # if type is NODE, then $APX_START_COMMAND, and $APX_PORT_OVERRIDE are required
 # if type is FRONTEND, then $APX_BUILD_COMMAND and $APX_PUBLISH_DIR
  if [ "$APX_APP_TYPE" = "node" ]; then
    if [ -z "$APX_START_COMMAND" ]; then
      echo "ERROR: Start Command is required for node apps."
      exit 1
    fi
    if [ -z "$APX_PORT_OVERRIDE" ]; then
      echo "ERROR: Port is required for node apps."
      exit 1
    fi
  elif [ "$APX_APP_TYPE" = "frontend" ]; then
    if [ -z "$APX_BUILD_COMMAND" ]; then
      echo "ERROR: Build Command is required for frontend apps."
      exit 1
    fi
    if [ -z "$APX_PUBLISH_DIR" ]; then
      echo "ERROR: Publish directory is required for frontend apps."
      exit 1
    fi
  elif [ "$APX_APP_TYPE" = "static" ]; then
    if [ -z "$APX_PUBLISH_DIR" ]; then
      echo "ERROR: Publish directory is required for static apps."
      exit 1
    fi
  else
    echo "ERROR: App type is required."
    ValidTypes
    exit 1
  fi
}

GenerateEnvFile() {
  rm -f $HOST_ROOT/apx.$APX_APP_ID.env
  touch $HOST_ROOT/apx.$APX_APP_ID.env

  if [ -f "$HOST_ROOT/.env" ]; then
    Verbose "Found .env file in repo. Copying to apx.$APX_APP_ID.env"
    cat $HOST_ROOT/.env >> $HOST_ROOT/apx.$APX_APP_ID.env
  fi
  if [ -n "$APX_ENV_VARS_FILE" ] && [ -f "$APX_ENV_VARS_FILE" ]; then
    Verbose "Overriding environment variables via: $APX_ENV_VARS_FILE"
      if [ -f "$HOST_ROOT/apx.$APX_APP_ID.env" ]; then
        cat $APX_ENV_VARS_FILE >> $HOST_ROOT/apx.$APX_APP_ID.env
      else
        cat $APX_ENV_VARS_FILE > $HOST_ROOT/apx.$APX_APP_ID.env
      fi
  fi

  # if PORT is NOT set in the env file, use the port override
  if ! grep -qP '^PORT=' $HOST_ROOT/apx.$APX_APP_ID.env; then
    echo "PORT=$APX_PORT_OVERRIDE" >>$HOST_ROOT/apx.$APX_APP_ID.env
  fi

  {
    echo "APX_APP_ID=$APX_APP_ID"
    echo "APX_APP_ID=$APX_APP_NAME"
    echo "APX_DOMAIN=$APX_DOMAIN"
    echo "APX_REPO_URL=$REPO_URL"
    echo "APX_PUBLISH_DIR=$APX_PUBLISH_DIR"
  } >>$HOST_ROOT/apx.$APX_APP_ID.env
}

# Generate nginx config file
GenerateNginxConfigFile() {
  rm -f $HOST_ROOT/apx.$APX_APP_ID.nginx.conf
  touch $HOST_ROOT/apx.$APX_APP_ID.nginx.conf

  {
    echo "server {"
    echo '  listen 16880 default_server;'
    echo '  listen [::]:16880 default_server;'
    echo "  server_name $APX_DOMAIN;"
    # if build dir is not empty, append it to the container root
    echo "  root $CONTAINER_ROOT/$APX_PUBLISH_DIR;"
    echo "  index index.html index.htm index.nginx-debian.html;"
    echo '  location / {'
  } >>$HOST_ROOT/apx.$APX_APP_ID.nginx.conf

  if [ "$APX_APP_TYPE" = "node" ]; then
    {
      echo "    proxy_pass http://localhost:$APX_PORT_OVERRIDE;"
      echo '    proxy_http_version 1.1;'
      echo '    proxy_set_header   Upgrade $http_upgrade;'
      echo '    proxy_set_header   Connection keep-alive;'
      echo '    proxy_set_header   Host $host;'
      echo '    proxy_cache_bypass $http_upgrade;'
    } >>$HOST_ROOT/apx.$APX_APP_ID.nginx.conf
  elif [ "$APX_APP_TYPE" = "frontend" ] || [ "$APX_APP_TYPE" = "static" ]; then
      echo '    try_files $uri $uri/ /index.html;' >> $HOST_ROOT/apx.$APX_APP_ID.nginx.conf
  fi
  {
    echo '  }'
    echo '}'
  } >>$HOST_ROOT/apx.$APX_APP_ID.nginx.conf
}

GenerateEntrypoint() {
  rm -f $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh
  touch $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh

  {
    echo "#!/bin/sh"
    echo "cd $CONTAINER_ROOT"
    echo "if [ -f \"package.json\" ]; then"
    echo "  echo \"Found package.json. Installing Node and NPM \""
    echo "  apk add --update nodejs npm"
    echo "  node -v"
    echo "  echo \"Running npm install\""
    if [ "$APX_APP_TYPE" = "node" ] || [ "$APX_APP_TYPE" = "frontend" ]; then
      echo "  npm install"
    fi
#    if BUILD command is set, run it, if it takes more than 5 minutes, kill it and exit
    if [ -n "$APX_BUILD_COMMAND" ]; then
      echo "  echo \"Running build command: $APX_BUILD_COMMAND\""
      echo "  timeout 300 $APX_BUILD_COMMAND"
      echo "  if [ \$? -eq 124 ]; then"
      echo "    echo \"Build command timed out after 5 minutes. Exiting.\""
      echo "    exit 1"
      echo "  fi"
    fi
    if [ -n "$APX_START_COMMAND" ]; then
      echo "  echo \"Running start command: $APX_START_COMMAND\""
      echo "  $APX_START_COMMAND &"
    fi
    echo "fi"
  } >> $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh

  chmod +x $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh
#  echo "Generated $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh"
}

GenerateComposeFile() {
  rm -f $HOST_ROOT/apx.$APX_APP_ID.compose.yml
  touch $HOST_ROOT/apx.$APX_APP_ID.compose.yml

  {
    echo "version: '3.9'"
    echo "services:"
    echo "  $APX_APP_ID$APX_APP_NAME:"
    echo "    container_name: ${APX_APP_ID}_${APX_APP_NAME}"
    echo "    hostname: ${APX_APP_NAME}"
    echo "    image: nginx:alpine"
    echo "    env_file:"
    echo "      - $HOST_ROOT/apx.$APX_APP_ID.env"
    echo "    volumes:"
    echo "      - $HOST_ROOT/apx.$APX_APP_ID.nginx.conf:/etc/nginx/conf.d/default.conf"
    echo "      - $HOST_ROOT:$CONTAINER_ROOT"
    echo "      - $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh:/docker-entrypoint.d/apx.$APX_APP_ID.entrypoint.sh"
    echo "    networks:"
    echo "      - appoxy-droidnet"
    echo "networks:"
    echo "  appoxy-droidnet:"
    echo "    external: true"
  } >>$HOST_ROOT/apx.$APX_APP_ID.compose.yml

#  echo "Generated $HOST_ROOT/apx.$APX_APP_ID.droidnet-proxy.compose.yml"
}

main() {
  DefaultVars
  ValidateVars
  GenerateEnvFile
  GenerateNginxConfigFile
  GenerateEntrypoint
  GenerateComposeFile

  if [ ! -f "/etc/appoxy/app.list" ]; then
    Verbose "Creating app list file"
    mkdir -p /etc/appoxy
    touch /etc/appoxy/app.list
  fi
  #write the app id and host root to a file so we can use it later
  echo "$APX_APP_ID $HOST_ROOT" >> /etc/appoxy/app.list

  Verbose "Generated $HOST_ROOT/apx.$APX_APP_ID.env"
  Verbose "Generated $HOST_ROOT/apx.$APX_APP_ID.nginx.conf"
  Verbose "Generated $HOST_ROOT/apx.$APX_APP_ID.entrypoint.sh"
  Verbose "Generated $HOST_ROOT/apx.$APX_APP_ID.compose.yml"
  Verbose "Done. You can now run '$(pwd)/deploy_app.sh $APX_APP_ID' to deploy your app."
}

main
