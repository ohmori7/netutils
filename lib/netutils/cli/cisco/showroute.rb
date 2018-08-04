require 'netutils/parser'
require 'netutils/rib'

module Cisco

class ShowRoute < Parser
	attr_reader :rib

	def cmd(ia)
		"show ip route vrf \* #{ia}"
	end

	def initialize
		@rib = RIB.new
		super
		# % Network not in table
		# Routing entry for 192.168.0.0/24
		add('Init',	:init)
  		#   Known via "connected", distance 0, metric 0 (connected, via interface)
		add('Protocol',	:protocol, /  Known via "([^"]+)",.*$/)
		add('Descriptor',	:descriptor)
		#   * 192.168.0.200
  		#   * directly connected, via Vlan4000
		#   * 192.168.0.1, from 192.168.0.1, 00:00:19 ago, via Vlan9999
		add('Nexthop',	:nexthop, /^  \* ([^ ,]+)(?:,? .*, via ([^ ]+)|)$/)
      		#       Route metric is 0, traffic share count is 1
		add('Metric',	:metric, /^      Route metric is .*$/)
	end

	def init(l, m)
		return if l =~ /^% .* not in table/
		return if l =~ /^$/
		if l !~ /^Routing entry for ([0-9\.\/]+)(?:, supernet)?$/
			raise "Invalid format: #{l}"
		end
		@dst = $1
		changeto('Protocol')
	end

	def protocol(l, m)
		@protocol = m[1]
		changeto('Descriptor')
	end

	def descriptor(l, m)
  		#   Routing Descriptor Blocks:
		case l
		when /^  Routing Descriptor Blocks:$/
			changeto('Nexthop')
		when /^  Redistributing via /, /^  Advertised by /
		end
	end

	def nexthop(l, m)
		case m[1]
		when 'directly'
			@nh = nil
		when /[0-9\.\/]+/
			@nh = m[1]
		else
			raise "Invalid format: #{l}"
		end
		@interface = m[2]
		changeto('Metric')
	end

	def metric(l, m)
		@rib.add(@protocol, @dst, @nh, @interface)
		changeto('Init')
	end
end

end
