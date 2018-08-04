module Aruba
	CONFIG_RE = /^Building Configuration...[^a-zA-Z]+(.*end\n)$/m

	def disable_logging_console
		# XXX
	end

	def show_running_config
		return cmd('show running-config')
	end

	def interface_gets(sw)
		# XXX
	end
end
