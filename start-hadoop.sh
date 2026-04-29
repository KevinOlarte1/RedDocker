#!/bin/bash

/entrypoint.sh /run.sh &

sleep 10

yarn --daemon start resourcemanager
yarn --daemon start nodemanager

tail -f /dev/null
