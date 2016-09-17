#!/bin/bash
#
# Shared folder between linux and windows
#
# 01-Nov-2013  Marko Kallinki  Initial version
#

if [[ $1 ]]; then

  rootfolder="$HOME/netdrives"
  targetfolder=$rootfolder/$1

  if [ ! -d $rootfolder ]; then
    mkdir $rootfolder
  fi

  if [ ! -d $targetfolder ]; then
    mkdir $targetfolder
  fi

  mountlist=(`mount | grep "$1 on $targetfolder"`)

  if [ ${#mountlist[*]} = 0 ]; then

    echo "Mount netfolder as $targetfolder"
    sudo mount -t vboxsf $1 $targetfolder

    #
    # Share otherway around (in Windows):
    # net use x:\\vboxsvr\share
    #

  else

    echo "Mount exists: $targetfolder"

  fi

else

  echo -e "\e[00;31mError: Give shared folder name as parameter\e[00m"
  echo "e.g. in VirtualBox -> Shared Folders ..."
 
fi






