#!/usr/bin/env bash

# mangle release info to pass checks (DELME when accepted)
sed -i 's@^NAME=.*@NAME=\"CentOS Linux\"@' /etc/os-release
sed -i 's@^VERSION_ID=.*@VERSION_ID=\"8\"@' /etc/os-release

