# kubernetes-cronjob-tutorial

This repository provides a demo on how to deploy cron jobs to Azure Kubernetes Service (AKS).

You learn how to: 

* Prepare a Python app for deployment to AKS and build a docker image.
* Create an Azure container registry and push images to the registry.
* Create and configure a Kubernetes cluster, scale it down to zero with autoscaler.
* Schedule and deploy jobs to Kubernetes cluster.

Read the [tutorial][1] for more.

[1]: https://viktorsapozhok.github.io "Running automated tasks with CronJob in Azure Kubernetes Service"

## 1. Clone the application

The application used in this tutorial to demonstrate the deployment process is 
a simple Python app printing the current time to stdout.

Clone the application to your development environment.

```shell
$ git clone https://github.com/viktorsapozhok/kubernetes-cronjob-tutorial.git
```

Then go to the project directory and install the application.

```shell
$ cd kubernetes-cronjob-tutorial
$ pip install .
```

When its installed, you can verify the installation calling `myapp` from the command line.

```shell
$ myapp --help
Usage: myapp [OPTIONS]

  Demo app printing current time to stdout.

Options:
  --job TEXT  Job name
  --help      Show this message and exit.
```

Run it, to print the current time to console:

```shell
$ myapp --job JOB-1 
15:42:36: JOB-1 started
```

Application is installed to your development environment. Now we can start
preparing it to the deployment.

## 2. Install docker and docker-compose

Skip this section and go to the section 3, if you already have docker installed.

Update software repositories to make sure you’ve got access to the latest revisions.
Then install docker engine.

```bash
$ sudo apt-get update
$ sudo apt install docker.io
```

Now we set up docker service to be running at startup.

```bash
$ sudo systemctl start docker
$ sudo systemctl enable docker
```

You can test the installation verifying docker version.

```bash
$ sudo docker --version
```

By default, the docker daemon always run as `root` user and other users can access it
only with `sudo` privileges. To be able to run docker as non-root user, create a new group
called `docker` and add your user to it.

```bash
$ sudo groupadd docker
$ sudo usermod -aG docker $USER
```

Log out and log back in so that group membership is re-evaluated.
You can also issue the following command to activate changes.

```bash
$ newgrp docker
```

Verify if docker can be run as non-root.

```bash
$ docker run hello-world
```

Reboot if you got error.

Now, after docker engine is installed, we install docker compose, a tool for
defining and running multi-container docker applications. 

Follow the [official installation guide][2] and test the installation verifying compose version.

[2]: https://docs.docker.com/compose/install/ "Install Docker Compose"

```bash
$ docker-compose --version
```

## 3. Create docker image for your Python app


