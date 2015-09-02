#!/bin/bash
## Description: Regular software updates are important for test and production servers to keep the systems secured and up to date. We usually update the test servers at the first week of the month and test for a week. If everything looks good with the update, we perform software update on the production servers. But there are chance of non tested packages updated in production servers which released in after the test server update. This script ensures that only the tested packages and versions will be updated in production systems.
## Author  : Selvakumar Arumugam <selva@endpoint.com>
## Options: 
##   -h, --help    Display this message.
##   -t            Type of the server to update, test or prod
## Test Server Options
##   -s            Name of the test server to use in filename, Optional
##   -p            Test server path to place the processing files, optional
## Prod Server Options
##   -S            Name of the remote test server to fetch the tested packages list
##   -U            Username of the remote test server to fetch the tested packages list
##   -P            Remote Test server path to fetch the tested packages file, Optional
##   -p            Prod server path to place the tested packages list file from test server, Optional
##
## Test Server Update Usage: ./tested_update.sh -t test [-s server] [-p path] [-f file_name] 
## Prod Server Update Usage: ./tested_update.sh -t prod -S remote_server -U remote_user [-P remote_path] [-p path]

echo -e "
    ##########################################################\n\
    ############ Auto Tested Server Update Script ############\n\
    ##########################################################
"
function usage
{
  tmp_path=~/tmp
  echo "    ### Test Server Update Usage: ./tested_update.sh -t test [-s server] [-p path] [-f file_name] ###"
  echo "    ### Prod Server Update Usage: ./tested_update.sh -t prod -S remote_server -U remote_user [-P remote_path] [-p path]###"
  echo "    ### Default Values ###"
  echo -e "
      server : $(hostname) \n\
      path: $tmp_path \n\
      file_name: diff_update_$(hostname).$(date +%Y-%m-%d).txt \n\
      remote_path: $tmp_path\n"
}

if [ "$1" == "" ]; then
  usage
  exit
fi
 
server=`hostname`
today=`date +%Y-%m-%d`
file_name="diff_server_update_$server.$today.txt"
path=~/tmp
remote_user=""
remote_server=""
remote_path=~/tmp

while [ "$1" != "" ]; do
    case $1 in
        -t)                     shift
                                update_type=$1
                                ;;
        -s)                     shift
                                server=$1
                                ;;
        -p)                     shift
                                path=$1
                                ;;
        -f)                     shift
                                file_name="diff_$1"
                                ;;
        -U)                     shift
                                remote_user=$1
                                ;;
        -S)                     shift
                                remote_server=$1
                                ;;
        -P)                     shift
                                remote_path=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done


# Test server actions
if [ "$update_type" == "test" ] ; then
  [ -d $path ] || mkdir -p $path
  apt-get update
  before_update="before_update_$server.$today.txt"
  if [ -f "$path/$before_update" ]
  then
    echo "INFO: $path/$before_update already generated, ignoring overwrite to preserve the package details before upgrade"
  else
    dpkg -l | tail -n +6 | awk '{print $2"="$3}' > $path/before_update_$server.$today.txt
  fi
  apt-get dist-upgrade
  dpkg -l | tail -n +6 | awk '{print $2"="$3}' > $path/after_update_$server.$today.txt
  diff -y $path/before_update_$server.$today.txt $path/after_update_$server.$today.txt | egrep '[<>|]' > $path/$file_name
  exit
elif [ "$update_type" == "prod" ]
then
  # Production server actions
  # files=$(ls *.txt)
  echo "*** Producttion Server Update Process ***"
  if [[ ("$remote_user" == "") || ("$remote_server" == "") ]]; then
    echo -e "ERROR: Must provide remote user and server to fetch tested package lists\n"
    usage 
    exit
  elif [[ ! `ssh $remote_user@$remote_server test -d "$remote_path" && echo true` ]]
  then
    echo "ERROR: Remote path $remote_path doesn't exist, please ensure the right path"
    usage 
    exit
  else
    echo -e "
      remote_user: $remote_user\n\
      remote_server: $remote_server\n\
      remote_path: $remote_path\n\
    "
  fi

  # Fetch the list of tested packages & versions file from test server 

  # files=$(ssh selva@selva cd $remote_path && ls diff*)
  files=$(ssh $remote_user@$remote_server ls $remote_path/diff*)
  i=0

  for j in $files
  do
    i=$(( i + 1 ))
    echo "$i.$j"
    file[$i]=$j
  done

  while [[ $number == "" || $number > $i ]]
  do
    read -p "Enter a number to choose file: " number
  done
  remote_file=`basename ${file[$number]}`
  echo "INFO: You have selected the file: $remote_file" 
  [ -d $path ] || mkdir -p $path
  echo "INFO: scp $remote_user@$remote_server:$remote_path/$remote_file $path"
  scp $remote_user@$remote_server:$remote_path/$remote_file $path

  # Processing packages under tested packages

  echo "INFO: Fetching the list of packages need to be changed...!"
  updates=`apt-get --just-print dist-upgrade | egrep -v '(Inst|Conf)' | head -n -1`
  packages=`echo $updates | awk -F 'The following ' '{for (i =2 ; i <= NF; i++) {print $i} }'`

  install=""
  upgrade=""
  remove=""
  while read p; do
    if [[ ("$p" == *"NEW packages will be installed"*) || ("$p" == *"extra packages will be installed"*) ]] ; then
      string="$( cut -d ':' -f 2- <<< "$p" )"; # echo "$string"
      install="$install$string" 
    elif [[ "$p" == *"packages will be upgraded"* ]]
    then
      string="$( cut -d ':' -f 2- <<< "$p" )"; # echo "$string"
      upgrade="$upgrade$string" 
    elif [[ "$p" == *"packages will be REMOVED"* ]]
    then
      string="$( cut -d ':' -f 2- <<< "$p" )"; # echo "$string"
      remove="$remove$string" 
    fi
  done < <(echo "$packages")

  # Generate server update commands based on filtered packages 
  install_filter=`echo "$install" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
  to_install=`grep '>' $path/$remote_file | cut -d '>' -f 2 | grep "$install_filter"`
  echo "*********************** Installation *************************"
  echo "apt-get install" $to_install
  apt-get install $to_install
  echo "**************************************************************"
  upgrade_filter=`echo "$upgrade" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
  to_upgrade=`grep '|' $path/$remote_file | cut -d '|' -f 2 | grep "$upgrade_filter"`
  echo "************************* Upgrade ****************************"
  echo "apt-get install" $to_upgrade
  apt-get install $to_upgrade
  echo "**************************************************************"
  remove_filter=`echo "$remove" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
  to_remove=`grep '<' $path/$remote_file | cut -d '<' -f 1 | grep "$remove_filter"`
  echo "************************** Removal ***************************"
  echo "apt-get remove" $to_remove
  apt-get remove $to_remove
  echo "**************************************************************"
else
  echo "ERROR: Please provide server type as 'test' or 'prod'"
fi
