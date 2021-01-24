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

The simple application used in this tutorial to demonstrate the deployment process is 
a Python app printing the current time to stdout.

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
Usage: myapp [OPTIONS] COMMAND [ARGS]...

  Welcome to myApp CLI!

Options:
  --help  Show this message and exit.

Commands:
  run  Print job name and current time to stdout.
```

Execute `run` command to print the current time to console:

```shell
$ myapp run --job JOB-1 
15:42:36: JOB-1 started
```

Application is installed to your development environment. Now we can start
preparing it to the deployment.

## 2. Install docker and docker-compose

Skip this section and go to the section 3, if you already have docker installed.

