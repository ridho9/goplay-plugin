#!/usr/bin/env bash

git push origin master

ssh root@gp.ridho.dev /bin/bash << EOF
    cd goplay-plugin
    git checkout master
    git pull
    docker-compose up -d --build
EOF