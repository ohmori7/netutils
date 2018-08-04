require 'netutils/parser'
require 'netutils/vrf'

module Alaxala

class ShowVRF < Parser
	attr_reader :vrfs

	DUMMY_RD = '0:0'	# XXX: Alaxala do not have RD...

	def cmd
		# XXX: we do not use interfaces for now...
		return 'show ip vrf all'
	end

	def initialize
		super
		@vrfs = VRFTable.new
		# Date 2017/10/05 21:11:51 JST
		add('Init',		:init,	/^Date/)
		# VRF              Routes          ARP
		add('Title',		:title,	/^VRF/)
		# global           7/-             0/-            
		# 1                235/-           949/-          
		add('VRF',		:vrf)
	end

	def init(l, m)
		changeto('Title')
	end

	def title(l, m)
		changeto('VRF')
	end

	def vrf(l, m)
		if l !~ /^(global|[0-9]+)\s+.*$/
			raise(ArgumentError, "Invalid line: \"#{l}\"")
		end
		name = $1
		name = 'default' if name === 'global'
		@vrf = vrfs.add(name, DUMMY_RD)
	end
end

end
