require 'lib/parser'
require 'lib/macaddr'

module Cisco

class MACFIB < Parser
	attr_reader :ports

	# XXX
	# * 2005  082e.5f24.56a9   dynamic  Yes          0   Po19
	CISCO6500_RE = /^\* +[0-9]+ +[^ ]+ +dynamic +Yes +[0-9]+ +([^ ]+)$/
	# 3188    f80f.41d2.e746   dynamic ip,(cut),other TenGigabitEthernet1/1 
	CISCO4500_RE = /^ *[0-9]+ +[^ ]+ +dynamic +ip[^ ]+ +([^ ]+) +$/
	#  100    0016.c8c5.35a2    DYNAMIC     Po1
	CISCO2500_RE = /^ *[0-9]+ +[^ ]+ +(?:STATIC|DYNAMIC) +([^ ]+).*$/

	def cmd(ma, vlan)
		return "show mac address-table address #{ma.to_s} vlan #{vlan}"
	end

	def initialize(sw)
		@ports = {}
		super()
		add('Init',	:init)
		@sw = sw
	end

	def init(l, m)
		case l
		# XXX: other switches...
		when CISCO6500_RE, CISCO4500_RE, CISCO2500_RE
			name = @sw.ports.key($1)
			@ports[name] = name
		end
	end
end

end
