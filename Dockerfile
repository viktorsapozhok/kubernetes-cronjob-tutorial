FROM python:3.9-slim

RUN groupadd --gid 1000 user \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash user

COPY requirements.txt .
RUN pip install --no-cache-dir -r ./requirements.txt \
    && rm -f requirements.txt

COPY . /home/user/app
WORKDIR /home/user/app

RUN pip install --no-cache-dir . \
    && chown -R "1000:1000" /home/user

USER user
CMD tail -f /dev/null
