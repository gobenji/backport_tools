#!/bin/bash

master=${1:-"HEAD"}
bznum=$(git branch | grep "^* " | awk '{print $2}')

set -x
git branch master.${bznum} ${master} -f
