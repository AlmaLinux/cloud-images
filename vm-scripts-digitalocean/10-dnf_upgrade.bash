#!/usr/bin/env bash

# upgrade silently
dnf -qy distro-sync
dnf -qy clean all

