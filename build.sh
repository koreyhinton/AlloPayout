#!/bin/bash

orc=$(realpath ../orc/lib/src/main/bash/com/koreyhinton/nsmap)
export NSMAP="$orc"

cd ./src/main/java/com/koreyhinton/
./AlloPayout.sh \
    > ./AlloPayout.java && cd - && ./gradlew bootJar


# scp copying will need to drop the jar when it goes to /etc/cron.weekly/AlloPayout, and add +x permission


