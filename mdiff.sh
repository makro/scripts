#!/bin/bash
#
# This script opens multifolder compare for given tool and given roots
#
# 23-Oct-2013  Marko Kallinki  Initial version
#

ME="`basename $0`"

USAGE="Usage: ${ME} --tool tool --roots path1 path2 path3 [--file file|--serious|--help]"

USAGEVERBOSE="\

This script compares 3 parallel folder and/or file content which share same relative folder structure from root up. Recommended to use via alias like this:

alias mdiff='/\$HOME/bin/${ME} kdiff3 -r path/repo1 path/repo2 path/repo3'
"

#
# Process arguments.
#
while [ $# -gt 0 ]; do
  case "$1" in
    #
    # Help.
    #
    -h | --help)
      shift; echo "$USAGE"; echo "$USAGEVERBOSE"; exit 0 ;;

    -d | --debug)
      shift; set -x ;;

    #
    # Tool
    #
    -t | --tool)
      shift;
      TOOL=$1
      shift;;

    #
    # List of roots (expecting 3)
    #
    -r | --roots)
      shift;
      ROOT1=$1;
      shift;
      ROOT2=$1;
      shift;
      ROOT3=$1;
      shift;;

    #
    # Individual file
    #
    -f | --file)
      shift;
      FILE=$1
      shift;;

    #
    # Root folder too slow, must be serious
    #
    -s | --serious)
        shift;
        SERIOUS=true;;

    *)
      break;;
  esac
done

#
# Main
#
if [[ $ROOT1 ]]; then

  if [ $PWD == $ROOT1 -o $PWD == $ROOT2 -o $PWD == $ROOT3 -o \
       $PWD == /$ROOT1 -o $PWD == /$ROOT2 -o $PWD == /$ROOT3 ]; then

    echo "Running ${ME} for repository roots"

    if [[ $SERIOUS ]]; then

      $TOOL $ROOT1/ $ROOT2/ $ROOT3/ &

    else

      echo
      echo "Warning: This is very very slow operation."
      echo "Suggesting comparing deepest subfolder structures mainly."
      echo "add -s parameter to confirm you are serious with root compare."
      echo

    fi

  else

    FOLDER=${PWD#*$ROOT1}

    if [ $FOLDER == $PWD ]; then

      FOLDER=${PWD#*$ROOT2}

      if [ $FOLDER == $PWD ]; then

        FOLDER=${PWD#*$ROOT3}

        if [ $FOLDER == $PWD ]; then

          echo "You are not in under any root folders given"
          exit 2;

        fi

      fi

    fi

    if [[ $FOLDER ]]; then

      if [[ $FILE ]]; then

        echo "Running ${ME} for file: " $FOLDER/$FILE
        $TOOL $ROOT1$FOLDER/$FILE $ROOT2$FOLDER/$FILE $ROOT3$FOLDER/$FILE &

      else

        echo "Running ${ME} for subfolder: " $FOLDER
        $TOOL $ROOT1$FOLDER $ROOT2$FOLDER $ROOT3$FOLDER &

      fi

    fi

  fi

else

  ${ME} --help

fi




