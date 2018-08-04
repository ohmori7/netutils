require 'net/ssh'
require 'net/ssh/telnet'
require 'net/telnet'

path = File.expand_path(File.dirname(__FILE__)).untaint
Dir.glob("#{path}/cli/*") do |path|
	file = File.basename(path, '.*')
	require "netutils/cli/#{file}"
end

class CLI
	module Maker
		CISCO		= 0
		ALAXALA		= 1
		PALOALTO	= 2
		ARUBA		= 3
		NEC		= 4
		#
		# XXX:  Cisco WLC should come after Paloalto and NEC for a maker
		#	detection by a command to disable a CLI terminal pager.
		#	Since Paloalto always interprets a command like:
		#
		#		``config hogehoge''
		#
		#	as:
		#
		#		``configure.''
		#
		#	WLC pager command is then accepted by Paloalto and a
		#	maker detection fails if Cisco WLC preceds Paloalto.
		#
		WLC		= 5	# XXX: Cisco WLC, should be product...
		UNKNOWN		= 6
		MIN		= CISCO
		MAX		= ARUBA
	end

	FIRST_PROMPT_RE		= /^.*\n+\(?!?([^\r\n\(\)\s>#]+)\)? ?([>#]) ?\r?\n?.*$/m

	TIMEOUT = 30
	LOGIN_TIMEOUT = 3

	attr_reader :name, :ia, :maker, :product, :users, :prompt,
	    :passwds, :enable_passwds

	def initialize(name, ia, types = CLI_SESSION_TYPES, maker = Maker::UNKNOWN)
		@ia = ia
		@users = USERS.dup
		@passwds = PASSWORDS.dup
		@enable_passwds = ENABLES.dup
		@enabled = false
		@type = nil
		@types = types
		@session = nil
		@maker = maker
		@product = nil
		@cr = ''
		@name_supplied = name
		name_update(nil)
		@userprompt = [
		    'login:',		# Alaxala
		    '[Uu]sername:',	# Cisco
		    'User:'		# Cisco WiSM/WLC
		    ]
		# Cisco has trailing space, ``Password: '', but Alaxala not
		@passwdprompt = 'Password:'
		@telnetopt = Hash.new
		@telnetopt['Timeout' ] = TIMEOUT
		if defined?(LOGDIR)
			path = File.dirname(__FILE__)
			path += "/../"
			path += "/#{LOGDIR}/#{ia}.log"
			path = File.expand_path(path).untaint
			@telnetopt['Output_log'] = path
		end
		#@telnetopt['Dump_log'] = '/dev/stdout'
	end

	def name_update(name)
		if name =~ /^([^@]*)@(.*)$/
			@user = $1
			name = $2
		end
		raise "Invalid host name given: \"#{name}\"" if name =~ /[>#\n]/
		if @name === nil && name != nil &&
		   @name_supplied != nil && name != @name_supplied
			raise(ArgumentError, "host name mismatch: " +
			    "\"#{@name_supplied}\" is supplied " +
			    "but actually \"#{name}\"")
		end
		@name = name
		case @maker
		when Maker::CISCO
			prefix = suffix = trailer = ''
		when Maker::ALAXALA
			prefix = '!?'
			suffix = ''
			trailer = "\0? "
		when Maker::PALOALTO
			raise('Invalid host name for Paloalto') if ! @user
			prefix = "#{@user}@"
			suffix = ''
			trailer = ' '
		when Maker::ARUBA
			prefix  = '\('
			suffix  = '\) '
			trailer = ''
		else
			prefix  = '\(?'
			if @user
				prefix = "#{prefix}#{@user}@"
			else
				prefix = "#{prefix}.*"
			end
			suffix  = '\)? ?'
			trailer = "\0? ?"
		end
		name = '[^\r\n\(\)]+' if ! name
		@normalprompt = "#{prefix}#{name}#{suffix}>#{trailer}"
		@enableprompt = "#{prefix}#{name}#{suffix}##{trailer}"
		@configprompt = "#{prefix}#{name}#{suffix}\\(config[^ ]*\\)##{trailer}"
		if @enabled
			@prompt = @enableprompt
		else
			# XXX configuring node... dirty....
			@prompt = @normalprompt
		end
	end

	#
	# handle a carriage return (\r) and (\E[K) that intend to
	# remove all characters in a current line and remove trailing
	# characters, respectively.
	#
	def handle_control_characters(input)
		out = ''
		l = ''
		pos = 0
		escape = nil
		input.chars do |c|
			if escape
				escape += c
				case escape
				when /\e[0-9]/, /\e\[[0-9]+;[0-9]+H/, "\e[r"
					escape = nil
				when "\e[K"
					l.slice!(pos, l.length - pos)
					escape = nil
				when "\x1b[6n"
					# XXX: Alaxala edge switch hack...
					escape = nil
				end
				next
			end
			case c
			when "\0"
				# XXX: i do not know but Alaxala sends this...
			when "\b"
				l.chop!
				pos -= 1
			when "\e"
				escape = c
			else
				case c
				when "\r"
					pos = 0
				when "\n"
					#
					# in case of "\r\n", do not override
					# the character.
					#
					pos = l.length if pos === 0
					l[pos] = c
					out += l
					l = ''
					pos = 0
				else
					l[pos] = c
					pos += 1
				end
			end
		end
		out += l if ! l.empty?
		out.delete!("^\u{0001}-\u{007f}")
		return out
	end
	private :handle_control_characters

	def error?(r)
		case r
		when /%[^\n]+\n+\Z/m # XXX: this is not accurate
			maker = Maker::CISCO
		when /Error: Bad command\. \n\Z/m,
		     /[^\s]+: not found\n\Z/m,
		     /% The command or parameter at the ^ marker is invalid\./m,
		     /Error: Invalid parameter\./m
			maker = Maker::ALAXALA
		when /Invalid syntax\..*\Z/m, /Unknown command: .*\Z/m
			maker = Maker::PALOALTO
		when /^ *\^ *\n% [^\n]+ error/m,
		     /^ *\^ *\n% Invalid input detected at/m	# same as Cisco
			maker = Maker::ARUBA
		else
			return false
		end
		#maker_update(maker)
		return true
	end

	def puts(s)
		@session.puts(s + @cr)
	end
	private :puts

	def cmd(s, nextprompt = nil, ignoreerror = false)
		re = [ @prompt ]
		re.push('#') if @maker == Maker::UNKNOWN # XXX dirty hack for now...
		re.push(nextprompt) if nextprompt
		re = '(?:' + re.join('|') + ')'
		r = @session.cmd('String' => s + @cr, 'Match' => /#{re}\Z/)
		r = handle_control_characters(r)
		#
		# XXX: allows a command not to be echo-ed like FTP server.
		#
		if r !~ /^#{re}?(?:#{s.sub('*', '\\*')})?\n+(.*)#{re}\Z/m
			raise(ArgumentError, "CLI output error: \"#{r}\"")
		end
		r = $1
		r.slice!(-1) if @maker === Maker::ALAXALA && r[-1] === '!'
		if ignoreerror === false && error?(r)
			raise(ArgumentError,
			    "Command failed on #{@name}: #{s}: #{r}")
		end
		@prompt = nextprompt if nextprompt
		return r
	end

	def passwd(users, passwds, opasswds, nextprompt, cmd = nil)
		userpromptre = /(?:#{@userprompt.join('|')})/
		prompts = @userprompt.dup
		prompts << @prompt if @prompt
		prompts << @passwdprompt if @passwdprompt
		prompts << nextprompt if nextprompt
		re = /(?:#{prompts.join('|')})/
		r = @session.waitfor('Match' => re) if users
		while true
			if passwds.empty?
				users.shift if users
				if users && r =~ userpromptre
					passwds = opasswds.dup
				else
					raise(Errno::EPERM,
					    'authentication failed')
				end
			end
			if users && ! users.empty? && r =~ userpromptre
				puts(users[0])
			elsif cmd && r !~ /#{@passwdprompt}/
				puts(cmd)
			end
			if r !~ /#{@passwdprompt}/
				r = @session.waitfor(
				    'Match' => /#{@passwdprompt}/)
				#
				# emulate an exception because net/telnet.rb
				# does not raise an exception when a remote
				# note disconnects after consecutive login
				# failures.
				#
				raise(Errno::ECONNRESET) if r === nil
			end
			puts(passwds[0])
			r = @session.waitfor('Match' => re)
			case r
			when userpromptre
				raise('no user for user prompt') if ! users
			when /#{@passwdprompt}/
			when /#{nextprompt}/
				@prompt = nextprompt
				return r
			else
				if @prompt && r =~ /#{@prompt}/ && ! cmd
					raise('invalid state')
				end
			end
			passwds.shift
		end
	end
	private :passwd

	def login_ssh(ousers, opasswds)
		users = ousers.dup
		passwds = opasswds.dup
		user = users.shift
		begin
			passwd = passwds.shift
			opt = @telnetopt.dup
			ssh = Net::SSH.start(@ia, user,
			    :password		=> passwd,
			    :non_interactive	=> true,
			    #:keys		=> ['/path/to/private_key'],
			    #:port		=> 22,
			    :timeout		=> opt['Timeout']
			    )
			opt['Session'] = ssh

			#
			# XXX: Alaxala edge switch hack...
			#
			#      an Alaxala edge switch asks us cursor position
			#      using CSI escap sequence, DSR (0x1b[6n), before
			#      outputing prompt.  Net::SSH::Telnet then does not
			#      consider the case where escape sequence is sent
			#      right after login.  This incurs long delay until
			#      Alaxala outputs the first  prompt.  Here, we send
			#      back a dummy cursor position, (1, 1), to Alaxala.
			#
			opt['Prompt'] = /(?:\e\[6n|[$%#>] ?\Z)/

			msg = ''
			@session = Net::SSH::Telnet.new(opt) { |l| msg += l }
			@session.prompt = /[$%#>] \z/
			if msg =~ /ALAXALA/
				maker_update(Maker::ALAXALA)
				if msg.rindex("\x1b[6n")
					@cr = "\r"
					@session.write("^1;1R")
					msg += @session.waitfor(/[$%#>] \z/)
				end
			end
		rescue Net::SSH::AuthenticationFailed, Net::SSH::Disconnect => e
			if passwds.empty?
				if users.empty?
					raise(Errno::EPERM, "cannot login to " +
					    "#{@ia}")
				end
				user = users.shift
				passwds = opasswds.dup
			end
			retry
		rescue Net::SSH::ConnectionTimeout
			raise("cannot login to #{@ia}")
		end
		#
		# XXX: dirty hack
		#
		# some switch, say Alaxala, disconnects immediately
		# after authentication succeeds if many user logged
		# in.  Net::SSH::Telnet.new() unfortunately cannot
		# handle such case.
		# 
		if @session.nil?
			raise(Errno::ECONNRESET, 'too many users???')
		end
		return msg
	end
	private :login_ssh

	def login_telnet(users, passwds)
		opt = @telnetopt.dup
		opt['Host'] = @ia
		users = users.dup if users
		passwds = passwds.dup
		opasswds = passwds.dup
		begin
			@session = Net::Telnet::new(opt)
			r = passwd(users, passwds, opasswds, @normalprompt)
		rescue Errno::ECONNRESET
			retry
		end
		return r
	end
	private :login_telnet

	def login
		users = @users.dup
		passwds = @passwds.dup
		@type = @types[0]
		begin
			r = send("login_#{@type}", users, passwds)
		rescue Errno::ECONNREFUSED => e
			raise e if @type === @types.last
			@type = @types[@types.index(@type) + 1]
			retry
		end
		r = handle_control_characters(r)
		if r =~ FIRST_PROMPT_RE
			name_update($1)
			if $2 === '#'
				@enabled = true
			end
		end
		if r =~ /NEC Corporation.*OpenROUTE.*J\. Noel Chiappa/m
			maker_update(Maker::NEC)
		end
		product_detect
	end

	PRODUCT_DETECTION_MAXRETRIES = 3

	# XXX: exclude maker dependencies...
	def product_detect
		pager_disable
		return if @maker === Maker::UNKNOWN
		case @maker
		when Maker::CISCO
			c = 'show version'
			# XXX: Nexus not supported yet
			re = /IOS Software, ([^\s]+) Software .*/m
		when Maker::WLC
			c = 'show sysinfo'
			re = /.*Product Name[^ ]+ (.*)$/m
		when Maker::ALAXALA
			c = 'show version'
			re = /.*Model:\s+(AX[^\s\n]+).*$/m
		when Maker::PALOALTO
			c = 'show system info'
			re = /model: ([^\s\n]+).*/m
		when Maker::ARUBA
			c = 'show version'
			re = /.*ArubaOS \(MODEL: ([^\)]+)\),.*/m
		when Maker::NEC
			c = 'show version'
			re = /^IX Series ([^ ]+) .*$/m
		when Maker::UNKNOWN
			return
		end

		leftchance = PRODUCT_DETECTION_MAXRETRIES
		begin
			v = cmd(c)
			if v !~ re
				raise('Unknown maker detected')
			end
			@product = $1
			disable_logging_console
		rescue => e
			leftchance -= 1
			raise e if leftchance === 0
			retry
		end
	end
	private :product_detect

	def maker_to_s
		# XXX: smarter way please...
		case @maker
		when Maker::CISCO
			'Cisco'
		when Maker::WLC
			'WLC'
		when Maker::ALAXALA
			'Alaxala'
		when Maker::PALOALTO
			'Paloalto'
		when Maker::ARUBA
			'Aruba'
		when Maker::NEC
			'NEC'
		else
			'Unknown'
		end
	end

	def yes_or_no(yes_or_no, re)
		re = /\n[^\n]+[Yy]\/[Nn]\)? ?$/m if re == nil
		@session.waitfor('Match' => re)
		puts(yes_or_no)
	end
	private :yes_or_no

	def yes(re = nil)
		yes_or_no('y', re)
	end

	def no(re = nil)
		yes_or_no('n', re)
	end

	def logout
		@session.close
	end

	def maker_update(maker)
		return if @maker != Maker::UNKNOWN
		@maker = maker
		extend Module.const_get("#{maker_to_s}")
	end
	private :maker_update

	def pager_disable_cisco
		cmd('terminal length 0')
	end
	private :pager_disable_cisco

	def pager_disable_wlc
		cmd('config paging disable')
	end

	def pager_disable_alaxala
		cmd('set terminal pager disable')
	end
	private :pager_disable_alaxala

	def pager_disable_paloalto
		cmd('set cli pager off')
	end
	private :pager_disable_paloalto

	def pager_disable_aruba
		enable
		cmd('no paging')
	end
	private :pager_disable_aruba

	def pager_disable_nec
		configure
		cmd('terminal length 0')
		unconfigure
	end
	private :pager_disable_nec

	def pager_disable
		maker = omaker = @maker
		maker = Maker::MIN if omaker === Maker::UNKNOWN
		begin
			@maker = maker
			send('pager_disable_' + maker_to_s.downcase)
		rescue Timeout::Error => e
			raise e
		rescue => e
			if omaker === Maker::UNKNOWN
				maker += 1
				if maker != Maker::UNKNOWN &&
				   e != ArgumentError
					retry
				else
					@maker = omaker
					raise
				end
			end
		ensure
			@maker = omaker
		end
		maker_update(maker)
		name_update(@name) if omaker === Maker::UNKNOWN
	end
	private :pager_disable

	def enable
		return if @enabled
		passwd(nil, @enable_passwds.dup, @enable_passwds.dup,
		    @enableprompt.dup, 'enable')
		@enabled = true
	end

	def configure
		raise "already configuring" if @prompt == @configprompt
		enable
		return cmd('configure terminal', @configprompt)
	end

	def unconfigure
		raise "currently not configuring" if @prompt != @configprompt
		return cmd('end', @enableprompt)
	end

	def config_get
		enable
		re = Module.const_get(maker_to_s).const_get('CONFIG_RE')
		if show_running_config !~ re
			raise("Invalid configuration format for #{@name}")
		end
		return $1
	end

	def _new(name, *arg)
		c = Module.const_get(maker_to_s)
		if c.const_defined?(name)
			c.const_get(name).new(*arg)
		else
			nil
		end
	end
	private :_new

	def route_gets(ia)
		r = _new(:ShowRoute)
		r.parse(cmd(r.cmd(ia), nil, true))
		return r.rib.get(ia)
	end

	def vrf_gets
		v = _new(:ShowVRF)
		v.parse(cmd(v.cmd))
		v.vrfs.add('default', '0:0') if v.vrfs.empty?
		return v.vrfs
	end

	def arp_resolve(ia, vrf)
		if vrf.name == 'default'
			output = cmd("show ip arp #{ia}")
		else
			output = cmd("show ip arp vrf #{vrf.name} #{ia}")
		end
		a = _new(:ShowARP)
		a.parse(output)
		return a.arps[ia]
	end

	def mac_address_table_get(sw, ma, vlan)
		fib = _new(:MACFIB, sw)
		fib.parse(cmd(fib.cmd(ma, vlan)))
		return fib.ports
	end

	def interface_gets(sw)
		i = _new(:Interface, sw)
		i.parse(cmd(i.cmd))
		#
		# XXX: hack for Cisco because Cisco cannot obtain up/down of
		#      an interface with interfaces capability command...
		#
		is = _new(:IfSummary, sw)
		is.parse(cmd(is.cmd)) if is
	end

	def interface_name(port)
		port
	end

	def interface_name_cli(port)
		port
	end

	def interface_shutdown(port)
		configure
		cmd("interface #{port}")
		cmd('shutdown')
		unconfigure
	end

	def interface_noshutdown(port)
		configure
		cmd("interface #{port}")
		cmd('no shutdown')
		unconfigure
	end

	def acl_exists?(type, name)
		configure
		filters = cmd("show #{acl_definition(type, name)}")
		unconfigure
		! filters.empty?
	end

	def acl_add(type, name, addr, seq = nil)
		case type
		when 'ip'
			# XXX: we may need sanity check.
		when 'mac', 'advance'
			addr = MACAddr.new(addr)
		else
			raise("Unknown ACL type: #type")
		end
		cmd = acl_type_to_cmd(type)
		configure
		cmd(acl_definition(type, name))
		cmd("#{seq} deny #{cmd} host #{addr} any")
		unconfigure
	end

	def acl_delete(type, name, seq)
		configure
		cmd(acl_definition(type, name))
		cmd("no #{seq}")
		unconfigure
	end

	def neighbor_gets(sw, port = nil)
		c = _new(:CDP, sw)
		if c
			begin
				c.parse(cmd(c.cmd(port)))
				return c.rsw if port && c.rsw
			rescue ArgumentError => e
				if e.to_s !~ /% CDP is not enabled/
					raise e
				end
			end
		end
		l = _new(:LLDP, sw)
		if l
			l.parse(cmd(l.cmd(port)))
			return l.rsw if port && l.rsw
		end
		if ! c && ! l
			raise 'No method found for retrieving a neighbor!!'
		end
		nil
	end
end
