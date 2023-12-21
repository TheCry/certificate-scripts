#!/bin/bash

# Script updates Apache2 certchain and key. It also restarts
# the apache2 service.

# This script should be securely placed with limited access
# (e.g. owned by root with permissions of 700) to avoid
# compromising the API Keys

# ECDSA Keys ARE supported

## Recommended cron -- run at boot (in case system was powered off
# during a renewal, and run weekly)
# Pick any time you like. This time was arbitrarily selected.

# sudo crontab -e
# @reboot sleep 15 && /script/path/here
# 5 4 * * 2 /script/path/here

## Set VARs in accord with environment
cert_apikey=<cert API key>
key_apikey=<key API key>
# server hosting key/cert
server=certdp.local:port
# name of the key/cert (as it is on server)
cert_name=apache.example.com

# URL paths
api_cert_path=legocerthub/api/v1/download/certificates/$cert_name
api_key_path=legocerthub/api/v1/download/privatekeys/$cert_name
# local user who will own certs
cert_owner=root
# local cert storage
local_certs=/etc/apache2/certs
# path to store a timestamp to easily see when script last ran
time_stamp=/etc/apache2/certs/cert_timestamp.txt
# temp folder
temp_certs=/tmp/tempcerts

## Script
# stop / fail on any error
set -e

# Make folder if doesn't exist
sudo [ -d "$temp_certs" ] || sudo mkdir "$temp_certs"

# Fetch certs, if curl returns anything other than 200 success, abort
http_statuscode=$(sudo curl -L https://$server/$api_cert_path -H "apiKey: $cert_apikey" --out $temp_certs/certchain.pem --write-out "%{http_code}")
if test $http_statuscode -ne 200; then exit "$http_statuscode"; fi
http_statuscode=$(sudo curl -L https://$server/$api_key_path -H "apiKey: $key_apikey" --out $temp_certs/key.pem --write-out "%{http_code}")
if test $http_statuscode -ne 200; then exit "$http_statuscode"; fi

# if different
if ( ! cmp -s "$temp_certs/certchain.pem" "$local_certs/certchain.pem" ) || ( ! cmp -s "$temp_certs/key.pem" "$local_certs/key.pem" ) ; then
	sudo service apache2 stop

	sudo cp -rf $temp_certs/* $local_certs/

	sudo chown $cert_owner:$cert_owner $local_certs/*

	sudo chmod 600 $local_certs/key.pem
	sudo chmod 644 $local_certs/certchain.pem

	sudo service apache2 start
fi

sudo rm -rf $temp_certs
echo "Last Run: $(date)" > $time_stamp
