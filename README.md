# kubernetes-cronjob-tutorial

This repository provides a tutorial on how to deploy cron jobs to Azure Kubernetes Service (AKS).

You learn how to: 

* Prepare a Python app for deployment to AKS and build a docker image.
* Create an Azure container registry and push images to the registry.
* Create and configure a Kubernetes cluster, scale it down to zero with autoscaler.
* Schedule and deploy jobs to Kubernetes cluster.
* Automate the deployment process with Makefile.

Read the [tutorial][1] for more.

[1]: https://viktorsapozhok.github.io "Running automated tasks with CronJob in Azure Kubernetes Service"

## 1. Clone the application

The application used in this tutorial to demonstrate the deployment process is 
a simple Python app printing message to stdout and to slack channel.

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

  Demo app printing current time and job name.

Options:
  --job TEXT  Job name
  --slack     Send message to slack
  --help      Show this message and exit.
```

You can run it without sending messages to the slack channel, only printing to console.
In this case, don't pass the `slack` flag.

```shell
$ myapp --job JOB-1 
14:00:26: JOB-1 started
```

To integrate it with slack, you need to configure an incoming webhook for your channel. Read [here][2] 
how to do this. Add a Webhook URL you will get to an environment variable `SLACK_TEST_URL`.

[2]: https://api.slack.com/messaging/webhooks# "Sending messages using incoming Webhooks"

Verify that it works by passing `slack` flag to `myapp` command.

```bash
$ myapp --job JOB-1 --slack 
14:00:34: JOB-1 started
```

If everything is correct then you should receive the same message in your slack channel.

<img src="https://github.com/viktorsapozhok/kubernetes-cronjob-tutorial/blob/master/docs/source/images/slack.png?raw=true" width="700">

Application is installed to your development environment, and we can start preparing it to the deployment.

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

Follow the [official installation guide][3] and test the installation verifying compose version.

[3]: https://docs.docker.com/compose/install/ "Install Docker Compose"

```bash
$ docker-compose --version
```

## 3. Create docker image for your Python app

Now that we have installed our application and docker software, we can build a docker image 
for the application and run it inside the container. To do that, we create a Dockerfile, a text file
that contains a list of instructions, which describes how a docker image is built.

We store Dockerfile in the project root directory and add the following instructions to it:

```dockerfile
FROM python:3.9-slim

COPY requirements.txt .
RUN pip install --no-cache-dir -r ./requirements.txt \
    && rm -f requirements.txt

RUN groupadd --gid 1000 user \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash user

COPY . /home/user/app
WORKDIR /home/user/app

RUN pip install --no-cache-dir . \
    && chown -R "1000:1000" /home/user 

USER user
CMD tail -f /dev/null
```

Here we create a non-root user, as it's not recommended running the container as a root due 
to some security issues.

We intentionally keep the list of requirements outside `setup.py` to be able to install it
in a separate layer, before installing the application. The point is that docker is caching 
every layer (each `RUN` instruction will create a layer) and checks the previous builds
to use the untouched layers as cache.

In case we don't keep the requirements in a separate file, but instead list them directly in `setup.py`,
docker will install it again every time we change something in the application code
and rebuild the image. Therefore, if we want to reduce the building time, we use two
layers for installation, one for requirements, one for application. 

We also modify `setup.py` to dynamically read the list of requirements from file:

```python
from setuptools import setup


def get_requirements():
    r = []
    with open("requirements.txt") as fp:
        for line in fp.read().split("\n"):
            if not line.startswith("#"):
                r += [line.strip()]
    return r


setup(
    name="app",
    packages=["app"],
    include_package_data=True,
    zip_safe=False,
    install_requires=get_requirements(),
    entry_points={
        "console_scripts": [
            "myapp=app.cli:main",
        ]
    },
)
```

We can now build the docker image using `docker build` command.

```bash
$ docker build --tag app:v0 .
```

When building process is over, you can find your image in local image store.

```bash
$ docker images
REPOSITORY   TAG        IMAGE ID       CREATED             SIZE
app          v0         73ac1e524c0e   35 seconds ago      123MB
python       3.9-slim   609da079b03a   About an hour ago   115MB
```

All right, now let's run our application inside the container.

```bash
$ docker run app myapp --job JOB-1 
20:56:33: JOB-1 started
```

The container has been started and application was successfully running inside the container.
Container stops after the application has finished. Docker containers are 
not automatically removed when you stop them. To remove one or more containers, use 
`docker container rm` command specifying container IDs you want to remove.

You can view the list of all containers using `docker container ls --all` command.

```bash
$ docker container ls --all
CONTAINER ID   IMAGE   COMMAND               CREATED             STATUS                       
c942c2424719   app     "myapp"               3 seconds ago       Exited (0) 2 seconds ago
0d311b2708e4   app     "myapp --job JOB-1"   8 seconds ago       Exited (0) 7 seconds ago
```

From the list above, you can see the `CONTAINER ID`. Pass it to `docker container rm` command to delete 
the containers.

```bash
# remove two containers
$ docker container rm c942c2424719 0d311b2708e4
c942c2424719
0d311b2708e4

# remove one container
$ docker container rm c942c2424719
c942c2424719
```

To remove all stopped containers, use `docker container prune` command.

Note, that you can start the container with `--rm` flag meaning that the container
will be automatically removed after stop.

```bash
$ docker run --rm app myapp --job JOB-1 
```

## 4. Push docker images to the registry

Azure Container Registry (ACR) is a private registry for container images, it allows
you to build, store, and manage container images. In this tutorial, we deploy an ACR instance
and push a docker image to it. This requires that you have Azure CLI installed. Follow the
[official guide][4] if you need to install it.

[4]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli "Install Azure CLI"

To create an ACR instance, we need to have a resource group, a logical container that
include all the related resources to your solution. Create a new group with `az group create` command or
use the existing group if you already have one.

```bash
$ az group create --name myResourceGroup --location westeurope
```

Now we can create an Azure Container Registry with `az acr create` command. We use the `Basic` SKU, which
includes 10 GiB storage. Service tier can be changed at any time, you can use `az acr update` command to 
switch between service tiers.

```bash
$ az acr create \
  --resource-group myResourceGroup \
  --name vanillacontainerregistry \
  --sku Basic \
  --location westeurope
```

To push our docker image to the registry, it has to be tagged with the server address `vanillacontainerregistry.azurecr.io`.
You can find the address on Azure Portal. 

```bash
$ docker tag app:v0 vanillacontainerregistry.azurecr.io/app:v0

$ docker images
REPOSITORY                                TAG   IMAGE ID       CREATED        SIZE
vanillacontainerregistry.azurecr.io/app   v0    46894e5479b8   25 hours ago   123MB
app                                       v0    46894e5479b8   25 hours ago   123MB
```

Now, we can log in to the registry and push our container image.

```bash
$ az acr login --name vanillacontainerregistry
Login Succeeded

$ docker push vanillacontainerregistry.azurecr.io/app:v0
The push refers to repository [vanillacontainerregistry.azurecr.io/app]
d4f6821c5d53: Pushed 
67a0bfcd1c19: Pushed 
1493f3cb6eb5: Pushed 
d713ef9ef160: Pushed 
b53f0c01f700: Pushed 
297b05241274: Pushed 
677735e8b7e0: Pushed 
0315c2e53dfa: Pushed 
98a85d041f35: Pushed 
02c055ef67f5: Pushed 
v0: digest: sha256:2b11fb037d0c3606dd32daeb95e355655594159de6a8ba11aa0046cad0e93838 size: 2413
```

That's it. We built a docker image for our Python application, created an Azure Container Registry and
pushed the image to the repository. You can view the repository with `az acr repository` command or via portal.

```bash
$ az acr repository show-tags --name vanillacontainerregistry --repository app --output table
Result
--------
v0
```

All good, we move on to the next step.

## 5. Create and configure Kubernetes cluster

