#!/bin/bash
#
# Take single or series of screenshots
#
# 02-Dec-2013  Marko Kallinki  Take screenshot
#

ME="`basename $0`"

USAGEVERBOSE="\

Take single or series of screenshots

Usage:
$ME -1             - Take a single screenshot
$ME -s             - Take several shots, manual steps
$ME -d             - Target: hw device (optional)
$ME -e             - Target: emulator (optional)
$ME -h             - This information
"

CAPTUREFOLDER="$HOME/capture"
DEVICEFOLDER="/data/media"
ANIMATION="animation.gif"


#
# Process arguments.
#
if [ $# -eq 0 ]; then
  echo "$USAGEVERBOSE"
  exit 0
fi

target=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      echo "$USAGEVERBOSE"
      exit 0;;
    -d | --device)
      target="-d"
      shift;;
    -e | --emulator)
      target="-e"
      shift;;
    -1 | --one)
      mode=single
      shift;;
    -s | --step)
      mode=step
      shift;;
    -t | --test)
      test=true
      shift;;
    -v | --video)
      mode=video
      time=$2
      shift;;
    *)
      echo "$USAGEVERBOSE"
      exit 0;;
  esac
done

# adb ready?
check=(`which adb | wc -l`)
if [[ $check -eq 0 ]]; then
  echo "Error: Can't locate adb"
  echo "Setup your enviroment first!"
  exit
fi

# Device or emulator?
if ! [[ $test = true ]]; then
  check=(`adb devices -l | grep model: | wc -l`)
  if [[ $check -eq 0 ]]; then
    echo "Error: No any devices found!"
    exit
  else
    if [[ $target = "" ]] && [[ $check -gt 1 ]]; then
      echo "Both emulator and usb-device detected. Using -d switch"
      echo "Use -e switch for exliciply target for emulator"
      echo
      target="-d"
    fi
  fi
fi

# Make sure we have proper folder and it is empty
if [ ! -d $CAPTUREFOLDER ]; then
  mkdir $CAPTUREFOLDER
else
  rm -f $CAPTUREFOLDER/*.png
  rm -f $CAPTUREFOLDER/$ANIMATION
fi

# Take single screenshot
if [[ $mode = single ]]; then

  adb $target root
  adb $target shell mount -o rw,remount /system

  echo "Taking screenshot..."

  adb $target shell system/bin/screencap -p $DEVICEFOLDER/screen.png
  adb $target pull $DEVICEFOLDER/screen.png
  adb $target shell rm $DEVICEFOLDER/screen.png
  mv screen.png $CAPTUREFOLDER/screen.png
  eog $CAPTUREFOLDER/screen.png &
  echo "Saved: $CAPTUREFOLDER/screen.png"
  exit

fi

# Multi capture modes
if [[ $mode = step ]]; then

  # Check that we have imagemagick installed
  check=(`which convert | wc -l`)
  if [[ $check -eq 0 ]]; then
    echo "Error: Can't find image convertter, so let's install it!"
    sudo apt-get install imagemagick
    echo "Please retry again!"
    exit
  fi

  id=0
  if [[ $mode = video ]]; then
    echo "Press any key to start \"video\" capturing."
    read -n 1 key
  else
    echo "Press space to take a picture, any other key to end."
  fi

  while true; do

    id=$(($id + 1))
    if [[ $mode = step ]]; then

      read -n 1 key
      if ! [[ $key = '' ]]; then
        break
      fi

      echo "Screenshot $id"

    else # video

      if [[ $id -gt 20 ]]; then
        break
      fi

    fi

    adb $target shell system/bin/screencap -p $DEVICEFOLDER/screen$id.png

  done

  echo
  echo "Capturing ended, copying screenshots from target"
  fname=""

  for i in $(seq 1 $(($id - 1))); do

    adb $target pull $DEVICEFOLDER/screen$i.png;
    adb $target shell rm $DEVICEFOLDER/screen$i.png
    fname=$CAPTUREFOLDER/screen$i.png
    mv screen$i.png $fname

  done

  # make one last grayscale screen
  cd $CAPTUREFOLDER
  convert -type Grayscale -colors 16 $fname screenlast.png

  echo "Converting into animation..."
  if [[ $mode = video ]]; then
    interval=50
    cp screenlast.png screenlast1.png
    cp screenlast.png screenlast2.png
    cp screenlast.png screenlast3.png
    cp screenlast.png screenlast4.png
  else
    interval=300
  fi

  # make gif animation
  convert -set delay $interval *.png $ANIMATION
  eog $CAPTUREFOLDER/$ANIMATION &

  echo "Saved as: $CAPTUREFOLDER/$ANIMATION"
  exit

fi

# Video
if [[ $mode = video ]]; then

  adb $target root
  adb $target shell mount -o rw,remount /system



  # TODO: update avconv
  check=(`which ffmpeg | wc -l`)
  if [[ $check -eq 0 ]]; then
    echo "Error: Can't find ffmpeg, so let's install it!"
    sudo apt-get install libav-tools
    echo "Please retry again!"
    exit
  fi

  adb $target root
  adb $target shell mount -o rw,remount /system

  # Download video file
  echo "Recording video... NOW!"
  if ! [[ $test = true ]]; then

    echo "Started recording 20sec!"
    # FIXME: segmentaion fault :(
    adb $target shell /system/bin/recordvideo 
#-o /$DEVICEFOLDER/output.mp4
    echo "Recording stopped!"
    echo "Downloading video file..."
#    adb $target pull $DEVICEFOLDER/output.mp4
    adb $target pull /sdcard/output.mp4

    adb $target shell rm $DEVICEFOLDER/output.mp4
    fname=$CAPTUREFOLDER/output.mp4
    mv output.mp4 $fname

  fi

  # Extracts each frame of the video as a single gif
  echo "Extracting video frames..."
  ffmpeg -i output.mp4 out%04d.gif >/dev/null 2>&1

  # Combines all the frames into one very nicely animated gif.
  echo "Combining into animation..."
  convert -delay 4 out*.gif blob.gif >/dev/null 2>&1

  # Optimizes the gif using imagemagick
  echo "Compressing animation..."
  convert -layers Optimize blob.gif animation.gif >/dev/null 2>&1

  #Cleans up the leftovers
  rm out*.gif
  echo "Done"

  #rm anim.gif

fi


