#!/bin/bash
#
# Rebuild app and push to emulator
#
# 05-Nov-2013  Marko Kallinki  Initial version
#

ME="`basename $0`"

checkjava=(`which java`)

if [ $checkjava = /usr/bin/java ]; then

  echo "Checking Java environment: $checkjava"
  echo -e '\e[00;31mWrong Java version! Make sure you are in "build shell"\e[00m'

else

  #
  # Load mm build function
  #
  source $ANDROID_BUILD_TOP/build/envsetup.sh

  checkemulator=(`adb get-state`)

  if [ $checkemulator = unknown ]; then
  
    #
    # Emulator is not running, remake system image
    #
    mm
    cd $ANDROID_BUILD_TOP
    make snod
    echo
    echo "$ME : Application rebuild, start emulator"

  else

    #
    # Emulator is running, update live
    #
    mm
    adb remount
    adb sync
    echo
    echo "$ME : Application uploaded into emulator"

    #make snod > /dev/null 2>&1 # silent build

  fi

fi


