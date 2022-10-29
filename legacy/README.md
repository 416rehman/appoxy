# APPOXY - Work In Progress

## What is it?
A heroku-like platform for deploying applications. It is a work in progress.

## Prerequisites
- Docker
- Docker Compose

## How to use it?
Run 
```sh
 # Clone the repo
git clone git@github.com:416rehman/appoxy.git && cd ./appoxy &&
# Configure the Appoxy system (sets up docker networking, nginx proxying, and more) 
sudo ./configure.sh &&
#Deploy the example application
sudo ./appoxy_deploy_app -g "https://github.com/416rehman/Rest-Inn.git" -r ./client -e ./.envfiles/restinnclient.env -b "npm run build" -t frontend -d build
```
