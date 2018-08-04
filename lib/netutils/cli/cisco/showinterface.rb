require 'lib/parser'
require 'lib/tunnel'

module Cisco

class ShowInterface < Parser
	attr_reader :tunnel

	def initialize
		super()
		add('Init',	:init)
		add('Done',	:done)
	end

	def init(l, m)
		# Tunnel source 192.168.0.1 (Dialer1), destination 192.168.0.2
		if l =~ /^  Tunnel source ([^ ]+) [^,]+, destination ([^ ]+)/
			@tunnel = Tunnel.new($1, $2)
			changeto('Done')
		end
	end

	def done(l, m)
	end
end

end
