#!/bin/bash

master=${1:-"HEAD"}
bznum=$(git branch | grep "^* " | awk '{print $2}')

set -x
git reset --hard master.${bznum}
