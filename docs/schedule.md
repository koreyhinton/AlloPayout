# Schedule the cron

## Remote Server Preparation

First ssh to access the remote VPS server (tested on debian) directly.

### Install java jdk

You can optionally replace jdk with jre (java runtime environment) if you know
you'll never compile directly on the server.

```sh
which java
```

If java is not installed, then install it and verify the version installed.

```sh
sudo apt update
sudo apt install openjdk-21-jdk-headless
java --version
```

```
openjdk 21.0.12.1 2026-08-18
```

### Create linux user and directories

Create the linux user and verify it exists

```sh
sudo useradd --system --no-create-home --shell /usr/sbin/nologin allopayout
getent passwd allopayout
```

```
# something in this format:
allopayout:x:...:...::/home/allopayout:/usr/sbin/nologin
```

Create the application directory, the log directory, and etc config directory.

```sh
sudo mkdir /srv/AlloPayout
sudo chown root:root /srv/AlloPayout
sudo chmod 755 /srv/AlloPayout

sudo mkdir /var/log/AlloPayout
sudo chown allopayout:allopayout /var/log/AlloPayout
sudo chmod 700 /var/log/AlloPayout

sudo mkdir /etc/AlloPayout
sudo chown allopayout:allopayout /etc/AlloPayout
sudo chmod 700 /etc/AlloPayout
```

## Local instance copy

Next exit out of the ssh session so you can run scp to copy the files from
the local machine over to the remote server, due to permissions you might need
to copy somewhere else (your home dir) and move if you get a copy access error.

```sh
scp ../credentials.json myssh:/etc/AlloPayout # assume exists 1 dir above repo
scp ./build/libs/AlloPayout.jar myssh:/srv/AlloPayout/app.jar
```

## Finalize Remote Server

Again ssh to access the remote VPS server (tested on debian) directly.

```sh
sudo chmod 644 /srv/AlloPayout/app.jar
sudo chown root:root /srv/AlloPayout/app.jar

sudo chmod 400 /etc/AlloPayout/credentials.json
sudo chown allopayout:allopayout /etc/AlloPayout/credentials.json
```

Create the /etc/cron.weekly/AlloPayout file with the following contents:

```sh
#!/bin/sh

filedate=$(/usr/bin/date +%Y%m%d)
exec /usr/sbin/runuser -u allopayout -- /usr/bin/java -jar /srv/AlloPayout/app.jar \
    1>> /var/log/AlloPayout/AlloPayout_${filedate}.log \
    2>&1
```

Next set permissions on the file:

```sh
sudo chmod 755 /etc/cron.weekly/AlloPayout
```

