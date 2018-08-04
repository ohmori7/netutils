#
# possible usernames, login passwords and enable passwords.
#
USERS = [
	'hogehoge',
	'fugafuga',
	'bakeratta',
	]
PASSWORDS = [
	'secret1',
	'secret2',
	'secret3',
	]
ENABLES = [
	'secret4',
	'secret5',
	'secret6',
	]

#
# Logging directory to which debug messages go.
#
LOGDIR = 'log'

#
# List of CLI session types.  SSH or telnet or both of them must be specified.
#
CLI_SESSION_TYPES = [ :ssh, :telnet ]

#
# pairs of a host name of core switch and IP address.
#
SWITCHES = [
	# Koyama
	[ 'koyama-c01', 	'10.0.0.1' ],
	# Yonago
	[ 'yonago-c01', 	'10.100.0.1' ],
	# Dry land
	[ 'hamasaka-c01',	'10.200.0.1' ],
	]

#
# Mail notification configurations.
#
MAILFROM = 'example@example.tottori-u.ac.jp'
MAILTO = 'example@example.tottori-u.ac.jp'
MAILSERVER = 'example.tottori-u.ac.jp'

#
# List of neighbors that cannot run both of LLDP and CDP.
#
STATIC_NEIGHBOR = {
	#
	# XXX: Special hack for AX3800
	# XXX: AX3800 cannot run LLDP with stack configuration...
	#
	'koyama-c01_TenGigabitEthernet 1/1' =>
	    { name: 'koyama-me2f-sw1', ia: '192.168.0.1' },
}

#
# Preferred L3 nexthops when connecting to neighboring routers.
#
PREFERRED_NEXTHOPS = [
	'192.168.0.0/24',	# Koyama
	'192.168.1.0/24',	# Yonago
]

#
# List of nexthop routers that are out of scope of our operations.
#
OTHER_NEXTHOPS = [
	'192.168.0.1',
	]

#
# List of VLAN IDs to filter out a MAC address.
# XXX: will be deprecated.
#
VLANS = {
	# KOYAMA
	'koyama-c01' => [ 100, 200, ],
	# YONAGO
	'yonago-c01' => [ 1000, 2000, ],
}

#
# FTP server and Web authentication server for ``alaxala-deploy'' script.
# XXX: should be moved to other place???
#
FTP_SERVER = '10.0.1.1'
WEBAUTH_HOST = 'webauth.example.tottori-u.ac.jp'
