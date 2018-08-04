require 'netutils/cli/cisco/interface'
require 'netutils/cli/cisco/cdp'
require 'netutils/cli/cisco/macfib'
require 'netutils/cli/cisco/showarp'
require 'netutils/cli/cisco/showroute'
require 'netutils/cli/cisco/showvrf'

module Cisco
	CONFIG_RE = /^.*Current configuration[^\n]+\n(.*)\n.*$/m

	def disable_logging_console
		configure
		cmd('no loggin console')
		unconfigure
	end

	def acl_definition(type, name)
		case type
		when 'ip'
		when 'mac'
			"#{type} access-list extended #{name}"
		else
			raise(ArgumentError, "Unsupported ACL type: #{type}")
		end
	end

	def acl_type_to_cmd(type)
		case type
		when 'ip'
		when 'mac'
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
end
