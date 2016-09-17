#!/bin/bash
#
# Copy emulator code into hardware build area
#
# 12-Dec-2013  Marko Kallinki  Copy also overlay files
# 18-Nov-2013  Marko Kallinki  Fix root folder handling
# 14-Nov-2013  Marko Kallinki  Code refactored (user query)
# 12-Nov-2013  Marko Kallinki  Initial version (hardcoded)
#

OVERLAYPATH="/device/aosp/ara/overlay"

ME="`basename $0`"

USAGEVERBOSE="\

Script to keep emulator and hw build areas in sync

${ME} -r        - Clear all and sync .repo from other build area (slow!)
${ME} -a        - Sync current application files from other build area
"
# ${ME} -f <dir>  - Source build area. If not given, will be asked.

echo "Repository copy script"
currentdir=$PWD
rootdir=$PWD

#
# Process parameter
#
if [ $# -eq 0 ]; then
  echo "$USAGEVERBOSE"
  exit 0
fi

if [[ $1 = "-h" || $1 = "--help" ]]; then
  echo "$USAGEVERBOSE"
  exit 0
fi

if [ $1 = "-help" ]; then
  echo "Phfff. Either use -h or --help, not -help!"
  exit 1
fi

if [[ $1 == "-a" ]]; then
  if ! [[ $ANDROID_BUILD_TOP ]]; then
    echo -e "\e[00;31mError: You need to be at build shell!\e[00m"
    exit 1
  fi
fi

if [[ $currentdir = *$OVERLAYPATH* ]]; then
  echo -e "\e[00;31mError: You are under overlay. Run this at application directory!\e[00m"
  exit
fi


#
#  Get other project path
#
if ! [[ $sourcerepo ]]; then

  if [[ $ANDROID_BUILD_TOP ]]; then
    cd $ANDROID_BUILD_TOP
  fi

  echo
  echo -e "\e[00;31mBuild area to be overwritten: $rootdir\e[00m"
  echo
  echo "Choose the 'emulator' build area to sync from:"
  echo "(If none is correct, exit and use -r <dir> to give proper one)"

  cd ..
  folders=(`ls -d */`)

  num=0
  for f in ${folders[*]}; do
    num=$(($num + 1))
    echo "  $num  $PWD/$f"
  done

  limit=${#folders[*]}
  selection=100
  while [[ $selection -gt $limit ]]; do
    echo "Choose 1 - $limit (0 to quit)"
    read selection
  done

  if [[ $selection -eq 0 ]]; then
    echo "End user quit."
    exit 0
  fi

  selection=$(($selection - 1))
  sourcerepo=$PWD/${folders[$selection]}
  sourcerepo=${sourcerepo%*/}
  cd $currentdir

fi

#
#  Timer for background processes
#  Uses global $timer
#
function waittimer {
  bgid=$1
  active=1
  while [[ $active -gt 0 ]]; do
    active=(`ps | grep $bgid | wc -l`)
    timer=$(($timer + 1))
    tput cuu 1
    echo -e "\e[00;32m$timer seconds elapsed\e[00m    "
    sleep 1
  done
}

#
#  Repo clean and sync
#
if [[ $1 == "-r" ]]; then

  starttime=$(date +%s)
  cd $rootdir

  echo -e "\nSyncing repository operation started. Will take quite some time!"
  echo -e "\e[00;32mStep 1: Cleaning current workarea before sync...\e[00m\n"
  if [[ -d .repo ]]; then
    repo forall -c 'git reset --hard HEAD' 2>&1 1>/dev/null &
    waittimer $!
  fi

  tput cuu 1
  echo -e "\e[00;32mStep 2: Deleting old repository...\e[00m\n"
  rm -Rf .repo 2>&1 1>/dev/null &
  waittimer $!

  tput cuu 1
  echo -e "\e[00;32mStep 3: Copying new repository...\e[00m\n"
  cp -r $sourcerepo/.repo $rootdir 2>&1 1>/dev/null &
  waittimer $!

  tput cuu 1
  echo -e "\e[00;32mStep 4: Updating build area files...\e[00m"
  repo sync -l 
  #2>&1 1>/dev/null &
  #waittimer $!

  elapsed=$(($(date +%s) - $starttime))
  tput cuu 2
  echo "                                          "
  echo -e "\nRepositoy sync from $sourcerepo made."
  echo -e "\e[00;32mSync ended $(date +%T) and took $(($elapsed/60)) minutes $(($elapsed%60)) seconds\e[00m"
  echo

fi

#
#  Copy files from 'emulator' application folder
#
if [[ $1 == "-a" ]]; then

  #
  #  Folder tirckery
  #
  appdir1=${PWD##*/}
  appdir2=${PWD##*/}
  cd ..
  relativedir=${PWD#*$ANDROID_BUILD_TOP}/
  rootdir=$ANDROID_BUILD_TOP

  # Ugly exception for root .
  if [[ "$relativedir$appdir1" = "/$rootdir" ]]; then
    appdir1=""
    relativedir=""
  fi

  targetdir="${sourcerepo}${relativedir}$appdir1"

  echo -e "\nCloning emulator '$appdir2' code to hw build area..."
  check=(`find $targetdir | wc -l`)
  echo -e "Checking changes from $check files (+ overlay)\n"

  if [[ $check -gt 300000 ]]; then
    echo -e "\e[00;31mWarning: Will take quite a lot - are you sure [y/n] ?\e[00m"
    read answer
    if ! [[ $answer = Y* || $answer = y* ]]; then
      echo "End user calcelled."
      exit
    fi
  fi

  cd $currentdir
  cd ..
  #echo -e "Now: $PWD\ncp -ur $targetdir/* $appdir2\n"
  cp -ur $targetdir/* $appdir2 2>&1 1>/dev/null &
  waittimer $!

  targetdir="${sourcerepo}$OVERLAYPATH${relativedir}$appdir1"
  if [ -d $targetdir ]; then

      cd $rootdir$OVERLAYPATH${relativedir}
      #echo -e "Now: $PWD\ncp -ur $targetdir/* $appdir2\n"
      cp -ur $targetdir/* $appdir2 2>&1 1>/dev/null &
      waittimer $!

  fi

  tput cuu 1
  echo "Ready                                  "
  echo

fi


