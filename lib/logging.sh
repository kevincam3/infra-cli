#!/usr/bin/env bash

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

info()    { echo -e "${BLUE}ℹ${RESET} $1"; }
success() { echo -e "${GREEN}✔${RESET} $1"; }
error()   { echo -e "${RED}✖${RESET} $1" >&2; }
warn()    { echo -e "${YELLOW}⚠${RESET} $1"; }

section() {
  echo
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BLUE}$1${RESET}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}
