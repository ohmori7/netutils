require 'ipaddr'

class RIB
	class Route
		attr_reader :proto, :dst, :prefixlen, :nh, :interface

		def initialize(proto, dst, nh, interface)
			dst = ip_address_normalize(dst)
			@proto     = proto
			@dst       = dst
			@prefixlen = prefixlen_get(dst)
			@nh        = nh
			@interface = interface
		end

		def prefixlen_get(dst)
			return dst.split('/')[1].to_i
		end
		private :prefixlen_get

		def ip_address_normalize(dst)
			# XXX IPv4 dependent...
			n = dst.count('.')
			case n
			when 0, 1, 2
				ia = dst.split('/')[0]
				for i in 1..3 - n do
					ia += '.0'
				end
				dst = "#{ia}/#{prefixlen_get(dst)}"
			when 3
			else
				raise(ArgumentError,
				    "Invalid IP address: #{dst}")
			end
			return dst
		end
		private :ip_address_normalize

		def tunnel?
			@interface =~ /^[tT]unnel/
		end

		def compare(other)
			return self if ! other
			if defined?(PREFERRED_NEXTHOPS)
				PREFERRED_NEXTHOPS.each do |prefix|
					ir = IPAddr.new(prefix)
					if ir.include?(@nh) &&
					    ! ir.include?(other.nh)
						return self
					elsif ! ir.include?(@nh) &&
					    ir.include?(other.nh)
						return other
					end
				end
			end
			return other if @prefixlen < other.prefixlen
			return self
		end
	end

	def initialize
		@rib = []
	end

	def add(proto, dst, nh, interface)
		@rib.push(Route.new(proto, dst, nh, interface))
	end

	def get(dst, proto = nil)
		m = []
		@rib.each do |r|
			next if proto && r.proto != proto
			m.push(r) if IPAddr.new(r.dst).include?(dst)
		end
		return nil if m.empty?
		return m
	end
end
