#!/bin/bash

################################################################################################
#
# This script installs monit and configures it for the use with searchblox
#
# created by ege
#
# changelog
#
# 20141113
# created
#
################################################################################################

#global script variable
me=$(basename $0)
log_out="STDOUT"
log_out_err="STDERR"

function usage {
	echo "Usage: $(basename $0) -e email [ -v ]" >&2
	echo >&2
	echo "-h) displays this help" >&2
	echo "-e) email address to send monit alerts to" >&2
	echo "-v) be more verbose (includes debug output)" >&2
	echo >&2
}

function cleanup {
	set +u
	set +e
	rm $tempfile >/dev/null 2>&1
	unset IFS
	exitCode=$1
	if [ "$exitCode" != "0" ]
	then   
		echo -e "\nAborting\n"
	fi
	trap - SIGINT SIGTERM EXIT
	exit $exitCode
}

function initialize {
	trap "cleanup 2" SIGINT SIGTERM EXIT
	tempfile=$(mktemp -t $(basename $0).XXXXXX)
	set -e
	set -u
}

function parseOpts {
	alert_recipient=
	verbose=false
	while getopts ve:h opts
	do
		case $opts in
			v) verbose=true
			;;
			e) alert_recipient=$OPTARG
			;;
			h) usage; exit 0
			;;
			*) usage; exit 1
			;;
		esac
	done
	if [ -z "$alert_recipient" ]
	then
		usage; exit 1
	fi
}

function log {
	local msg="$1"
	local log_out="$2"
	#log to syslog
	#logger -i -t $me "$msg"
	#log to stdout/stderr
	case $log_out in
		STDOUT)
			echo "$msg" 
			;;
		STDERR)
			echo "$msg" >&2
			;;
		*)
			# fall back to STDERR if unknown option is given
			echo "$msg" >&2
			;;
	esac
}

function debug {
	if $verbose
	then
		log "DEBUG: $1" "$log_out"
	fi
}

function error {
	log "ERROR:  $1" "$log_out_err"
}

function f_get_system_info {
	debug "To monitor accurate system load indication, we need to know how much cpus the system has got"
	cpus=$(cat /proc/cpuinfo |grep processor|tail -n1 |cut -d":" -f2|tr -cd [:digit:])
	let cpus=$cpus+1
	debug "Found $cpus cpus on your system"
	load_50=$(echo "scale=1;$cpus/2" |bc)
}

function f_install {
	#install epel release if not installed already
	if [ -e /etc/yum.repos.d/epel.repo ]
	then
		debug "epel release seams to be installed, already. Not changing that"
	else
		debug "installing epel release, so we can install monit"
		rpm -ivh http://mirror.switch.ch/ftp/mirror/epel/6/i386/epel-release-6-8.noarch.rpm
	fi
	debug "testing if monit is installed"
	if $(which monit &>/dev/null)
	then
		debug "monit seams to be installed, already"
	else
		debug "Installing monit as it doesn't seam to be installed"
		yum -y install monit
	fi
	if [ -e /etc/monit.d/logging ]
	then
		debug "deleting logging file from /etc/monit.d/"
		rm -f /etc/monit.d/logging
	fi
}

function f_configure {
	debug "getting system info"
	f_get_system_info
	debug "writing  monit.conf"
	cat >/etc/monit.conf <<EOF_MONIT_CONF
set daemon 120 #check every 2 minutes
set logfile syslog facility log_daemon # log to syslog
set mailserver localhost #by default send mails through locally running mail server
set alert $alert_recipient # receive all alerts
#if you need to send mails through external host, uncomment and change the following lines accordingly
#set mailserver mail.example.com
#	username "user" password "123456":w
##########################3
# some basic checks
check system localhost
	if loadavg (5min) > $cpus then alert #cpus may be replaced by $load_50, wthich is "used 50% of system resources"
	if memory usage > 85% then alert #alert if more than 85% memory is used
# include specific monitoring rules
include /etc/monit.d/*
EOF_MONIT_CONF
	mkdir -p /etc/monit.d/
	debug "creating searchblox monit conf"
	cat >/etc/monit.d/searchblox.conf <<EOF_SB_MONIT_CONF
check process searchblox_process with pidfile /var/run/wrapper.searchblox.pid
	start program = "/etc/init.d/searchblox start" with timeout 60 seconds
	stop program = "/etc/init.d/searchblox stop"
	if cpu > 75% for 3 cycles then alert
	if totalmem > 75% for 3 cycles then alert
#	if cpu > 95% for 3 cycles then restart
#	if totalmem > 75% for 3 cycles then restart
check host searchblox_service with address localhost 
	if failed url http://localhost/searchblox/search.jsp
	and content == 'Basic Search'
	then restart
check filesystem searchblox_folder with path /opt/searchblox
	if space gt 75% then alert
EOF_SB_MONIT_CONF
	debug "finished"

}

parseOpts "$@"
initialize
f_install
f_configure
debug "enabling autostart of monit"
chkconfig monit on
debug "starting monit"
service monit start
cleanup 0

