#!/bin/bash
#
# Multi Finder, to compare results of two separate search
#
# 12-Dec-2013  Marko Kallinki  Spaces in filenames fix
# 28-Nov-2013  Marko Kallinki  Shortform for most used find command
# 08-Nov-2013  Marko Kallinki  Dir/file options and error info added
# 05-Nov-2013  Marko Kallinki  Speed optimization
# 03-Nov-2013  Marko Kallinki  Added progress % info
# 31-Oct-2013  Marko Kallinki  Added additional and excluded options
# 31-Oct-2013  Marko Kallinki  Refactor grep and parameter order
# 28-Oct-2013  Marko Kallinki  Initial version
#

starttime=$(date +%s)
ME="`basename $0`"

USAGEVERBOSE="\

Search tool to grep textfiles and store results for comparison

Usage:
$ME \"text\"             - Find text in all textfiles
$ME ... \"*.xml\"        - Find text in any files
$ME ... -a \"text\"      - Additional text to be matched
$ME ... -e \"text\"      - Exclude lines with this text
$ME ... -d \"name\"      - Exclude named subdirectory
$ME ... -n             - Show (file)names only
$ME ... -o (editor)    - Open search result with editor
$ME ... -r|-l          - Store as left or right result
$ME -c (difftool)      - Compare left and right results
$ME -f name            - Filename search (no text check)
$ME -h                 - This information
"

THERESULT="/$HOME/.result.txt"
LEFTRESULT="/$HOME/.lresult.txt"
RIGHTRESULT="/$HOME/.rresult.txt"

#
# Process arguments.
#
if [ $# -eq 0 ]; then
  echo "$USAGEVERBOSE"
  exit 0;
fi

#
# First parameter (text)
#
case "$1" in
  -h | --help)
    echo "$USAGEVERBOSE"
    exit 0;;
  -f | --find)
    find . -name "*$2*"
    exit;;
  -c | --compare)
    if [ $# -ge 2 ]; then
      difftool="$2"
    else
      difftool="diff"
    fi
    echo "Compare left and right results with '$difftool' (wait a sec.)"

    if ! [ -f $LEFTRESULT ]; then
      echo -e "\e[00;31mYou need to store result with -l before you can compare\e[00m"
      exit 1;
    fi
    if ! [ -f $RIGHTRESULT ]; then
      echo - e "\e[00;31mYou need to store result with -r before you can compare\e[00m"
      exit 1;
    fi
    $difftool $LEFTRESULT $RIGHTRESULT &
    echo
    exit 0;;
  *)
    if [[ "$1" != -* ]]; then
      text="$1"
    fi
    ;;
esac

#
# Rest of parameters
#
result=$THERESULT
filename="."
extra=""
without=""
skip=""
shift;

while [ $# -gt 0 ]; do
  case "$1" in
    -l | --left)
      targetfile=$LEFTRESULT
      shift;;
    -r | --right)
      targetfile=$RIGHTRESULT
      shift;;
    -a | --additional)
      additional="$2"
      extra=" and '$2'"
      shift
      shift;;
    -e | --exclude)
      exclude="$2"
      without=" except '$2'"
      shift
      shift;;
    -d | --exclude-dir)
      exdir="$2"
      skip=" (skipping */$exdir/*)"
      shift
      shift;;
    -n | --names-only)
      filesonly=true
      shift;;
    -o | --open)
      if [[ $# -gt 1 ]]; then
        editor="$2"
        shift
      else
        editor="gedit" # default
      fi
      shift;;
    *)
    filename="$1"
    if [[ $filename = .* ]]; then
      filename='*'"$filename"
    fi
    shift;;
  esac
done

echo -e "\e[00;32m$ME : Searching '$text'$extra$without in files $filename$skip under\e[00m"
echo -e "\e[00;32m$PWD\e[00m"
echo

if [[ $result ]]; then
  echo "$ME : Searching '$text'$extra$without in files $filename$skip under" > $result
  echo $PWD >> $result
fi

#
#  Loop files (grep check ignores binary files) and lines
#
fcount=0
prevprogress=-1
mcount=0
gcount=0

OLDIFS=$IFS
IFS=$'\n'
if [ "$filename" = "." ]; then
  filelist=(`find . -type f -readable`)
else
  filelist=(`find . -type f -readable -name "$filename"`)
fi
IFS=$OLDIFS

filelistlen=${#filelist[*]}
echo "Checking $filelistlen files..."
echo

for file in "${filelist[@]}"
do
  firstmatch=true

  fcount=$(($fcount + 1))
  progress=$(($fcount*100/$filelistlen))
  if [ $progress -gt $prevprogress ]; then
    tput cuu 1
    echo "$progress%  "
    prevprogress=$progress
  fi

  #
  # Skip files under excluded dir
  #
  if [[ $exdir ]]; then
    if [[ $file == */$exdir/* ]]; then
      continue
    fi
  fi

  #
  # Speed optimization
  #
  precheck=(`grep -I -a --count --max-count=1 "$text" "$file"`)
  if [[ $precheck == 0 ]]; then
    continue
  fi

  while read line
  do

    #
    # Check primary, additional and excluded texts
    #
    match=false
    if [[ $line = *$text* ]]; then
      if [[ $additional ]]; then
        if [[ $line = *$additional* ]]; then
          match=true
        fi
      else
        match=true
      fi
      if [[ $exclude ]]; then
        if [[ $line = *$exclude* ]]; then
          match=false
        fi
      fi
    fi

    if [ $match = true ]; then

      #
      # Print filename only once
      #
      if [ $firstmatch = true ]; then
        mcount=$(($mcount + 1))

        tput cuu 1
        if ! [[ $filesonly ]]; then
          echo "      "
        fi
        echo -e "\e[00;37mfile:" $file "\e[00m"
        echo
        if [[ $result ]]; then
          if ! [[ $filesonly ]]; then
            echo "" >> $result
          fi
          echo "file:" $file >> $result
        fi
        firstmatch=false

        if [[ $filesonly ]]; then
          break
        fi

      fi

      #
      # Print matched lines with red highlight
      #
      gcount=$(($gcount + 1))
      output=${line%$text*}"\e[00;31m$text\e[00m"${line#*$text}
      if [[ $additional ]]; then
        output=${output%$additional*}"\e[00;31m$additional\e[00m"${output#*$additional}
      fi
      tput cuu 1
      echo -e " " $output
      echo
      if [[ $result ]]; then
        echo " " $line >> $result
      fi

    fi
  done < $file
done

tput cuu 1
echo "           "
echo -e "\e[00;32mFound $gcount matches in $mcount files of total $filelistlen files checked\e[00m"
if [[ $result ]]; then
  echo "" >> $result
  echo "Found $gcount matches in $fcount files of total $filelistlen files checked." >> $result
fi

if [[ $targetfile ]]; then
  cp $result $targetfile
  echo -e "\e[00;32mResult stored in $targetfile for comparison; $ME -c\e[00m"
fi

echo -e "\e[00;32mSearch ended $(date +%T) and took $(($(date +%s) - $starttime)) second(s)\e[00m"

if [[ $editor ]]; then
  echo "Opening result with $editor"
  #fixme: don't work 2>&1 1>/dev/null &
  $editor $result &
else
  echo "Result stored in $result"
fi


