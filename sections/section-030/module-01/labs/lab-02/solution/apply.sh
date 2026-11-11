#!/usr/bin/env bash
set -euo pipefail

sudo nft 'add rule inet training input iifname "lab-untrusted" tcp dport 8080 reject with tcp reset'
