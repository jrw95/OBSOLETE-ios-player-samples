#!/bin/bash

# run this script in the root directory
[[ `basename "$PWD"` = "scripts" ]] && echo Please run this script from this project\'s base directory. && exit 1 ;

source_project=${1}
target_project=${2}

# we need to set LANG and LC_CTYPE to 'UTF-8' so that sed won't thrown errors like this:
# sed: RE error: illegal byte sequence
# cocoapods also warns if these variables are not set to UTF-8
if [[ ${LANG} != "UTF-8" ]] ; then
  export LANG='UTF-8' ;
fi

if [[ ${LC_CTYPE} != "UTF-8" ]] ; then
  export LC_CTYPE='UTF-8' ;
fi

function usage() {
  echo "Usage:" ;
  echo "copy-project.sh <source project> <target project>"
  echo "You can call copy-project.sh from anywhere within this project."
}

case ${1} in
  "-help" | "--help" | "-h" | "?")
    usage ;
    exit 0 ;
    ;;
  * )
    if [ "$#" -ne 2 ] ; then
      echo "You must supply both a SOURCE and a TARGET directory." ;
      echo "Exiting." ;
      exit 1 ;
    fi
    ;;
esac

if [[ -d ${source_project} ]] ; then
  if [[ -d ${target_project} ]] ; then
    echo A project named ${target_project} was found: ;
    ls -l ${target_project} ;
    echo ;
    echo Do you want to replace it? Entering Y will remove the existing copy of ${target_project} ;
    read response ;
    case $response in
      "Y" | "y" | "Yes" | "yes" )
        rm -rf ${target_project} ;
        cp -r ${source_project} ${target_project} ;;
      * )
        echo Aborting project copy.
        exit 1 ;;
    esac
  else
    cp -r ${source_project} ${target_project} ;
  fi
else
  echo ;
  echo No project named ${source_project} was found for copying. ;
  echo Exiting. ;
  exit 1 ; 
fi

cd ${target_project} ;
target_dir=`pwd` ;

# remove the Podfile.lock file and the Pods directory; we'll be running a fresh pod install later
rm Podfile.lock ;
rm -rf Pods ;

# clean out the xcuserdata directory
rm -rf "${source_project}/${source_project}.xcworkspace/xcuserdata/"

sed_cmd="s/${source_project}/${target_project}/g"
for i in `grep -lr ${source_project} .` ;
do
  sed ${sed_cmd} < ${i} > ${i}-sed
    if [[ "$?" -ne "0" ]] ; then
      echo Error processing file ${i};
    fi
  mv ${i}-sed ${i}
done

# Rename the files and directories from the source name to the target name
# We need a nested loop here, because we're renaming both
# TODO: find a way to suppress output like "ls: SingleVideoPlayer*: No such file or directory"
# When no files exist that match the search string
ls ${1}* | sed 's/:$//' | while read file ; 
do
  if [[ -d $file ]] ; then
    # We need the new file name to cd into it
    filedir=`mv -v "$file" "${file/${1}/${2}}" | cut -d'>' -f 2`;
    cd ${filedir} ;
    for infile in $(ls "${1}"*);
    do
      basefilename=$(basename ${infile}) ;
      mv "${basefilename}" "${basefilename/${1}/${2}}" ;
    done;
  fi
  cd ${target_dir} ;
done

# Create a symlink called "workspace" in the root directpry, and point it at the
# actual workspace folder.
rm -rf "workspace"
ln -s "${target_project}.xcworkspace" "workspace"

pod install ;

echo Done. You can open the workspace by typing '`open workspace`'.
