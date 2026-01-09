#!/bin/env bash

CMD=''
if [ -n "$MILTON_INSTALL_SH_EXECUTED" ]; then
  cat <<EOS >&2
Possible infinite recursion detected between install.sh and milton-setup!!!

What does this mean? Most likely, you have executed either install.sh or milton-setup
in a way that was not anticipated during their development.

To install from a git clone of the source code, you should run install.sh from the
base directory of your git clone - ie. the directory where install.sh is located.
EOS

  exit 1
fi
export MILTON_INSTALL_SH_EXECUTED=1

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
    sudo pacman -Sy $1

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

cat <<EOS
################################################################################
################################################################################
################################################################################
Installing a shared instance may require sudo access and prompt for your
password once or more during setup.

Install a shared instance (Y/N)?
EOS
unset choice
typeset -u choice
read choice
while [ "$choice" != "Y" -a "$choice" != "N" ]; do
  echo "Invalid choice. Please answer Y or N."
  read choice
done

if [ "$choice" == "Y" ]; then
  MILTON_BASE=/opt/milton
  cp -v config.mk.global config.mk
elif [ "$choice" == "N" ]; then
  MILTON_BASE=$HOME/.local/milton
  cp -v config.mk.local config.mk
fi
export MILTON_BASE

export PERL5LIB=$PWD/src:$PERL5LIB
check_for make check_for perl perl src/milton-setup.pl

if [ "$CMD" == "perl" ]; then
  install_needed perl dev-lang/perl
elif [ "$CMD" == "make" ]; then
  install_needed make dev-build/make
fi

