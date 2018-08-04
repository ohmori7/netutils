require 'netutils/parser'

module Cisco

class IfSummary < Parser
	def cmd
		'show interfaces summary'
	end

	def initialize(sw)
		super()
		add('Init',		:init)
		add('Interface',	:interface)
		@sw = sw
	end

	def init(l, m)
		changeto('Interface') if l =~ /^-+$/
	end

	def interface(l, m)
		return unless l =~ /^(.) ([^ ]+) +.*$/
		up = $1
		name = $2
		return if name =~ /Port-channel/
		return if name =~ /Vlan/
		return if ! @sw.ports.exists?(name)
		@sw.ports[name].up = up == '*' ? true : false
	end
end

end
