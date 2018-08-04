module NEC

# IX series does not have LLDP and this is dummy class.
class LLDP
	def cmd(port)
		''
	end

	def initialize(sw)
	end

	def parse(l)
	end
end

end
