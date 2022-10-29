#!/usr/bin/env sh

Help() {
  # Display Help
  echo "Configures APPOXY with the configuration data provided in the appoxy.conf file."
  echo
  echo "Syntax: setup.sh [-r|h|v]"
  echo "options:"
  echo "r    Reloads the configuration file."
  echo "h    Print this Help."
  echo "v    Verbose mode."
  echo
}

Verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "$1"
  fi
}

while getopts ":rhv" option; do
  case $option in
  r) # reload configuration
    RELOAD=true
    ;;
  h) # display Help
    Help
    exit
    ;;
  v) # verbose mode
    VERBOSE=true
    ;;
  \?) # incorrect option
    echo "Error: Invalid option"
    exit
    ;;
  esac
done

# Default Configuration File
DefaultConfig() {
  {
    echo "PUBLIC_DOMAINS=localhost,appoxy.com"
  } >appoxy.conf
}

# Load Configuration File
LoadConfig() {
  if [ -f appoxy.conf ]; then
    . ./appoxy.conf
  else
    DefaultConfig
    . ./appoxy.conf
  fi
}

CreateNginxConfig() {
  server_name="server_name"

#  if no PUBLIC_DOMAINS are provided, use localhost
  if [ -z "$PUBLIC_DOMAINS" ]; then
    Verbose "No PUBLIC_DOMAINS provided, using localhost"
    PUBLIC_DOMAINS="localhost"
  fi

  for domain in $(echo $PUBLIC_DOMAINS | tr ":" "\n"); do
    escaped_domain=$(echo $domain | sed "s/\./\\\./g")
    server_name="$server_name ~^(?<subdomain>.+)\.$escaped_domain$"
  done

  #  if droidnet.nginx exists, create a backup
  if [ -f droidnet.nginx ]; then
    Verbose "droidnet.nginx exists, creating a backup."
    cp droidnet.nginx droidnet.nginx.bak
    Verbose "droidnet.nginx.bak created."
  fi

  {
    echo "server {"
    echo "    server_name $server_name;"
    echo "    location / {"
    echo '        proxy_pass http://$subdomain:16880;'
    echo "        resolver 127.0.0.11;"
    echo "    }"
    echo "}"
  } >droidnet.nginx
  Verbose "droidnet.nginx created."
}

Reload() {
  Verbose "Reloading configuration file..."
  LoadConfig
  Verbose "Loaded configuration file."
  CreateNginxConfig
  Verbose "Updated nginx configuration file."
}

CreateDockerNetworks() {

  if ! command -v docker &>/dev/null; then
    echo "Docker is not installed."
    exit 1
  fi

  if ! command -v docker compose &>/dev/null; then
    echo "Docker Compose is not installed."
    exit 1
  fi

  Verbose "Checking docker networks..."
  if [ -z "$(docker network ls | grep appoxy-corenet)" ]; then
    Verbose "appoxy-corenet does not exist, creating..."
    docker network create appoxy-corenet
  fi
  if [ -z "$(docker network ls | grep appoxy-droidnet)" ]; then
    Verbose "appoxy-droidnet does not exist, creating..."
    docker network create appoxy-droidnet
  fi
  Verbose "Checked docker networks."
}

StartDockerCompose() {
#  if droidnet-proxy.compose.yml does not exist. Create it
  if [ ! -f droidnet-proxy.compose.yml ]; then
    Verbose "droidnet-proxy.compose.yml does not exist."
    {
      echo "version: '3.9'"
      echo "services:"
      echo "  appoxy:"
      echo "    container_name: appoxy-droidnet-proxy"
      echo "    hostname: appoxy-droidnet-proxy"
      echo "    image: nginx:latest"
      echo "    ports:"
      echo "      - 80:80"
      echo "    volumes:"
      echo "      - ./droidnet.nginx:/etc/nginx/conf.d/default.conf"
      echo "    networks:"
      echo "        - appoxy-droidnet"
      echo "        - appoxy-corenet"
      echo "networks:"
      echo "    appoxy-droidnet:"
      echo "        external: true"
      echo "    appoxy-corenet:"
      echo "        external: true"
    } > droidnet-proxy.compose.yml
    Verbose "droidnet-proxy.compose.yml created."
  fi

#  if appoxy-droidnet-proxy container exists, stop it and remove it
  if [ -n "$(docker ps -a | grep appoxy-droidnet-proxy)" ]; then
    Verbose "appoxy-droidnet-proxy container exists, stopping and removing..."
    docker stop appoxy-droidnet-proxy
    docker rm appoxy-droidnet-proxy
  fi

  Verbose "Starting docker compose..."
  docker compose -f droidnet-proxy.compose.yml up -d
  Verbose "Started docker compose."
}

Main() {
  if [ "$RELOAD" = true ]; then
    Reload
    exit
  fi
  CreateDockerNetworks
  LoadConfig
  CreateNginxConfig
  StartDockerCompose
  echo "Appoxy has been configured. You can now deploy your apps using the 'appoxy_deploy_app' command."
  exit
}

Main