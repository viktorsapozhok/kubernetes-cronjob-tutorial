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

We can now build the docker image.

```bash
$ docker build --tag app .
```

When building process is over, you can find your image in local image store.

```bash
$ docker images
REPOSITORY   TAG        IMAGE ID       CREATED             SIZE
app          latest     73ac1e524c0e   35 seconds ago      123MB
python       3.9-slim   609da079b03a   About an hour ago   115MB
```

All right, now let's run our application inside the container.

```bash
$ docker run app myapp --job JOB-1 
20:56:33: JOB-1 started
```

The container has been started and application was successfully running inside the container.
When application finished, the container has been stopped. Docker containers are 
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

