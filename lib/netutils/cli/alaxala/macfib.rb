require 'netutils/parser'
require 'netutils/macaddr'

module Alaxala

class MACFIB < Parser
	attr_reader :ports

	#
	# Date 2017/10/15 08:24:22 JST
	# Aging time : 300
	# MAC address        VLAN    Type     Port-list
	# dead.beef.dead     9999    Dynamic  0/26-27
	#
	AX2000_RE = /^[0-9a-z.]+\s+[0-9]+\s+[^\s]+\s+([0-9\/,\-]+)$/

	# Date 2017/10/14 19:39:20 JST
	# MAC address        VLAN C-Tag    Aging-Time Type     Port-list
	# dead.beef.dead     9999     -           479 Dynamic  7/5,11/5
	AX8600_RE = /^[0-9a-z.]+\s+[0-9]+\s+[^\s]+\s+[0-9]+\s+[^\s]+\s+([0-9\/,\-]+)$/

	def cmd(ma, vlan)
		mac = "mac " if @sw.product =~ /^AX2[0-9]{2,3}/
		return "show mac-address-table #{mac}#{ma.to_s} vlan #{vlan}"
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
		when AX2000_RE, AX8600_RE
			$1.split(',').each do |port|
				port, last = port.split('-')
				if port =~ /^(.*\/)([0-9]+)$/
					prefix = $1
					first = $2.to_i
				else
					raise(ArgumentError,
					    "Unknown port name format: #{port}")
				end
				if last
					last = last.to_i
				else
					last = first
				end
				for i in first .. last do
					name = prefix + i.to_s
					name = @sw.interface_name(name)
					@ports[name] = name
				end
			end
		end
	end
end

end
