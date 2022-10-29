#!/usr/bin/env sh

# help function
help() {
  echo "Provisions a new droid-server instance by configuring Nginx, Docker, Git, Pack, and Droid-Server Interface (DSI)."
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -h, --help          show this help message and exit"
  echo "  -d, --domain        comma-separated list of domains that will be used by apps. i.e if domain is set to 'myhost.com', then the apps will be available at 'app.myhost.com'"
  echo "  -v, --verbose       verbose output"
}

GREEN='\033[42m'
RED='\033[41m'
NC='\033[0m' # No Color

while [ "$1" != "" ]; do
  case $1 in
  -h | --help)
    help
    exit
    ;;
  -d | --domain)
    shift
    DOMAIN=$1
    ;;
  -v | --verbose)
    VERBOSE=1
    ;;
  *)
    help
    exit 1
    ;;
  esac
  shift
done

validate() {
  if [ -z "$DOMAIN" ]; then
    echo "${RED}Error: domain is required. Please provide a comma-separated list of domains that will be used by apps. i.e if domain is set to 'myhost.com', then the apps will be available at 'app.myhost.com'${NC}"
    echo "Example: $0 -d myhost.com,localhost"
    exit 1
  fi
}

verbose() {
  if [ -n "$VERBOSE" ]; then
    echo "$@"
  fi
}

get_init() {
#  if init system is systemd then use systemctl, if upstart then use service
  if systemctl ; then
    verbose "${GREEN}systemd detected${NC}"
    INIT="systemctl"
  elif service --version ; then
    verbose "${GREEN}upstart detected${NC}"
    INIT="service"
  else
    echo "${RED}No init system detected. Exiting...${NC}"
    exit 1
  fi
}


update_ubuntu() {
  verbose "${GREEN}Updating Ubuntu...${NC}"
  apt-get update
  apt-get upgrade -y

  verbose "${GREEN}Installing dependencies...${NC}"
  apt-get install -y git curl wget software-properties-common
}

provision_git() {
  verbose "${GREEN}Installing Git...${NC}"
  if ! command -v git; then
    verbose "${GREEN}Installing Git...${NC}"
    apt-get install git -y
  fi
  verbose "${GREEN}Git installed${NC}"

  verbose "${GREEN}Configuring Git...${NC}"
  git config --global user.name "droid-server"
  git config --global user.email "droid-server@localhost"
  verbose "${GREEN}Git configured${NC}"

  verbose "${GREEN}Generating SSH key...${NC}"
}

provision_docker() {
  verbose "${GREEN}Installing Docker...${NC}"
  if ! command -v docker; then
    verbose "${GREEN}Installing Docker...${NC}"
    apt-get install \
      ca-certificates \
      curl \
      gnupg \
      lsb-release -y

    verbose "${GREEN}Adding Docker's official GPG key...${NC}"
    yes | mkdir -p /etc/apt/keyrings
    yes | curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    verbose "${GREEN}Setting up the stable repository...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    verbose "${GREEN}Updating the apt package index...${NC}"
    chmod a+r /etc/apt/keyrings/docker.gpg
    apt-get update -y

    # Install the latest version of Docker Engine and containerd
    apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
  fi
  verbose "${GREEN}Docker installed${NC}"

  verbose "${GREEN}Configuring Docker...${NC}"
  # if docker group does not exist, create it
  if ! getent group docker; then
    verbose "${GREEN}Creating docker group...${NC}"
    groupadd docker
  fi

  # if $USER is not set, set it to the current user
  if [ -z "$USER" ]; then
    verbose "Setting USER to current user"
    USER=$(whoami)
  fi

  # if user environment variable is not in docker group, add it
  if ! id -nG "$USER" | grep -qw "docker"; then
    verbose "Adding $USER to docker group"
    usermod -aG docker "$USER"
  fi

  # Set permissions on ~/.docker directory
  chown "$USER":"$USER" /home/"$USER"/.docker -R
  chmod g+rwx "$HOME/.docker" -R

  #start and enable docker
  if [ "$INIT" = "systemctl" ]; then
    systemctl start docker
    systemctl enable docker
  elif [ "$INIT" = "service" ]; then
    service docker start
    update-rc.d docker enable
  elif [ "$INIT" = "rc-service" ]; then
    rc-service docker start
    rc-update add docker default
  fi

  # Create the droid-net network
  docker network create droid-net
  verbose "Docker Network ${GREEN}droid-net${NC} created"

  verbose "${GREEN}Docker configured${NC}"
}

provision_nginx() {
  verbose "${GREEN}Provisioning Nginx...${NC}"
  if ! command -v nginx; then
    verbose "Installing Nginx"
    apt-get install nginx -y
  fi

  if ! command -v nginx; then
    echo "Failed to install Nginx. Please install Nginx manually and try again."
    exit 1
  fi
  verbose "${GREEN}Nginx installed${NC}"

  verbose "${GREEN}Configuring Nginx...${NC}"
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default

  # Seperate domains by space
  domains=$(echo "$DOMAIN" | tr -d '[:space:]' | tr ',' ' ')
  server_names=""
  for dom in $domains; do
    server_names="$server_names ~^(?<app_id>.+)\.$dom$"
  done

  # Create Nginx config file that redirects requests to app_id
  tee /etc/nginx/sites-available/droid-server <<EOF
server {
    listen 80;
    server_name $server_names;

    location / {
EOF
  tee -a /etc/nginx/sites-available/droid-server <<"EOF"
        proxy_pass http://$app_id:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        }
}
EOF

  # Enable Nginx config file
  ln -s /etc/nginx/sites-available/droid-server /etc/nginx/sites-enabled/droid-server

  # Test Nginx config
  if ! nginx -t; then
    echo "${RED}Nginx config test failed. Please check your config and try again.${NC}"
    exit 1
  fi

  # Restart Nginx
  if [ "$INIT" = "systemctl" ]; then
    systemctl restart nginx
  elif [ "$INIT" = "service" ]; then
    service nginx restart
  elif [ "$INIT" = "rc-service" ]; then
    rc-service nginx restart
  fi

  verbose "${GREEN}Nginx configured${NC}"
}

provision_pack() {
  verbose "${GREEN}Provisioning pack...${NC}"
  if ! command pack version; then
    verbose "Installing Pack"

    # Add Pack's official GPG key
    add-apt-repository ppa:cncf-buildpacks/pack-cli -y

    # Update the apt package index
    apt-get update -y

    # Install the latest version of Pack
    apt-get install pack-cli -y
  fi

  if ! command pack version; then
    echo "${RED}Failed to install Pack. Please install Pack manually and try again.${NC}"
    exit 1
  fi

  verbose "${GREEN}Pack Provisioning Complete${NC}"
}

provision_dsi() {
  echo "${GREEN}Provisioning Droid Server Installer...${NC}"

  # TODO: Provision DSI
  # This function should install DSI and configure it to run on startup so the DSI is accessible on port 8000

  echo "${GREEN}Droid Server Installer Provisioning Complete${NC}"
}

main() {
  validate

  if ! get_init; then
    echo "${RED}Failed to detect init system. Please install Docker manually and try again.${NC}"
    exit 1
  fi

  if ! update_ubuntu; then
    echo "Failed to update Ubuntu" >&2
    exit 1
  fi

  if ! provision_git; then
    echo "Failed to provision Git" >&2
    exit 1
  fi

  if ! provision_docker; then
    echo "Failed to provision Docker" >&2
    exit 1
  fi

  if ! provision_nginx; then
    echo "Failed to provision Nginx" >&2
    exit 1
  fi

  if ! provision_pack; then
    echo "Failed to provision Pack" >&2
    exit 1
  fi

  if ! provision_dsi; then
    echo "Failed to provision DSI" >&2
    exit 1
  fi

#  green_bg "Droid Server Installer Provisioning Complete"
  verbose "${GREEN}Provisioning Complete${NC}"
  # run newgrp to apply changes
  newgrp docker
}

main "$@"
