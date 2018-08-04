require 'lib/macaddr'

class ARPTable
	class ARP
		attr_reader :ia, :ma, :interface, :static

		def initialize(ia, ma, interface, static)
			@ia = ia
			@ma = MACAddr.new(ma)
			@interface = interface
			@static = static
		end
	end

	attr_reader :arps

	def initialize
		@arps = {}
	end

	def add(ia, ma, interface, static)
		@arps[ia] = ARP.new(ia, ma, interface, static)
	end

	def [](ia)
		return @arps[ia]
	end
end
