Description:
===========
Regular software updates are important for test and production servers to keep the systems secured and up to date. We usually update the test servers at the first week of the month and test for a week. If everything looks good with the update, we perform software update on the production servers. But there are chance of non tested packages updated in production servers which released in after the test server update. This script ensures that only the tested packages and versions will be updated in production systems.
Author:
======
Selvakumar Arumugam <selva@endpoint.com>
Usage:
======
#### Test Server Update Usage: 
./auto-tested-server-update.sh -t test [-s server] [-p path] [-f file_name] 
#### Prod Server Update Usage: 
./auto-tested-server-update.sh -t prod -S remote_server -U remote_user [-P remote_path] [-p path]

Options:
======= 
   -h, --help    Display this message.
   
   -t            Type of the server to update, test or prod
   
Test Server Options
-------------------
   -s            Name of the test server to use in filename, Optional
   
   -p            Test server path to place the processing files, optional
   
Prod Server Options
-------------------
   -S            Name of the remote test server to fetch the tested packages list
   
   -U            Username of the remote test server to fetch the tested packages list
   
   -P            Remote Test server path to fetch the tested packages file, Optional
   
   -p            Prod server path to place the tested packages list file from test server, Optional


