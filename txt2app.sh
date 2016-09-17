#!/bin/bash
#
# Fast text search for android build
#
# 05-Nov-2013  Marko Kallinki  Speed optimization (for *.xml)
# 04-Nov-2013  Marko Kallinki  Handle <string-array> lists
# 03-Nov-2013  Marko Kallinki  Add options and % counter
# 01-Nov-2013  Marko Kallinki  Initial version
#

starttime=$(date +%s)
ME="`basename $0`"

# TODO: -a absolute path info?
USAGEVERBOSE="\

Search tool to map MView text resources to application code files

Usage:
$ME \"*text*\"      - Text seen on phone screen
$ME ... \"en\"      - limit search to values-en*.xml file(s)
$ME ... -c        - Find java code files using the resource(s)
$ME ... -i        - Ignore resource names without \"_\"
$ME -h | --help   - This information
"

#
# Process arguments.
#
if [ $# -eq 0 ]; then
  echo "$USAGEVERBOSE"
  exit 0;
fi

if [ "$1" = -h -o "$1" = --help ]; then
  echo "$USAGEVERBOSE"
  exit 0
else
  text=$1
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      echo "$USAGEVERBOSE"
      exit 0;;
    -c | --code)
      codecheck=true
      shift;;
    -i | --ignore)
      ignore=true
      shift;;
    *)
    lang=$1
    shift;;
  esac
done


#
#  Check if asterisks found, and make plain text for output
#
plaintext=$text
len=${#plaintext}
last=$(($len - 1))

if [[ ${plaintext:0:1} = \* ]]; then
   plaintext=${plaintext:1:$last}
   len=${#plaintext}
   last=$(($len - 1))
fi

if [[ ${plaintext:$last:$(($last1+1))} = \* ]]; then
   plaintext=${plaintext:0:$last}
fi

if [[ $lang ]]; then

  echo -e "\e[00;32m$ME : Search usage of \"$text\" text from values-$lang*.xml files\e[00m"

else

  echo -e "\e[00;32m$ME : Search usage of \"$text\" text\e[00m"

fi

#
#  First search text from xml files
#
OLDIFS=$IFS
IFS=$'\n'
filelist=(`find . -type f -readable -name "*.xml"`)
IFS=$OLDIFS
filelistlen=${#filelist[*]}
fcount=0
ignorecount=0

echo "Parsing $filelistlen resource files..."
echo

arrid=0

for file in "${filelist[@]}"
do

  fcount=$(($fcount + 1))
  tput cuu 1 # move 1 line up
  echo $(($fcount*100/$filelistlen))"%  "

  # FIXME: Doesn't work in no folder, i.e. only files
  if [[ $file = *value* ]]; then

      if [[ $lang ]]; then

        if ! [[ $file = *values-$lang* ]]; then

          continue # Wrong language

        fi

      fi

  else

    continue # Not localisation file

  fi

  #
  # Speed optimization
  #
  precheck=(`grep -a --count --max-count=1 "$text" $file`)
  if [[ $precheck == 0 ]]; then
    continue
  fi

  stringarr=false
  firstmatch=true
  lcount=0

  while read line
  do

    lcount=$(($lcount + 1))
    rnameok=false

    #
    # string arrays
    #
    if [[ $stringarr = false ]]; then

      if [[ $line = *\<"string-array"* ]]; then

        rname=${line#*name=\"} # keep after name="
        rname=${rname%%\"*} # keep before "
        stringarr=true
        continue

      fi

    else

      if [[ $line = *\<"item"* ]]; then

        localisation=${line%\</item\>*}  # remove last </string>
        localisation=${localisation##*\>} # keep after last >

        # strip " markers (some has them, some don't?)
        if [[ ${localisation:0:1} = \" ]]; then

          last=$((${#localisation} - 1))
          localisation=${localisation:0:$last}
          localisation=${localisation:1:$last}
 
        fi

        if [[ $localisation = $text ]]; then

          if [[ $firstmatch = true ]]; then

            #if ! [[ $codecheck ]]; then

              tput cuu 1
              echo "     "
              echo -e "\e[00;37mfile:" $file "\e[00m"
              echo

            #fi

            firstmatch=false

          fi

          rnameok=true
 
        fi

      fi

      if [[ $line = *\<"/string-array"* ]]; then

        stringarr=false
        continue

      fi

    fi

    #
    # plain strings
    #
    if [[ $line = *\<"string "* ]]; then

      localisation=${line%\</string\>*}  # remove last </string>
      localisation=${localisation##*\>} # keep after last >

      # strip " markers (some has them, some don't?)
      if [[ ${localisation:0:1} = \" ]]; then

        last=$((${#localisation} - 1))
        localisation=${localisation:0:$last}
        localisation=${localisation:1:$last}
 
      fi

      if [[ $localisation = $text ]]; then

        if [[ $firstmatch = true ]]; then

          #if ! [[ $codecheck ]]; then

            tput cuu 1
            echo "     "
            echo -e "\e[00;37mfile:" $file "\e[00m"
            echo

          #fi

          firstmatch=false

        fi

        rname=${line#*name=\"} # keep after name="
        rname=${rname%%\"*} # keep before "
        rnameok=true
        
        if [[ $ignore ]]; then

          if ! [[ "$rname" = *\_* ]]; then

            tput cuu 1
            output='"'${localisation%$text*}"\e[00;31m"$plaintext"\e[00m"${localisation#*$text}'"'
            echo -e $lcount': '$output' -> '$rname' (Ignored!)'
            echo

            rnameok=false
            ignorecount=$(($ignorecount + 1))

          fi

        fi

      fi

    fi

    #
    # Collect resource ids (and texts) in an array
    #
    if [ $rnameok = true ]; then

      #FIXME: remove duplicates 
      resoarray[$arrid]=$rname
      textarray[$arrid]=$localisation
      arrid=$(($arrid + 1))

      #if ! [[ $codecheck ]]; then
     
        tput cuu 1
        output='"'${localisation%$text*}"\e[00;31m"$plaintext"\e[00m"${localisation#*$text}'"'
        if [[ $stringarr = true ]]; then 
          echo -e $lcount': '$output' -> '$rname' (array)'
        else
          echo -e $lcount': '$output' -> '$rname
        fi
        echo

      #fi

    fi

  done < $file

done

tput cuu 1
echo "    "
echo -e "\e[00;32mFound $arrid matching resources for \"$text\"\e[00m"

if [[ $ignore ]]; then

  echo -e "\e[00;32mIgnored $ignorecount without underscore (causes too many mismatch in code files)\e[00m"

fi

if ! [[ $codecheck ]]; then

  elapsed=$(($(date +%s) - $starttime))
  echo -e "\e[00;32mSearch ended $(date +%T) and took $(($elapsed/60)) minutes $(($elapsed%60)) seconds\e[00m"
  echo -e "\e[00;32mUse -c option to see actual code files which use the(se) text resource(s).\e[00m"
  echo
  exit

fi

#
# Check if resource(s) in code files
#

if [[ $rname ]]; then

  filelist=(`find . -type f -readable -name "*.java"`)
  filelistlen=${#filelist[*]}
  resoarraylast=$((${#resoarray[@]} -1))
  resoarrayseq=$(seq 0 $resoarraylast)
  fcount=0
  mcount=0

  echo "Parsing ${#filelist[*]} code files..."
  echo

  for file in "${filelist[@]}"
  do

    fcount=$(($fcount + 1))
    tput cuu 1
    echo $(($fcount*100/$filelistlen))"%  "

    lcount=0
    while read line
    do
      
      lcount=$(($lcount + 1))

      # inner loop
      for resoid in $resoarrayseq
      do

        elem=${resoarray[$resoid]}
        if [[ $line = *$elem* ]]; then

          mcount=$(($mcount + 1))
          localisation=${textarray[$resoid]}
          
          tput cuu 1
          echo "                    "
          echo -e '"'${localisation%$text*}"\e[00;31m"$plaintext"\e[00m"${localisation#*$text}'"'
          echo $file":"$lcount
          echo -e ${line%$elem*}"\e[00;31m"$elem"\e[00m"${line#*$elem}
          echo

        fi 

      done
      
    done < $file

  done

fi

#TODO: collect above results in array
# loop array for each r.java - if in active build?

tput cuu 1
echo "                    "
echo -e "\e[00;32mFound $arrid resource usages for \"$text\"\e[00m"
elapsed=$(($(date +%s) - $starttime))
echo -e "\e[00;32mSearch ended $(date +%T) and took $(($elapsed/60)) minutes $(($elapsed%60)) seconds\e[00m"



