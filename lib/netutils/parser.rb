require 'netutils/fsm'

class Parser < FSM
	def initialize
		super
		@regexp = Array.new
	end

	def add(sname, cb, regexp = nil)
		super(sname, cb)
		@regexp.push(regexp)
	end

	def regexp
		r = @regexp[@state]
		r = /^.*$/ if r == nil
		return r
	end

	def parse(buf)
		buf.each_line do |l|
			unless l.chomp! =~ regexp
				raise(ArgumentError,
				    "No match at #{state_name}: \"#{l}\" " +
				    "to #{regexp.to_s}")
			end
			send(cb, l, $~)
		end
	end
end
