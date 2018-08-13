require 'netutils/parser'
require 'netutils/switch'

module Alaxala

class LLDP < Parser
	def cmd(port)
		if port
			port = @sw.interface_name_cli(port)
			# XXX: how about stack configuration...
			if @sw.product =~ /^AX3[0-9]{3}/
				numbers = port.split('/')
				if numbers.size != 3
					raise "Invalid port format: #{numbers}"
				end
				port = "#{numbers[1]}/#{numbers[2]}"
			end
			port = "port #{port} "
		end
		return "show lldp #{port}detail"
	end

	# Date 2017/10/15 00:06:36 JST
	# Status: Enabled     Chassis ID: Type=MAC          Info=beef.dad.beef
	# Interval Time: 30       Hold Count: 4     TTL: 121      Draft TTL: 120  
	# System Name: hogehoge
	# System Description: ALAXALA AX8600S AX-8600-S16 [AX8616S] Switching software (including encryption) Ver. 12.7.B [OS-SE]
	# Neighbor Counts=1
	# Draft Neighbor Counts=0
	# Port Counts=1
	# Port  1/ 1(CH:  1)
	#   Link: Up      PortEnabled: TRUE     AdminStatus: enabledRxTx
	#   Neighbor Counts:   1    Draft Neighbor Counts:   0
	#   Port ID: Type=MAC          Info=beef.dead.beef
	#   Port Description: hogehoge
	#   Neighbor 1      TTL: 95   
	#     Chassis ID: Type=MAC          Info=dead.beef.dead
	#     System Name: fugafuga
	#     System Description: ALAXALA AX2530 AX-2530-48T2X-B [AX2530S-48T2X] Switching software Ver. 4.6.A [OS-L2B]
	#     Port ID: Type=MAC          Info=dead.beef.dead
	#     Port Description: hogehoge

	attr_reader :rsw
	def initialize(sw)
		super()
		add('Init',		:init)
		add('Port',		:port)
		add('PortInfo',		:port_info)
		add('ChassisID',	:chassis_id,	/^    Chassis ID: Type=[^\s]+ \s+Info=[0-9a-z.]+$/)
		add('SystemName',	:system_name,	/^\s{4,6}System Name: ([^\s]+)$/)
		add('SystemDescription',:system_description,	/^\s{4,6}System Description: (.*)$/)
		add('PortID',		:port_id)
		add('PortDescription',	:port_description,	/^\s{4,6}Port Description: .*$/)
		add('TagID',		:tag_id)
		@sw = sw
	end

	private

	def init(l, m)
		changeto('Port') if l =~ /^Port Counts.*$/
	end

	def port(l, m)
		raise 'Invalid format' if l !~ /^Port\s+([0-9\s\/]+).*$/
		@lport = @sw.interface_name($1)
		changeto('PortInfo')
	end

	def port_info(l, m)
		if l =~ /^  (?:Draft Neighbor|Neighbor)\s+[0-9]+\s+TTL: [0-9]+\s*.*$/
			neighbor(l, m)
		elsif l =~ /^  [0-9]+\s+TTL:\s*[0-9]+\s+Chassis ID: Type=[^\s]+\s+Info=[0-9a-z.]+$/
			neighbor_ax3000(l, m)
		elsif l =~ /^Port/
			port(l, m)
		else
		end
	end

	def neighbor(l, m)
		@rname = nil
		changeto('ChassisID')
	end

	def neighbor_ax3000(l, m)
		@rname = nil
		changeto('SystemName')
	end

	def chassis_id(l, m)
		changeto('SystemName')
	end

	def system_name(l, m)
		@rname = m[1]
		changeto('SystemDescription')
	end

	def system_description(l, m)
		desc = m[1]
		case desc
		when /^(ALAXALA.*) Switching software Ver. (.*)$/
			platform = $1
			firmware = $2
		else
			platform = desc
			firmware = nil
		end
		case platform
		when /Cisco*/,
		     /^ALAXALA AX[87643]/, /ALAXALA AX2[0-9]{2}[^0-9]/
			type = Switch::Type::ROUTER
		when /^ALAXALA AX[12][0-9]{3}[^0-9]/
			type = Switch::Type::SWITCH
#		elsif  /XXX/
#			type = Switch::Type::BRIDGE
		else
			type = Switch::Type::HOST
		end
		neighbor_add(@lport, @rname, type, platform, firmware)
		changeto('PortID')
	end

	def port_id(l, m)
		# XXX: this may be left system description.
		return if l !~ /^\s{4,6}Port ID: Type=[^\s]+ \s+Info=.*+$/
		changeto('PortDescription')
	end

	def port_description(l, m)
		changeto('TagID')
	end

	def tag_id(l, m)
		case l
		when /^Port+/
			if ! @rsw.ia
				raise "no IP address found for #{@rsw.name} "
				    "on #{@sw.name} #{@lport}"
			end
			port(l, m)
		when /^  [^\s]+/
			port_info(l, m)
		when /^\s{4,6}Tag ID: .*$/
			return
		when /^\s{4,6}IPv4 Address: (?:Untagged|Tagged:\s+[0-9]+)\s+([0-9.]+)$/,
		     /^\s{4,6}Management Address:\s+([0-9.]+)$/
			@rsw.ip_address_set($1)
		end
	end

	def neighbor_add(lport, rname, type, platform, firmware)
		# XXX: this is valid for cisco only...
		if firmware =~ /^.*Copyright \(c\) .*([0-9]{4}) .*$/
			time = $1
		else
			time = 'unknown'
		end
		static_neighbor_resolve(@sw, lport)
		@rsw = Switch.get(rname, type, platform, firmware, time)
		@sw.ports[lport].peers.add(@rsw, nil) # XXX: no way to know remote port...
	end
end

end
