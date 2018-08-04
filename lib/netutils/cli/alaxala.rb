require 'lib/cli/alaxala/interface'
require 'lib/cli/alaxala/lldp'
require 'lib/cli/alaxala/macfib'
require 'lib/cli/alaxala/showarp'
require 'lib/cli/alaxala/showroute'
require 'lib/cli/alaxala/showvrf'

module Alaxala
	CONFIG_RE = /\A((?:#configuration list for [^\n]+|#Last modified [^\n]+)\n.*)\n\Z/m

	def disable_logging_console
		case @product
		when /^AX86[0-9]{2}/
			# AX8600
			configure
			cmd('username default_user logging-console event-level 0')
			unconfigure
		when /^AX22[0-9]{2}/
			# XXX: AX2230 seems not to have set logging commands...
		when /^AX[23][0-9]{2,3}/
			# AX3800, AX3600, AX2500, AX260
			for level in 3..9
				cmd("set logging console disable E#{level}")
			end
		end
	end

	def interface_name(sw, name)
		if name =~ /^Port\s+(.*)$/i
			name = $1
		elsif name =~ /^[^\s0-9]/
			return name
		end
		numbers = name.delete(' ').split('/')
		sw.ports.each do |port|
			return port.name.to_s if port.name.numbers == numbers
			if sw.product =~ /^AX3[0-9]{3}/ &&
			   port.name.numbers.size === 3 &&
			   numbers.size === 2 &&
			   port.name.numbers.drop(1) == numbers
				return port.name.to_s
			end
		end
		nil
	end

	def interface_name_cli(name)
		name.split(' ')[1]
	end

	def unconfigure
		cmd('save')
		super
	end

	#
	# XXX: forcely override method because Alaxala
	#      interface command accept lower case characters only...
	#      e.g., GigabitEthernet should be gigabitethernet...
	#
	def interface_name_interface_command(port)
		port.downcase
	end
	private :interface_name_interface_command

	def interface_shutdown(port)
		super(interface_name_interface_command(port))
	end

	def interface_noshutdown(port)
		super(interface_name_interface_command(port))
	end

	def acl_definition(type, name)
		case type
		when 'ip'
		when 'mac'
			"#{type} access-list extended #{name}"
		when 'advance'	# XXX: AX8600 only
			"#{type} access-list #{name}"
		else
			raise(ArgumentError, "Unsupported ACL type: #{type}")
		end
	end

	def acl_type_to_cmd(type)
		case type
		when 'ip'
		when 'mac'
		when 'advance'	# XXX: AX8600 only
			#
			# we here use only ``mac'' even though mac-ip and
			# mac-ipv6 are available.
			# 
			type = 'mac'
		else
			raise(ArgumentError, "Unsupported ACL type: #{type}")
		end
		type
	end

	def show_running_config
		return cmd('show running-config')
	end

	def syslog(host, vrf = 1)
		configure
		case @product
		when /^AX86[0-9]{2}/
			# AX8600
			cmd("logging syslog-host #{host} vrf #{vrf} no-date-info")
		when /^AX(?:25[0-9]{2}|3[0-9]{3})/
			# AX2500, AX3000
			cmd("logging host #{host} no-date-info")
		when /^AX22[0-9]{2}/
			# AX2230
			cmd("logging host #{host}")
		end
		unconfigure
	end
end
