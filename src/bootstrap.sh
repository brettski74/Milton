#!/bin/env bash

function check_for {
  typeset cmd="$1"
  shift

  echo -n "Checking for $cmd... "
  if which "$cmd"; then
    if [ -n "$1" ]; then
      "$@"
    fi
    exit 0
  else
    echo "Not found"
    return 1
  fi
}

check_for perl perl src/milton_setup.pl
message=<<EOS
You need to install perl. Try running the commands:

EOS

check_for apt echo <<EOS
$message
    sudo apt update
    sudo apt install perl

EOS

check_for pacman echo <<EOS
$message
    sudo pacman -Syy perl

EOS

check_for dnf echo <<EOS
$message
    sudo dnf install perl

EOS

check_for emerge echo <<EOS
$message
    sudo emerge dev-lang/perl

EOS

check_for zypper echo <<EOS
$message
    sudo zypper refresh
    sudo zypper install perl

EOS

check_for apk echo <<EOS
$message
    sudo apk add perl

EOS
