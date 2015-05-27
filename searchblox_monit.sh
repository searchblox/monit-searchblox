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
#valid for ubuntu and debian
confdir_debian="/etc/monit/conf.d/"
conffile_debian="/etc/monit/monitrc"
confdir_redhat="/etc/monit.d"
conffile_redhat2="/etc/monitrc"
conffile_redhat="/etc/monit.conf"

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

function f_guess_os {
	os_family="unknown"
	debug "trying to find out which OS you are using"
	if grep -i centos /etc/*release &>/dev/null
	then
		debug "seams you are using CentOS"
		os_family="redhat"
		if grep "7." /etc/*release &>/dev/null
		then
			error "not sure if CentOS 7 is supported, already, trying anyway"
		fi
	elif grep -i 'redhat\|rhel' /etc/*release
	then
		debug "looks like you are running on RedHat"
		os_family="redhat"
		if grep "7." /etc/*release &>/dev/null
		then
			error "not sure if RedHat 7 is supported, already, trying anyway"
		fi
	elif grep -i debian /etc/issue &>/dev/null
	then
		debug "you are running a debian System"
		os_family="debian"
	elif grep -i ubuntu /etc/issue &>/dev/null
	then
		debug "seems as if you are using Ubuntu"
		os_family="debian"
	else
		error "Sorry, I could not guess your operating system, and therefore no automatic installation possible"
		cleanup 3
	fi
}

function f_get_system_info {
	debug "To monitor accurate system load indication, we need to know how much cpus the system has got"
	cpus=$(cat /proc/cpuinfo |grep processor|tail -n1 |cut -d":" -f2|tr -cd [:digit:])
	let cpus=$cpus+1
	debug "Found $cpus cpus on your system"
	load_50=$(echo "scale=1;$cpus/2" |bc)
}

function f_install_redhat {
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

function f_install_debian {
	debug "testing if monit is installed"
	if $(which monit &>/dev/null)
	then
		debug "monit seams to be installed, already"
	else
		debug "Installing monit as it doesn't seam to be installed"
		apt-get -y install monit
	fi
}

function f_configure {
#confdir_debian="/etc/monit/conf.d/"
#conffile_debian="/etc/monit/monitrc"
#confdir_redhat="/etc/monit.d"
#conffile_redhat="/etc/monit.conf"
  local cf="conffile_$os_family"
	local cf2="conffile_${os_family}2"
	local cd="confdir_$os_family"
	debug "getting system info"
	f_get_system_info
	debug "writing  ${!cf}"
	cat >${!cf}<<EOF_MONIT_CONF
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
include ${!cd}/*
EOF_MONIT_CONF
	mkdir -p ${!cd}
	debug "creating searchblox monit conf"
	cat >${!cd}/searchblox.conf <<EOF_SB_MONIT_CONF
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
	if [ -e /etc/monit.d/logging ]
	then
		debug "deleting logging file from /etc/monit.d/ which came with install"
		rm -f /etc/monit.d/logging
	fi
  # copy config file to secondary location if it exists; 
  # e.g. CentOS 7 location is /etc/monitrc
  if [ ! -z "${!cf2}" ]
  then
    [ -f ${!cf2} ] && cp ${!cf} ${!cf2}
    chmod 700 ${!cf2}
  fi
	debug "finished"
}

function f_manage_service_debian {
	debug "enabling autostart of monit"
	update-rc.d monit defaults
	debug "starting monit"
	service monit start
}

function f_manage_service_redhat {
	debug "enabling autostart of monit"
	chkconfig monit on
	debug "starting monit"
	service monit start
}

parseOpts "$@"
initialize
f_guess_os
f_install_$os_family
f_configure
f_manage_service_$os_family
cleanup 0

