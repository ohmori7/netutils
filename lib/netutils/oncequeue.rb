class OnceQueue
	def initialize
		@element = []
		@queue = []
		@mutex = Thread::Mutex.new
		@cond = Thread::ConditionVariable.new
		@empty = Thread::ConditionVariable.new
		@processing = 0
		@total = 0
		@errors = 0
	end

	def __count
		@queue.size + @processing
	end
	private :__count

	def count
		@mutex.synchronize do
			__count
		end
	end

	def total
		@mutex.synchronize do
			@total
		end
	end

	def errors
		@mutex.synchronize do
			@errors
		end
	end

	def enqueue(v)
		@mutex.synchronize do
			break if @element.include?(v)
			@element.push(v)
			@queue.push(v)
			@cond.signal
		end
	end

	def dequeue
		@mutex.synchronize do
			@cond.wait(@mutex) while @queue.empty?
			@processing += 1
 			@queue.shift
		end
	end

	def done(v)
		@mutex.synchronize do
			@processing -= 1
			@empty.signal if __count === 0
			@total += 1
		end
	end

	def error
		@mutex.synchronize do
			@errors += 1
		end
	end

	def synchronize
		@mutex.synchronize do
			yield
		end
	end

	def wait_all
		@mutex.synchronize do
			@empty.wait(@mutex) if __count > 0
		end
	end
end
