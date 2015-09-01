#!/bin/bash
# Regular software updates are important for test and production servers to keep the systems secured and up to date. We usually update the test servers at the first week of the month and test for a week. If everything looks good with the update, we perform software update on the production servers. But there are chance of non tested packages updated in production servers which released in after the test server update. This script ensures that only the tested packages and versions will be updated in production systems.

# Test server actions
# server=$1
# today=`date +%Y-%m-%d`
# apt-get update
# dpkg -l | tail -n +6 | awk '{print $2"="$3}' > before_update_$server.$today.txt
# apt-get dist-upgrade
# dpkg -l | tail -n +6 | awk '{print $2"="$3}' > after_update_$server.$today.txt
# diff -y before_update_$server.$today.txt after_update_$server.$today.txt | egrep '[<>|]' > diff_update_$server.$today.txt

# Production server actions
# files=$(ls *.txt)
remote_user="root"
remote_server="selva"
remote_path="~/tested-update"
# files=$(ssh selva@selva cd $remote_path && ls diff*)
files=$(ssh selva@selva cd $remote_path && ls *)
i=1

for j in $files
do
  echo "$i.$j"
  file[$i]=$j
  i=$(( i + 1 ))
done

echo "Enter a number to choose file"
read input
echo "You select the file ${file[$input]}"
remote_file=${file[$input]}
echo "scp $remote_user@$remote_server:$remote_path/$remote_file ."

# Processing packages under tested packages

updates=`apt-get --just-print dist-upgrade | egrep -v '(Inst|Conf)' | head -n -1`
# echo "$updates" | grep -A3 "The following"
packages=`echo $updates | awk -F 'The following ' '{for (i =2 ; i <= NF; i++) {print $i} }'`

install=""
upgrade=""
remove=""
echo "**************************************************************"
while read p; do
  echo $p
  if [[ ("$p" == *"NEW packages will be installed"*) || ("$p" == *"extra packages will be installed"*) ]] ; then
    echo "INSTALLED"
    string="$( cut -d ':' -f 2- <<< "$p" )"; echo "$string"
    install="$install$string" 
  elif [[ "$p" == *"packages will be upgraded"* ]]
  then
    echo "UPGRADED"
    string="$( cut -d ':' -f 2- <<< "$p" )"; echo "$string"
    upgrade="$upgrade$string" 
  elif [[ "$p" == *"packages will be REMOVED"* ]]
  then
    echo "REMOVED"
    string="$( cut -d ':' -f 2- <<< "$p" )"; echo "$string"
    remove="$remove$string" 
  fi
done < <(echo "$packages")

# echo "** INSTALLED: $install"
install_filter=`echo "$install" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
to_install=`cat $remote_file | grep "$install_filter"`
echo $install_filter
echo "apt-get install --simulate" $to_install
# echo "** INSTALLED: $upgrade"
upgrade_filter=`echo "$upgrade" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\\|/g'`
to_upgrade=`cat $remote_file | grep "$upgrade_filter"`
echo $upgrade_filter
echo "apt-get install --simulate" $to_upgrade
echo "** REMOVED  : $remove"
remove_filter=`echo "$remove" | sed 's/^ //g' | sed 's/[.0-9-]\+ / /' | sed 's/ /\\|/g'`
to_remove=`cat $remote_file | grep "$remove_filter"`
echo $to_upgrade
echo "apt-get remove --simulate" $to_remove

