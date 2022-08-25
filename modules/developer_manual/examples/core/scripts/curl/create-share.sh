#!/bin/bash

##
## Variable Declaration
##
base_uri={oc-examples-server-url}
API_PATH=ocs/v1.php/apps/files_sharing/api/v1/shares

# Create a public link share of a single file with read permissions, named "paris photo"
curl --user {oc-examples-username}:{oc-examples-password} "$base_uri/$API_PATH" \
     --data 'path=/Photos/Paris.jpg&shareType=3&permissions=3&name=paris%20photo'

# Create a public link share of a single file with read and write permissions, named "Notes"
curl --user {oc-examples-username}:{oc-examples-password} "$base_uri/$API_PATH" \
     --data 'path=/Documents/notes.txt&shareType=3&permissions=15&name=Notes'

# Create a user share with read permissions, named "welcome.txt" that has read
# and share permissions set.
curl --silent --user {oc-examples-username}:{oc-examples-password} \
     "$base_uri/$API_PATH/" \
     --data 'path=/welcome.txt' \
     --data 'shareType=3' \
     --data 'name=welcome.txt' \
     --data 'attributes[0][scope]=ownCloud&attributes[0][key]=read&attributes[0][value]=true'
