#!/bin/sh

hostnames="\
	officecdn.microsoft.com						\
	officecdn.microsoft.com.edgesuite.net				\
	ctldl.windowsupdate.com						\
	niig4.ocsp.secomtrust.net					\
	repo1.secomtrust.net						\
	scrootca2.ocsp.secomtrust.net					\
	repository.secomtrust.net					\
	wpad.tottori-u.ac.jp						\
	"
filename=ipaddrs.txt

#
tmpfile=$filname.tmp
interval=300
expiry=864000

log()
{

	echo `date '+%Y/%m/%d %H:%M:%S'` "$1"
}

resolve()
{
	hostname=$1

	host $hostname | sed -rn 's/^.* has address ([0-9.]+)$/\1/p'
}

add()
{
	ia=$1
	hostname=$2
	time=$3

	if ! remove $ia $hostname 'no'; then
		log "add $hostname ($ia) $time"
		r=0
	else
		r=1
	fi
	echo "$ia $hostname $time" >> $filename
	return $r
}

remove()
{
	ia=$1
	hostname=$2
	removeonly=$3

	[ ! -e $filename ] && return
	if [ "$removeonly" = 'yes' ]; then
		log "Remove $hostname ($ia)"
	fi
	grep "^$ia .*$" $filename > /dev/null 2>&1
	r=$?
	if [ $r -eq 0 ]; then
		grep -v "^$ia .*$" $filename > $tmpfile
		mv $tmpfile $filename
	fi
	return $r
}

expire()
{
	now=$1
	expiry=$2

	while read ia hostname lasttime; do
		diff=`expr $now - $lasttime`
		if [ $diff -gt $expiry ]; then
			remove $ia $hostname 'yes'
		fi
	done < $filename
}

log 'Started'
while true; do
	changed=no
	now=`date +%s`
	for h in $hostnames; do
		for ia in `resolve $h`; do
			if add "$ia" "$h" "$now"; then
				changed=yes
			fi
		done
	done
	expire $now $expiry
	if [ "$changed" = 'yes' ]; then
		ruby wiredlanauth-filter-sync.rb
	fi
	sleep $interval
done
