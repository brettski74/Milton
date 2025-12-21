#!/bin/env bash

CMD=''

function check_for {
  CMD="$1"
  shift

  echo -n "Checking for $CMD... "
  if which "$CMD"; then
    if [ -n "$1" ]; then
      "$@"
    fi
    CMD=''
  else
    echo "Not found"
    return 1
  fi
}

function install_needed {
message=<<EOS
You need to install $1. Try running the commands:

EOS

check_for apt echo <<EOS
$message
    sudo apt update
    sudo apt install $1

EOS

check_for pacman echo <<EOS
$message
    sudo pacman -Syy $1

EOS

check_for dnf echo <<EOS
$message
    sudo dnf install $1

EOS

check_for emerge echo <<EOS
$message
    sudo emerge $2

EOS

check_for zypper echo <<EOS
$message
    sudo zypper refresh
    sudo zypper install $1

EOS

check_for apk echo <<EOS
$message
    sudo apk add $1

EOS
}

check_for make check_for perl perl milton-setup.pl

if [ "$CMD" == "perl" ]; then
  install_needed perl dev-lang/perl
elif [ "$CMD" == "make" ]; then
  install_needed make dev-build/make
fi

