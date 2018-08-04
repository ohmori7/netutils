module Paloalto
	CONFIG_RE = /^(config {\n(?:[^\n]+\n){1,}}\n)\n\Z/

	def disable_logging_console
		# XXX
	end

	def enable
	end

	def disable
	end

	def show_running_config
		return cmd('show config running')
	end

	def interface_gets(sw)
		# XXX
	end
end
