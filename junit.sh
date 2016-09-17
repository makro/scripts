#!/bin/bash
#
# Build and launch junit tests for current application
#
# 12-Dec-2013  Marko Kallinki  Refactored code +r +e
# 05-Dec-2013  Marko Kallinki  Build dependecies too
# 15-Nov-2013  Marko Kallinki  Handle hardware sync 
# 28-Oct-2013  Marko Kallinki  Initial version
#

ME="`basename $0`"

USAGEVERBOSE="\
Usage:
$ME           - Builds unittests and syncs with device
$ME x         - Runs test case number x
$ME -d        - Build and sync with dependencies
$ME -r        - Restart adb shell (helps sometimes)
$ME -l        - Only lists unittests in device
$ME -e        - Erase all unittests from device
$ME -h        - Shows this information
"

echo "JUnit launch script"

if ! [[ $ANDROID_BUILD_TOP ]]; then
  echo -e "\e[00;31mError: You need to be at build shell!\e[00m"
  exit 1
fi

#  
# Check target
# FIXME: Might use more reliable lunch variables too
#

if [[ $TARGET_PRODUCT = *ara* ]]; then
  target='-d'
fi

if [[ $TARGET_PRODUCT = *emu* ]]; then
  target='-e'
fi

if ! [[ $target ]]; then

  if [[ $# -gt 0 ]]; then
    if [[ $1 = '-d' ]]; then
      target='-d'
      shift
    fi
    if [[ $1 = '-e' ]]; then
      target='-e'
      shift
    fi
  else
    echo -e '\e[00;31mUnknown target!\e[00m'
    echo 'Use -e for emulator (pc) or -d for device (hw) as first parameter'
    exit 1
  fi

fi

if [[ $target = "-d" ]]; then
  echo "Test target: Phone (hw)"
else
  echo "Test target: Emulator (pc)"
fi

#
#  Process arguments.
#
mmcommand='mm'
mode='build'

while [ $# -gt 0 ]; do
  case "$1" in

    -h | --help)
      echo "$USAGEVERBOSE"
      exit 0 ;;

    -d | --dependencies)
      mmcommand='mma'
      shift ;;

    -e | --eraseall)
      mode='erase'
      shift ;;

    -l | --list)
      mode='list'
      shift ;;

    -r | --restart)
      restart=true
      shift ;;

    *)
      if [ "$1" -eq "$1" ] 2>/dev/null; then
        mode='run'
        runtest=$1
      fi
      shift ;;

  esac
done


#
#  Check that emulator is running
#
state=(`adb $target get-state`)
if [ $state = unknown ]; then
  echo -e "\e[00;31mError: No target phone to run tests!\e[00m"
  exit 0;
fi

#
#  Erase all tests
#
if [[ $mode = 'erase' ]]; then

  search='data/app/*Test*.apk'
  testlist=(`adb $target shell ls $search`)

  if ! [[ ${testlist[1]} = No ]]; then

    adb $target root
    adb $target shell mount -o rw,remount /system

    for t in "${testlist[@]}"; do

      # fix shell ls formatting issue
      nt=${t%.apk*}.apk
      echo "Erasing:" ${nt##*/}
      adb $target shell rm $nt

    done
  fi

  echo "Ready"
  exit 0

fi

#
#  Load functions, like mm()
#
source $ANDROID_BUILD_TOP/build/envsetup.sh

if [[ $mode = 'build' ]]; then

  starttime=$(date +%s)

  # Rebuild (application and) tests
  # mm to build, mma + dependecies
  $mmcommand -B > >(tee $HOME/.build.log) 2>&1

  echo -e "\e[00;32mBuild lasted $(($(date +%s) - $starttime)) second(s)\e[00m"

  # Check build log for errors
  check=(`grep -E ' error|Error ' $HOME/.build.log | wc -l`)
  if [ $check -gt 0 ]; then

    echo -e '\e[00;31mError: Build errors found\e[00m'
    echo "see $HOME/.build.log for details"
    exit 1

  fi

  # Upload files into target
  adb $target root
  adb $target shell mount -o rw,remount /system
  adb $target sync

  if [[ $restart ]]; then

    echo "Restarting adb shell..."
    adb $target shell stop
    adb $target shell start
    sleep 10 # take it easy

  fi

  sleep 2 # Safety timeout

fi

#
#  List test in device
#
showlist=true
testlist=(`adb $target shell pm list instrumentation`)
INST_PREFIX="instrumentation:*"

#
# Search unittest and run
#
if [[ $mode = 'run' ]]; then

  index=0
  for t in "${testlist[@]}"; do

    if [[ $t = $INST_PREFIX ]]; then

      index=$(($index + 1))
      unittest=${t#*$INST_PREFIX}

      if [ $runtest == $index ]; then

        echo "Running test case $index:"
        echo $unittest
        adb $target shell am instrument -w $unittest
        showlist=false

      fi
    fi

  done

fi


#
#  List test cases
#
if [ $showlist = true ]; then

  if [[ $runtest ]]; then
    echo "Error: Can't find test case $runtest"
  fi
  echo "-------------------------------------------------"
  
  index=0
  for t in "${testlist[@]}"; do

    if [[ $t = $INST_PREFIX ]]; then

      index=$(($index + 1))
      unittest=${t#*$INST_PREFIX}
      echo "  $index  $unittest"

    fi
  done

  if [[ $index = 0 ]]; then
    echo "No junit test found"
  fi

  echo "-------------------------------------------------"
  echo "Run '${ME} <number>' to run certain unittest"

fi



