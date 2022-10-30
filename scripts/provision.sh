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
YELLOW='\033[43m'
BLUE='\033[44m'
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
    echo -e "${RED}No init system detected. Exiting...${NC}"
    exit 1
  fi
}


update_ubuntu() {
  verbose "${YELLOW}Provisioning Ubuntu...${NC}"
  verbose "${BLUE}Updating Ubuntu...${NC}"
  apt-get update
  apt-get upgrade -y

  verbose "${BLUE}Installing dependencies...${NC}"
  apt-get install -y git curl wget software-properties-common

  verbose "${GREEN}Ubuntu provisioning completed.${NC}"
}

provision_git() {
  verbose "${YELLOW}Provisioning Git...${NC}"
  if ! command -v git; then
    verbose "${BLUE}Installing Git...${NC}"
    apt-get install git -y
  fi
  verbose "${BLUE} Git installed. ${NC}"

  verbose "${BLUE}Configuring Git...${NC}"
  git config --global user.name "droid-server"
  git config --global user.email "droid-server@localhost"

  verbose "${GREEN}Git provisioning completed.${NC}"

}

provision_docker() {
  verbose "${YELLOW}Provisioning Docker...${NC}"
  if ! command -v docker; then
    verbose "${BLUE}Installing Docker...${NC}"
    apt-get install \
      ca-certificates \
      curl \
      gnupg \
      lsb-release -y

    verbose "${BLUE}Adding Docker's official GPG key...${NC}"
    yes | mkdir -p /etc/apt/keyrings
    yes | curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

    verbose "${BLUE}Setting up the stable repository...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    verbose "${BLUE}Updating the apt package index...${NC}"
    chmod a+r /etc/apt/keyrings/docker.gpg
    apt-get update -y

    # Install the latest version of Docker Engine and containerd
    apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
  fi
  verbose "${BLUE}Docker installed${NC}"

  verbose "${BLUE}Configuring Docker...${NC}"
  # if docker group does not exist, create it
  if ! getent group docker; then
    verbose "${BLUE}Creating docker group.${NC}"
    groupadd docker
  fi

  # if $USER is not set, set it to the current user
  if [ -z "$USER" ]; then
    verbose "${BLUE}Setting USER to current user.${NC}"
    USER=$(whoami)
  fi

  # if user environment variable is not in docker group, add it
  if ! id -nG "$USER" | grep -qw "docker"; then
    verbose "${BLUE}Adding $USER to docker group.${NC}"
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
  verbose "Docker Network ${BLUE}droid-net${NC} created"

  verbose "${GREEN}Docker provisioning completed.${NC}"
}

provision_nginx() {
  verbose "${YELLOW}Provisioning Nginx...${NC}"
  if ! command -v nginx; then
    verbose "${BLUE}Installing Nginx...${NC}"
    apt-get install nginx -y
  fi

  if ! command -v nginx; then
    echo "${RED}Error: Nginx installation failed. Exiting...${NC}"
    exit 1
  fi
  verbose "${BLUE}Nginx installed${NC}"

  verbose "${BLUE}Configuring Nginx...${NC}"
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default

  verbose "${BLUE}Parsing domains...${NC}"
  # Seperate domains by space
  domains=$(echo "$DOMAIN" | tr -d '[:space:]' | tr ',' ' ')
  server_names=""
  for dom in $domains; do
    server_names="$server_names ~^(?<app_id>.+)\.$dom$"
  done
  verbose "${BLUE}Parsed server_name: $server_names${NC}"

  verbose "${BLUE}Generating Nginx config file.${NC}"
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

  verbose "${BLUE}Enabling Nginx config file.${NC}"
  # Enable Nginx config file
  ln -s /etc/nginx/sites-available/droid-server /etc/nginx/sites-enabled/droid-server

  # Test Nginx config
  if ! nginx -t; then
    echo -e "${RED}Nginx config test failed. Please check your config and try again.${NC}"
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

  verbose "${GREEN}Nginx provisioning completed.${NC}"
}

provision_pack() {
  verbose "${GREEN}Provisioning pack...${NC}"
  if ! command pack version; then
    verbose "${BLUE}Installing pack...${NC}"

    # Add Pack's official GPG key
    add-apt-repository ppa:cncf-buildpacks/pack-cli -y

    # Update the apt package index
    apt-get update -y

    # Install the latest version of Pack
    apt-get install pack-cli -y
  fi
  verbose "${BLUE}Pack installed${NC}"

  if ! command pack version; then
    echo -e "${RED}Failed to install Pack. Please install Pack manually and try again.${NC}"
    exit 1
  fi

  verbose "${GREEN}Pack Provisioning Complete${NC}"
}

provision_dsi() {
  echo "${YELLOW}Provisioning Droid Server Installer...${NC}"

  # TODO: Provision DSI

  echo "${GREEN}DSI provisioning completed.${NC}"
}

create_apps_dir() {
  verbose "${YELLOW}Creating /apps directory...${NC}"
  if [ ! -d /apps ]; then
    mkdir /apps
  fi
  verbose "${GREEN}/apps directory created${NC}"
}

main() {
  validate

  if ! get_init; then
    echo -e "${RED}Failed to detect init system. Please install Docker manually and try again.${NC}"
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

  if ! create_apps_dir; then
    echo "Failed to create /apps directory" >&2
    exit 1
  fi

#  green_bg "Droid Server Installer Provisioning Complete"
  verbose "${GREEN}Provisioning Complete${NC}"
  # run newgrp to apply changes
  newgrp docker
}

main "$@"
