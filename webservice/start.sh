#!/bin/bash

# info
echo ">>> starting node mojojs server with reload support"
echo ">>> type rs + enter to restart node"

#
# run application
#

# default port (3000)
npx nodemon index.js server

# # customized port
# npx nodemon index.js server -l http://127.0.0.1:8000