require 'lib/parser'
require 'lib/arp'

module Alaxala

class ShowARP < Parser
	attr_reader :arps

	def initialize
		@arps = ARPTable.new
		super
		# Date 2017/10/05 21:30:53 JST
		add('Init',	:init, 	/^Date/)
		# VRF: 1 Total: 946 entries
		add('VRF',	:vrf, 	/^VRF/)
		#  IP Address       Linklayer Address  Netif             Expire     Type
		add('Title',	:title,	/^(?: IP Address       Linklayer Address  Netif             Expire     Type|There is no ARP entry.)/)
		# 192.168.0.1      dead.beaf.dead     VLAN9999          4m58s      arpa
		add('Entry',	:entry, /^\s+([0-9\.]+)\s+([0-9a-f\.]+|\(incomplete\))\s+([^\s]+)\s+([^\s]+).*$/)
	end

	def init(l, m)
		# XXX: VRF appears if and only if an IP address is given.
		#changeto('VRF')
		changeto('Title')
	end

	def vrf(l, m)
		changeto('Title')
	end

	def title(l, m)
		changeto('Entry')
	end

	def entry(l, m)
		#
		# remove mediate ``0''s because Alaxala CLI may to accept such 
		# interface name like ``VLAN0620.''
		#
		if m[3] =~ /^([^0-9]+)0+([0-9]+)$/
			interface = "#{$1}#{$2}"
		else
			interface = m[3]
		end
		return if m[2] === '(incomplete)'
		@arps.add(m[1], m[2].downcase, interface, m[4] === 'Static')
	end
end

end
