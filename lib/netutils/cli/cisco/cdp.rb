require 'lib/parser'

module Cisco

class CDP < Parser
	def cmd(port = nil)
		port = "#{port} " if port
		return "show cdp neighbors #{port}detail"
	end

	attr_reader :rsw, :ias	# XXX
	def initialize(sw)
		super()
		add('Init',		:init)
		add('DeviceID',		:device_id,	/^Device ID: (.*)$/)
		add('EntryAddrs',	:entry_addrs,
		    /^Entry address\(es\): $/)
		add('EntryAddr',	:entry_addr)
		add('Interface',	:interface,
		    /^Interface: (.*),  Port ID \(outgoing port\): (.*)$/)
		add('Ignore',		:ignore)
		add('Firmware',		:firmware)
		add('MngAddr',		:mng_addr)

		@sw = sw
	end

	private

	def init(l, m)
		return unless l =~ /^-{25}$/
		@rdevid = nil
		@ias = Array.new
		@platform = nil
		@lport = nil
		@rport = nil
		@firmware = ''
		@mngias = Array.new
		@type = Switch::Type::UNKNOWN
		changeto('DeviceID')
	end

	def device_id(l, m)
		@rdevid = m[1]
		changeto('EntryAddrs')
	end

	def entry_addrs(l, m)
		changeto('EntryAddr')
	end

	def entry_addr(l, m)
		unless l =~ /^ +[^:]+: (.*)$/
			platform(l)
		else
			@ias.push($1)
		end
	end

	def platform(l)
		unless l =~ /^Platform: ([^,]+),  Capabilities: (.*)$/
			raise(ArgumentError)
		end
		@platform = $1.strip
		cap = $2
		if cap =~ /Router/
			@type = Switch::Type::ROUTER
		elsif cap =~ /Switch/
			@type = Switch::Type::SWITCH
		elsif cap =~ /Trans-Bridge/
			@type = Switch::Type::BRIDGE
		elsif cap =~ /Host/
			@type = Switch::Type::HOST
		end
		changeto('Interface')
	end

	def interface(l, m)
		@lport = m[1]
		@rport = m[2]
		changeto('Ignore')
	end

	def ignore(l, m)
		changeto('Firmware') if l =~ /^Version :$/
		changeto('MngAddr') if l =~ /^Management address\(es\): $/
	end

	def firmware(l, m)
		if l =~ /^advertisement version: .*$/
			@firmware.strip!
			changeto('Ignore')
		else
			@firmware += l
		end
	end

	def mng_addr(l, m)
		if l=~ /^  [^:]+: (.*)$/
			@mngias.push($1)
		else
			ia = @mngias[0]
			ia = @ias[0] if ia == nil
			if @firmware =~ /^.*Copyright \(c\) .*([0-9]{4}) .*$/
				time = $1
			else
				time = 'unknown'
			end
			@rsw = Switch.get(@rdevid, @type, @platform, @firmware,
			    time, ia)
			@sw.ports[@lport].peers.add(@rsw, @rport)
			changeto('Init')
		end
	end
end

end
