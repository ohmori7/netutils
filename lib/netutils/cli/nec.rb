require 'netutils/cli/nec/lldp'

module NEC
	CONFIG_RE = /^(.*\n)$/m

	def disable_logging_console
		# XXX
	end

	def enable
	end

	def show_running_config
		return cmd('show running-config')
	end

	def interface_gets(sw)
		# XXX
	end
end
