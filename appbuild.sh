#!/bin/bash
#
# Rebuild app and push to emulator/device
#
# 15-Nov-2013  Marko Kallinki  Handle hardware sync
# 06-Nov-2013  Marko Kallinki  Added processor count
# 05-Nov-2013  Marko Kallinki  Initial version
#

ME="`basename $0`"

echo "Application build & sync script"

check=(`which java`)
if [[ $check = /usr/bin/java ]]; then

  echo "Checking Java environment: $checkjava"
  echo -e '\e[00;31mWrong Java version! Make sure you are in "build shell"\e[00m'
  exit 1

fi

check=(`which adb | wc -l`)
if [[ $check -eq 0 ]]; then

  echo -e '\e[00;31mError: Cant find adb. Make sure you have set up the enviroment\e[00m'
  echo "e.g."
  echo "source device/aosp/envsetup_ubuntu.sh;"
  echo "source build/envsetup.sh;"
  echo "lunch aosp_emu-eng"
  exit 1

fi

echo "Product build:" $TARGET_PRODUCT

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
    else
      target='-e'
    fi
  else
    echo -e '\e[00;31mUnknown target. Use -e for emulator (pc) or -d for device (hw)"\e[00m'
    exit 1
  fi

fi

if [[ $target = "-d" ]]; then
  echo "Product target: Phone (hw)"
else
  echo "Product target: Emulator (pc)"
fi


# Load mm build function
source $ANDROID_BUILD_TOP/build/envsetup.sh

# "optimal" processor count :P
pc=(`cat /proc/cpuinfo | grep processor | wc -l`)
pc=$((($pc + 2) / 2))

# Target precheck for end user
checkemulator=(`adb $target get-state`)
if [[ $checkemulator = unknown ]]; then

  if [[ $target = "-d" ]]; then
    echo -e '\e[00;31mWarning: No phone found, recheck your USB connection!\e[00m'
  else
    echo -e '\e[00;31mWarning: No emulator found, restart emulator!\e[00m'
  fi
    
  echo "Press enter to continue for building (or Ctrl-C to cancel)"
  read line
  echo "Building started..."

fi

# Build application
starttime=$(date +%s)
mm > >(tee $HOME/.build.log) 2>&1

# Check build log for errors
check=(`grep -E ' error|Error ' $HOME/.build.log | wc -l`)
if [[ $check -gt 0 ]]; then

  echo -e '\e[00;31mError: Build errors found\e[00m'
  echo "see $HOME/.build.log for details"
  exit 1

fi

# Check if we have target or not
check=(`adb $target get-state`)
if [[ $check = unknown ]]; then
  
  # Emulator is not running, remake system image
  cd $ANDROID_BUILD_TOP
  make snod -j$pc

  echo
  echo "Application and system image rebuilt"

else

  # Check if phone (hw) is ready for uploading
  check=(`adb $target remount`)
  if [[ ${check[1]} = *failed* ]]; then

    echo "Re-rooting phone"
    adb $target root
    sleep 1

    check=(`adb $target get-state`)
    if [[ $check = unknown ]]; then

      # In virtual Ubuntu, USB connection is lost when phone mode changes
      echo -e "\e[00;31mAfter re-rooting, no phone connected to USB. Recheck connection.\e[00m"

      while true; do

        sleep 0.5
        check=(`adb $target get-state`)
        if ! [[ $check = unknown ]]; then
          adb $target remount
          break
        fi

      done

    fi
  fi

  # Phone is running, update live
  adb $target sync

  echo
  echo "Application uploaded"

fi

echo "Operations took $(($(date +%s) - $starttime)) second(s)"


