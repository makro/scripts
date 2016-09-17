#!/bin/bash
#
# Convert path between application and custom overlays
#
# 12-Dec-2013  Marko Kallinki  Sanity checks added
# 11-Dec-2013  Marko Kallinki  Intial version  
#

OVERLAYPATH="/device/aosp/ara/overlay"

ME="`basename $0`"

USAGEVERBOSE="\

Script to toggle between real and custom overlay folders.

${ME} -c (tool)   - Compare what has been overwritten
${ME} -p          - Prints the overlay folder (for alias)
${ME} -h          - This information

Recommended to create following alias for \"cd overlay\":
alias cdov='cd \`overlay.sh -p\`'
"

if ! [[ $ANDROID_BUILD_TOP ]]; then
  echo -e "\e[00;31mError: You need to be at build shell!\e[00m"
  exit 1
fi

#
# Process arguments.
#

mode='help'
while [ $# -gt 0 ]; do
  case "$1" in

    -h | --help)
      mode='help'
      shift;;

    -c | --compare)
      tool=$2
      mode='compare'
      shift;;

    -p | --print)
      mode='printdir'
      shift;;

    # hidden features;
    -r | --root)
      # jump to root and back; cdr, cd -
      # alias cdr='cd `overlay.sh -r`'
      echo $ANDROID_BUILD_TOP
      exit 0;;

    -o | --overlayroot)
      # jump to overlay root
      # alias cdor='cd \`overlay.sh -o\`'
      echo $ANDROID_BUILD_TOP$OVERLAYPATH
      exit 0;;

    *)
      shift;;
  esac
done

if [[ $mode = 'help' ]]; then

  echo "$USAGEVERBOSE"
  exit 0

fi

#
# Get the "other" folder
#

if ! [[ $PWD = *$ANDROID_BUILD_TOP* ]]; then

  echo -e "\e[00;31mError: You need to be inside project hierarchy\e[00m" 1>&2
  echo $PWD
  exit 1

fi

relativedir=${PWD#*$ANDROID_BUILD_TOP}/

if [[ $relativedir = *$OVERLAYPATH* ]]; then

  relativedir=${PWD#*$OVERLAYPATH}/
  folder="$ANDROID_BUILD_TOP$relativedir"

else

  folder="$ANDROID_BUILD_TOP$OVERLAYPATH$relativedir"

fi

if ! [ -d $folder ]; then
  echo -e "\e[00;31mError: There is no overlay counterpart for this folder!\e[00m" 1>&2
  echo $PWD
  exit 1
fi

#
# Process mode
#

case "$mode" in

  'compare')

    echo "Compare directories:" $relativedir

    check=(`which $tool | wc -l`)    
    if ! [ $check -eq 1 ]; then

      check=(`which bcompare | wc -l`)
      if [ $check -gt 0 ]; then
        tool=bcompare
      else
        tool=diff
      fi

    fi

    $tool $folder $PWD & ;;

  'printdir')

    echo $folder ;;

  *)

    echo "$USAGEVERBOSE" ;;

esac


