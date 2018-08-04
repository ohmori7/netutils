class FSM
	class State
		attr_reader :cb

		def initialize(cb)
			@cb = cb
		end
	end

	FSM_S_INIT = 0

	def initialize
		@state = FSM_S_INIT
		@fsm = Array.new
		@name2index = Hash.new
		@index2name = Array.new
	end

	def add(name, cb)
		if @name2index.key?(name)
			raise(ArgumentError, "duplicated key \"#{name}\"")
		end
		@fsm.push(State.new(cb))
		idx = @fsm.length - 1
		@name2index[name] = idx
		@index2name[idx]  = name
	end

	def cb
		return @fsm[@state].cb
	end

	def changeto(name)
		if ! @name2index.key?(name)
			raise(ArgumentError, "unnown state: \"#{name}\"")
		end
		@state = @name2index[name]
	end

	def state_name
		return @index2name[@state]
	end
end
