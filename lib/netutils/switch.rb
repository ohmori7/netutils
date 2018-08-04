require 'netutils/cli'
require 'netutils/oncequeue'

class Switch
	module Type
		ROUTER	= 1
		SWITCH	= 2
		BRIDGE	= 3
		HOST	= 4
		UNKNOWN	= 5
	end

	class PortName
		MAX_ARGS = 3

		attr_reader :numbers

		def initialize(name)
			if name =~ /^([^0-9]+)([0-9]?.*)/
				@type = $1.strip
				@numbers = $2.split('/')
			else
				@type = name.strip
				@numbers = Array.new
			end
		end

		def to_s
			@type + ' ' + @numbers.join('/')
		end

		def to_csv
			n = @numbers.dup
			while n.length < MAX_ARGS do
				n.unshift('-')
			end
			[ @type, n ].join(',')
		end
	end

	class Peer
		attr_reader :sw, :port

		def initialize(sw, portname)
			@sw = sw
			@port = portname
		end

		def has_backlink?
			return @sw.ports.exists?(@port)
		end

		def _to_ascii(sep)
			return "#{@sw.name}#{sep}#{@port}"
		end

		def to_s
			_to_ascii(' ')
		end

		def to_csv
			_to_ascii(',')
		end
	end

	class Peers < Array
		def add(sw, portname)
			push(Peer.new(sw, portname))
		end
	end

	class Port
		attr_reader :name, :peers
		attr_accessor :up

		def initialize(name, model, type, speed, duplex)
			@name = PortName.new(name)
			@model = model
			@type = type_name(type)
			@speed = speed
			@duplex = duplex
			@peers = Peers.new
			@up = false
		end

		def type_name(type)
			type = $1 if type =~ %r{10/100/(1000BaseT).?}
			type = $1 if type =~ %r{10/(100BaseTX)}
			type = '1000BaseT' if type =~ %r{10/100/1000-T.?}
			type = $1 if type =~ /^(.*) SFP/
			type = 'none' if type =~ /^Not? .*/
			return type
		end

		def dump(p)
			up = @up? '*' : ' '
			s = sprintf "#{p}#{up}#{@name.to_s} #{@model} #{@type} "
			print s
			indent = 0
			@peers.each { |peer|
				l = peer.has_backlink? ? '<->' : '->'
				printf "% *s#{l} #{peer.to_s}\n", indent, ''
				indent = s.length
			}
			puts '' if @peers.length == 0
		end

		def dump_csv(p)
			up = @up? '*' : ' '
			printf "#{p},#{up},#{@name.to_csv},#{@type}"
			@peers.each { |peer|
				printf ",#{peer.to_csv}"
			}
			puts ''
		end
	end

	class Ports
		def initialize
			@hash = Hash.new
			@list = Array.new
		end

		def add(name, model, type, speed, duplex)
			port = Port.new(name, model, type, speed, duplex)
			@list << @hash[port.name.to_s] = port
		end

		def key(name)
			PortName.new(name).to_s
		end

		def [](name)
			return @hash[key(name)]
		end

		def exists?(name)
			return @hash.key?(key(name))
		end

		def length
			return @list.length
		end

		def each
			@list.each { |p| yield p }
		end
	end

	attr_reader :name, :type, :ports, :ia
	attr_accessor :platform, :firmware, :time

	@@retrieve_all = false
	@@db = Hash.new
	@@unretrieved = OnceQueue.new
	@@warn = Array.new

	def initialize(name, type, ia, retrieve = true)
		name_set(name)
		@type = type
		@ports = Ports.new
		@retrieve = retrieve
		@cli = nil
		ip_address_set(ia)

		return self
	end

	def name_set(name)
		raise "Already name is set: #{@name}" if @name
		@name = name
		@@db[name] = self if name
	end

	def ip_address_set(ia)
		return if ! ia
		return if @ia
		@ia = ia
		case @type
		when Type::ROUTER, Type::SWITCH
			@@unretrieved.enqueue(self) if @retrieve
		end
	end

	def login
		return if @cli
		@cli = CLI.new(@name, @ia)
		@cli.login
		name_set(@cli.name) if ! @name
		#
		# retrieve interfaces because many commands require
		# interface name.
		#
		interface_gets
	end

	def logout
		return if ! @cli
		@cli.logout
		@cli = nil
	end

	def cmd(*argv)
		@cli.cmd(*argv)
	end

	def configure
		@cli.configure
	end

	def unconfigure
		@cli.unconfigure
	end

	def exec(name, *argv)
		@cli.send(name, *argv)
	end
	private :exec

	def maker
		@cli.maker
	end

	def maker_to_s
		@cli.maker_to_s
	end

	def product
		@cli.product
	end

	def prompt
		@cli.prompt
	end

	def syslog(*arg)
		exec(__method__, *arg)
	end

	def route_gets(ia)
		exec(__method__, ia)
	end

	def vrf_gets
		exec(__method__)
	end

	def arp_resolve(ia, vrf)
		exec(__method__, ia, vrf)
	end

	def mac_address_table_get(ma, vlan)
		exec(__method__, self, ma, vlan)
	end

	def interface_gets
		raise "ERROR: cannot get interfaces twice" if @interface_got
		@interface_got = true
		exec(__method__, self)
	end

	def interface_name(name)
		exec(__method__, self, name)
	end

	def interface_name_cli(name)
		exec(__method__, name)
	end

	def interface_shutdown(port)
		exec(__method__, port)
	end

	def interface_noshutdown(port)
		exec(__method__, port)
	end

	def acl_exists?(*arg)
		exec(__method__, *arg)
	end

	def acl_add(*arg)
		exec(__method__, *arg)
	end

	def acl_delete(*arg)
		exec(__method__, *arg)
	end

	def neighbor_gets(*arg)
		exec(__method__, self, *arg)
	end

	def macaddr_resolve(ia)
		vrf_gets.each do |name, vrf|
			arp = arp_resolve(ia, vrf)
			next if ! arp
			#
			# bark here if static ARP entry is found because
			# static ARP entry may be for this system itself.
			#
			if arp.static
				raise "ERROR: Static MAC address " +
				    "found for #{ia}"
			end
			return arp.ma, vrf, arp.interface
		end
		raise "No MAC address found for #{ia}"
	end

	def self.get(name, type, platform = nil, firmware = nil, time = nil,
	    ia = nil)
		# XXX should lock
		if @@db.key?(name)
			sw = @@db[name]
			sw.platform = platform if sw.platform == nil
			sw.firmware = firmware if sw.firmware == nil
			sw.time = time if sw.time == nil
			sw.ip_address_set(ia)
		else
			sw = Switch.new(name, type, ia, @@retrieve_all)
		end
		return sw
	end

	def self.retrieve
		raise(ArgumentError, 'no user defined') if USERS.empty?
		raise(ArgumentError, 'no password defined') if PASSWORDS.empty?
		if ENABLES.empty?
			raise(ArgumentError, 'no enable password defined')
		end

		thread_concurrency = 64
		for i in 1..thread_concurrency do
			Thread.new do
				while true
					sw = @@unretrieved.dequeue
					begin
						yield sw
						sw.neighbor_gets
					rescue Errno::ECONNREFUSED,
					    Errno::ECONNRESET,
					    Errno::EPERM,
					    Timeout::Error => e
						msg = "WARNING: cannot " +
						    "retrieve #{sw.name} " +
						    "(#{sw.ia}): #{e}"
						puts msg
						@@warn.push(msg)
						@@unretrieved.error
					rescue => e
						msg = "WARNING: #{sw.name} " +
						    "(#{sw.ia}): #{e}"
						puts msg
						@@warn.push(msg)
					ensure
						@@unretrieved.done(sw)
					end
				end
			end
		end
		@@unretrieved.wait_all
		puts 'Finished!!'
		puts "Total: #{@@unretrieved.total}, Error: #{@@unretrieved.errors}"
	end

	def self.set_retrieve_all
		@@retrieve_all = true
	end

	def each_peer
		@ports.each { |p| p.peers.each { |peer| yield peer } }
	end

	def if_dump
		puts "#{@name}: #{@platform}, #{@time}, #{@ia.to_s}"
		@ports.each { |p| p.dump('  ') }
	end

	def if_dump_csv
		@ports.each { |p| p.dump_csv(@ia.to_s + ',' + @name) }
	end

	def config_get
		@config = @cli.config_get
	end

	def config_dump(dir = 'conf')
		begin
			Dir.mkdir(dir)
		rescue Errno::EEXIST
		end
		path = "#{dir}/#{@name}-#{@ia}.conf"
		f = File.open(path, 'w')
		f.puts @config
		f.close
	end

	def self.warn
		@@warn.each { |w| puts w }
	end
end
