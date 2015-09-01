#!/bin/bash
# Regular software updates are important for test and production servers to keep the systems secured and up to date. We usually update the test servers at the first week of the month and test for a week. If everything looks good with the update, we perform software update on the production servers. But there are chance of non tested packages updated in production servers which released in after the test server update. This script ensures that only the tested packages and versions will be updated in production systems.

echo -e "
    ##########################################################\n\
    ############ Auto Tested Server Update Script ############\n\
    ##########################################################
"
function usage
{
  echo "    ### Test Server Update Usage: ./tested_update.sh -t test [-s server] [-p path] [-f file_name] ###"
  echo "    ### Prod Server Update Usage: ./tested_update.sh -t prod -S remote_server -U remote_user [-P remote_path] ###"
  echo "    ### Default Values ###"
  echo -e "
      server : $(hostname) \n\
      path: ~/tmp \n\
      file_name: diff_update_$(hostname).$(date +%Y-%m-%d).txt \n\
      remote_path: ~/tmp\n"
}

if [ "$1" == "" ]; then
  usage
  exit
fi
 
server=`hostname`
today=`date +%Y-%m-%d`
file_name="diff_server_update_$server.$today.txt"
path="~/tmp"
remote_user=""
remote_server=""
remote_path="~/tmp"

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
  if [ -f "$before_update" ]
  then
    echo "INFO: $before_update already generated, ignoring overwrite to preserve the package details before upgrade"
  else
    dpkg -l | tail -n +6 | awk '{print $2"="$3}' > before_update_$server.$today.txt
  fi
  apt-get dist-upgrade
  dpkg -l | tail -n +6 | awk '{print $2"="$3}' > after_update_$server.$today.txt
  diff -y before_update_$server.$today.txt after_update_$server.$today.txt | egrep '[<>|]' > $file_name
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
  files=$(ssh selva@selva cd $remote_path && ls *)
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
  echo "INFO: You have selected the file: ${file[$number]}"
  remote_file=${file[$number]}
  [ -d $path ] || mkdir -p $path
  echo "scp $remote_user@$remote_server:$remote_path/$remote_file $path"

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
  to_install=`grep '>' $remote_file | cut -d '>' -f 2 | grep "$install_filter"`
  echo $install
  echo "*********************** Installation *************************"
  echo "apt-get install --simulate" $to_install
  echo "**************************************************************"
  upgrade_filter=`echo "$upgrade" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
  to_upgrade=`grep '|' $remote_file | cut -d '|' -f 2 | grep "$upgrade_filter"`
  echo $upgrade
  echo "************************* Upgrade ****************************"
  echo "apt-get install --simulate" $to_upgrade
  echo "**************************************************************"
  remove_filter=`echo "$remove" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\|/g'`
  to_remove=`grep '<' $remote_file | cut -d '<' -f 2 | grep "$remove_filter"`
  echo $remove
  echo "************************** Removal ***************************"
  echo "apt-get remove --simulate" $to_remove
  echo "**************************************************************"
else
  echo "ERROR: Please provide server type as 'test' or 'prod'"
fi
