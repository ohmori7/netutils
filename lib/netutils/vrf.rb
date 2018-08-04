class VRFTable
	include Enumerable
	class VRF
		attr_reader :name, :rd, :interfaces
		def initialize(name, rd)
			@name  = name
			@rd    = rd if rd =~ /[0-9]+:[0-9]/
			@interfaces = []
		end

		def interface_add(ifname)
			@interfaces.push(ifname)
		end

		def to_s
			return "#{@name} (#{@rd})"
		end
	end

	def initialize
		@table = {}
	end

	def add(name, rd)
		vrf = VRF.new(name, rd)
		@table[name] = vrf
		return vrf
	end

	def [](name)
		return @table[name]
	end
	private :[]

	def empty?
		@table.empty?
	end

	def each
		@table.each { |vrf| yield vrf }
	end
end
