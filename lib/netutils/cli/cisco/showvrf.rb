require 'lib/parser'
require 'lib/vrf'

module Cisco

class ShowVRF < Parser
	attr_reader :vrfs

	def cmd
		return 'show vrf'
	end

	def initialize
		super()
		@vrfs = VRFTable.new
		add('Init',		:init)
		add('VRF',		:vrf)
		add('Interface',	:interface)
	end

	def init(l, m)
		return if l !~ /^ +Name +Default RD +Protocols +Interfaces$/
		changeto('VRF')
	end

	def vrf(l, m)
		if l !~ /^ *([^ ]+) +([^ ]+|<not set>) +[^ ]+ +([^ ]+) *$/ &&
		   l !~ /^ *([^ ]+) +([^ ]+|<not set>) +[^ ]+ *$/
			raise(ArgumentError, "Invalid line: \"#{l}\"")
		end
		@vrf = vrfs.add($1, $2)
		@vrf.interface_add($3) if $3
		changeto('Interface')
	end

	def interface(l, m)
		if l =~ /^ +([^ ]+) *$/
			@vrf.interface_add(m[1])
		else
			vrf(l, nil)
		end
	end
end

end
