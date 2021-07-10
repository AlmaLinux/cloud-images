#!/usr/bin/env bash

# remove root password and lock it
passwd -d root
passwd -l root

