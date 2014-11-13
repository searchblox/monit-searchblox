#monit-searchblox#
================

Bash script for installation and configuration of monit for monitoring SearchBlox Server

##"installing" the script##

Download the script (searchblox_monit.sh) and move/copy it to your server. 

Login to console and become root: 

> sudo su - 

now change to the directory where you put the script.

change rights for the script

> chmod 0755 searchblox_monit.sh

and execute it according to the usage informations

> ./searchblox_monit.sh -e yourname@yourdomain.tld -v

This will install monit, configure it and start monitoring your searchblox installation

##script usage##

Usage: searchblox_monit.sh -e email [ -v ]

-h) displays this help
-e) email address to send monit alerts to
-v) be more verbose (includes debug output)

This script installes monit on a CentOS system, does the configuration and starts it up
