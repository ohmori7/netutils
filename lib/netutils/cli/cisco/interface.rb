require 'netutils/parser'

module Cisco

class Interface < Parser
	def cmd
		return 'show interfaces capabilities'
	end

	def initialize(sw)
		super()
		add('Init',	:init)
		add('Name',	:name,	/^ +Model: +(.+)$/)
		add('Model',	:model,	/^ +Type: +(.+)$/)
		add('Type',	:type)
		add('Speed',	:speed,	/^ +Duplex: +(.+)$/)
		@sw = sw
	end

	private

	def init(l, m)
		return unless l =~ /^([^ ]+)$/
		@name = $1
		@model = nil
		@type = nil
		@speed = nil
		@duplex = nil
		changeto('Name')
	end

	def name(l, m)
		@model = m[1]
		changeto('Model')
	end

	def model(l, m)
		@type = m[1]
		changeto('Type')
	end

	def type(l, m)
		if l =~ /^ +Speed: +(.+)$/
			@speed = m[1]
			changeto('Speed')
		else
			@speed = 'unknown'
			done
		end
	end

	def speed(l, m)
		@duplex = m[1]
		done
	end

	def done
		changeto('Init')
		return if @model === 'not applicable'	# port-channel
		return if @model === 'N/A'		# port-channel
		return if @type === 'WiSM'
		return if @type === 'unknown'		# port-channel
		@sw.ports.add(@name, @model, @type, @speed, @duplex)
	end
end

end
