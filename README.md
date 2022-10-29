# Appoxy - Cloud Native PaaS

## What is it?

Appoxy is a cloud native PaaS that allows you to deploy your applications to a cluster of servers. It is a work in progress.
Built around the concept of buildpacks, Appoxy can be self-hosted by anyone via a single machine configuration or a highly scalable multi-machine configuration.


## Why Appoxy?

Appoxy is a PaaS that is built with the following principles in mind:
- **Consumable**: Appoxy allows you to let your users deploy their applications on your platform.
- **Cloud Native**: Scalability is a first class citizen. Appoxy is built to be deployed on a single machine or a cluster of machines.
- **Open Source**: Appoxy is built with open source technologies and is open source itself.
- **Simple**: Operating Appoxy and deploying applications on it should be simple and intuitive.

## Features
Appoxy is a work in progress. The following features are planned:
- [x] 1-Script server provisioning
- [x] Buildpacks for deploying applications
- [ ] Deploy applications via git
- [ ] Frontend client for users to manage their applications
- [ ] Frontend client for admins to manage the platform

## How it works

### Application Management
Users deploy their applications from the frontend client. The frontend client communicates with Droid Administration Microservice (DAMS) which figures out which droid-server to deploy the application on. Once the droid-server is selected, the application is deployed on it via the Droid-Server Interface (DSI). The DSI communicates with the docker daemon of the droid-server to deploy the application.
<div style="text-align: center;">

![](docs/app_management.png)
App Management Operation Flow (Destroying an application)

</div>

### Public Internet Access

Appoxy uses a Global Nginx Proxy (or many proxies in scalable configuration) to intercept requests from the public internet and route them to the correct droid-server. Each droid-server has a local Nginx Proxy that routes requests to the correct application.

I.e A request to 'https://myapp.appoxy.com' is intercepted by the Global Nginx Proxy, which queries the database to find the droid-server hosting the application and the unique internal id of the application. The Global Nginx Proxy then routes the request to the local Nginx Proxy of the droid-server. The local Nginx Proxy then routes the request to the correct application by using the unique internal id of the application to match it with the correct container.

<div style="text-align: center;">

![](docs/public_access.png)
Visitor Accessing an Application
</div>