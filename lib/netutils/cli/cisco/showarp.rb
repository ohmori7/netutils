require 'netutils/parser'
require 'netutils/arp'

module Cisco

class ShowARP < Parser
	attr_reader :arps

	def initialize
		@arps = ARPTable.new
		super()
		add('Init',	:init)
		# Protocol  Address          Age (min)  Hardware Addr   Type   Interface
		# Internet  192.168.0.1             3   dead.beef.dead  ARPA   Vlan9999
		add('Entry',	:entry, /^Internet +([^ ]+) +([0-9]+|-) +([^ ]+) +ARPA+ +([^ ]+)$/)
	end

	def init(l, m)
		changeto('Entry') if l =~ /^Protocol/
	end

	def entry(l, m)
		@arps.add(m[1], m[3], m[4], m[2] === '-')
	end
end

end
