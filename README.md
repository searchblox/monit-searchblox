#monit-searchblox#
================

Bash script for installation and configuration of monit for monitoring SearchBlox Server.
Runable on Ubuntu, debian, CentOS, and RedHat (version 5 and 6)

__What it does__

- install monit (and the needed EPEL repository)
- configuring monit to:
	- check every 2 Minutes
	- log to syslog
	- send mails through local installed mailserver
	- send alerts to the address given as option
	- check load (alert if the 5 Mins average is above the number of cpus)
	- alert if memory usage is more than 85%
	- check process searchblox and restart if not running
	- alert if searchblox uses more than 75% cpu
	- alert if memory usage of searchblox exceeds 75%
	- restart searchblox if there is no string "Basic Search" as result to query http://localhost/searchblox/search.jsp
	- alert if disk where searchblox is installed on (/opt/searchblox) has less than 25% free
- start monit

It also adds some other config values you can easily uncomment and enable/adjust.

##prerequisites##

- searchblox is installed, already (into /opt/searchblox)


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

'''Usage: searchblox_monit.sh -e email [ -v ]

-h) displays this help
-e) email address to send monit alerts to
-v) be more verbose (includes debug output)
'''
