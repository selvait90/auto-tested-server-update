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
files=$(ssh selva@selva cd $remote_path && ls diff*)
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


