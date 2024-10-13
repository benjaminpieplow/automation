#!/bin/bash
# Author: Benjamin Rohner
# Date: 2024
# Desc: Installs ansible, with common Python dependencies

sudo apt update
sudo apt upgrade
sudo apt install -y pipx python3-pip
pipx install --include-deps ansible
pip install proxmoxer
