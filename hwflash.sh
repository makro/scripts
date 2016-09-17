#!/bin/bash
#
# Flash your R&D build into HW
#
# 05-Dec-2013  Marko Kallinki  Check usb writing rights
# 12-Nov-2013  Marko Kallinki  Handle alternative OUT
# 11-Nov-2013  Marko Kallinki  Initial version
#

echo "HW flashing script"

buildlog="$HOME/build.log"

if ! [[ $ANDROID_BUILD_TOP ]]; then
  echo -e "\e[00;31mError: You need to be at build shell!\e[00m"
  exit 1
fi

systemfile=(`find $ANDROID_PRODUCT_OUT -name "system.img" | wc -l`)
if [[ $systemfile -eq 0 ]]; then
  echo -e "\e[00;31mError: Can't find build files! (e.g. system.img)\e[00m"
  echo $ANDROID_PRODUCT_OUT
  exit 1
fi

devices=(`adb devices | grep "no permissions" | wc -l`)
if [[ $devices -gt 0 ]]; then
  echo -e "\e[00;31mError: No permissions. Reboot phone by pressing volume down down, and reconnect usb...\e[00m"
  exit 1
fi

devices=(`adb devices -l | grep "device usb" | wc -l`)
if [[ $devices -eq 0 ]]; then
  flashdevices=(`fastboot devices | wc -l`)
  if [[ $flashdevices -eq 0 ]]; then
    echo -e "\e[00;31mError: No suitable devices found to be flashed!\e[00m"
    adb devices
    exit 1
  fi
fi

echo "Target build: $TARGET_PRODUCT from $OUT_DIR_COMMON_BASE"
if [[ $TARGET_PRODUCT == *emu* ]]; then
  echo -e "\e[00;31mError: You can't flash emulator build into hardware!\e[00m"
  exit 1
fi

if ! [[ $TARGET_PRODUCT == *ara* ]]; then
  if ! [[ $1 == "--sure" ]]; then
    echo -e "\e[00;31mError: Not sure if this is suitable build for hardware. Use --sure flag to verify it.\e[00m"
    exit 1
  fi
fi

echo "Prepare phone for flashing... (should take only few seconds)"

# Prepare phone
flashdevices=(`fastboot devices | wc -l`)
if [[ $flashdevices -eq 0 ]]; then
  adb -d reboot-bootloader
  sleep 2
  # TODO: Check if reboot lingers
  echo "Phone swicthed to flash mode"
fi

# Verify phone
flashdevices=(`fastboot devices | wc -l`)
if [[ $flashdevices -eq 0 ]]; then

  # In virtual Ubuntu, USB connection is lost when phone mode changes
  echo -e "\e[00;31mWarning: No phone connected to USB. Recheck connection.\e[00m"

  while true; do

    sleep 0.4
    flashdevices=(`fastboot devices | wc -l`)
    if [[ $flashdevices -gt 0 ]]; then
      echo "Hardware ready for flashing"
      break
    fi

  done

fi

flashdevices=(`fastboot devices | grep permission | wc -l`)
if [[ $flashdevices -gt 0 ]]; then

  echo -e "\n\e[00;31mError: No user rights to write to USB.\e[00m"
  echo "Check that you have usb rights in: /etc/udev/rules.d/51-android.rules"
  echo "(If file not found, create it as a root)"
  echo "Check following line:"
  echo
  echo '# fastboot protocol'
  echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="xxxx", ATTR{idProduct}=="xxxx", MODE="0666"'
  echo
  echo 'Check device values (xxxx) from following list (lsusb):'

  lsusb
  echo

  fastboot reboot
  exit 1

fi

#
# Actual flashing operation
#
ARAFLASHING=$ANDROID_BUILD_TOP/device/aosp/common/tools/flash_scripts/Ara_flash_device.sh
cd $ANDROID_BUILD_TOP/device/aosp/common/tools/flash_scripts/

starttime=$(date +%s)


# Hide normal output, and show %-one-liner
advanced=true
if [[ $advanced = true ]]; then

    echo "Flashing target $TARGET_PRODUCT" > $buildlog

    lines=0
    while read line; do

      if [[ $line == *flash* ]]; then
        lines=$(($lines + 1))
      fi

    done < $ARAFLASHING

    echo -e "\e[00;31mFlashing hardware...\e[00m"

    lcount=0
    while read line; do

      if [[ $line = */* ]]; then
        file="("${line##*/}")"
      else
        file=""
      fi

      if [[ $line == *flash* ]]; then
        tput cuu 1
        echo $(($lcount*100/$lines))"% $file                    "
        lcount=$(($lcount + 1))
      fi

      # Process flashing steps and store stdout and strerr into build.log
      eval $line &>>$buildlog

    done < $ARAFLASHING

else

  # Plain Ara_flash_device.sh flashing
  $ARAFLASHING

fi

tput cuu 1
echo "100%                                          "
echo
echo "Flashing ready!"
echo "Flashing took $(($(date +%s) - $starttime)) second(s)"
echo "See $buildlog for details"
echo


