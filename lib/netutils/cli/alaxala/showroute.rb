require 'lib/parser'
require 'lib/rib'

module Alaxala

class ShowRoute < Parser
	attr_reader :rib

	def cmd(ia)
		"show ip route vrf all #{ia}"
	end

	def initialize
		@rib = RIB.new
		super
		# Route 10/8 , VRF 2
		add('Init',	:init)
		# AX8600
		# Entries 1
		# AX3600
		# Entries 1 Announced 1 Depth 0 <>
		add('Entries',	:entries, /^Entries [0-9]+.*$/)
		# empty line
		add('Empty',	:empty, /^$/)
		# * NextHop 192.168.0.1    , Interface   : VLAN9999
		add('Nexthop',	:nexthop, /^..NextHop ([^\s]+)\s*, Interface\s*: ([^\s]+)\s*$/)
		#     Protocol <OSPF inter>
		add('Protocol',	:protocol, /^     Protocol <([^>]+)>/)
		#
		add('Skip',	:skip)
	end

	def init(l, m)
		return if l =~ /^$/
		return if l !~ /^Route ([0-9\.\/]+)\s*, VRF ([0-9]+|global)$/
		@dst = $1
		@vrf = $1
		changeto('Entries')
	end

	def entries(l, m)
		changeto('Empty')
	end

	def empty(l, m)
		changeto('Nexthop')
	end

	def nexthop(l, m)
		@nh = m[1]
		@interface = m[2]
		#
		# remove mediate ``0''s because Alaxala CLI may to accept such 
		# interface name like ``VLAN0999.''
		#
		@interface = "#{$1}#{$2}" if @interface =~ /^([^0-9]+)0+([0-9]+)$/
		changeto('Protocol')
	end

	def protocol(l, m)
		case m[1]
		when /^Static/
			@protocol = 'static'
		when /^Connected/
			@protocol = 'connected'
		when /^RIP/
			@protocol = 'rip'
		when /^OSPF/
			@protocol = 'ospf'
		when /^BGP/
			@protocol = 'bgp'
		when /^Extra-VRF/
			@protocol = 'extranet'
		else
			raise(ArgumentError, "Invalid routing protocol: #{m[1]}")
		end
		@rib.add(@protocol, @dst, @nh, @interface)
		changeto('Skip')
	end

	def skip(l, m)
		changeto('Init') if l =~ /^$/
	end
end

end
