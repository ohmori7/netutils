require 'netutils/parser'

module Alaxala

class Interface < Parser
	def cmd
		return 'show port'
	end

	# AX2500
	# Date 2017/10/14 21:00:10 JST
	# Port Counts: 52
	# Port  Name           Status  Speed           Duplex     FCtl FrLen  ChGr/Status
	#  0/1  geth0/1        down    -               -          -        -  -/-
	#  0/2  geth0/2        down    -               -          -        -  -/-

	# AX2200
	# Date 2017/10/14 20:47:34 JST
	# Port Counts: 28
	# Port  Name           Status  Speed           Duplex     FCtl FrLen  ChGr/Status
	#  0/1  gigaether0/1   up      1000BASE-T      full(auto) off   1518  -/-
	#  0/2  gigaether0/2   up      1000BASE-T      full(auto) off   1518  -/-

	# AX3800 (stack)
	# Switch 1 (Master) 
	# ----------------- 
	# Date 2017/10/15 23:10:44 JST
	# Port Counts: 48   
	# Port  Name           Status   Speed           Duplex     FCtl FrLen ChGr/Status
	#  0/ 1 tengeth1/0/1   up       10GBASE-SR      full       off   1518   1/up
	#  0/ 2 tengeth1/0/2   up       10GBASE-SR      full       off   1518   2/up
	#
	#
	# Switch 2 (Backup) 
	# ----------------- 
	# Date 2017/10/15 23:10:44 JST
	# Port Counts: 48   
	# Port  Name           Status   Speed           Duplex     FCtl FrLen ChGr/Status
	#  0/ 1 tengeth2/0/1   up       10GBASE-SR      full       off   1518   1/-
	#  0/ 2 tengeth2/0/2   up       10GBASE-SR      full       off   1518   2/-

	# AX8600
	# Date 2017/10/14 20:16:41 JST
	# Port Counts: 54
	# Port  Status   Speed           Duplex     FCtl FrLen Description
	#  1/1  up       10GBASE-SR      full       off  1518  hogehoge
	#  1/2  up       10GBASE-SR      full       off  1518  fugafuga
	PORT_RE = /^\s*([0-9\/\s]+)\s+([^\s]*)\s*(up|down|dis|inact|init)\s+([^\s]+)\s+(full|half|-)(?:\(auto\))?\s+(on|off|-)\s+(?:[0-9]+|-)\s+.*$/

	def initialize(sw)
		super()
		add('Init',	:init)
		add('Date',	:date,	/^Port Counts:.*$/)
		add('Count',	:count,	/^Port\s+(?:Name|Status).*$/)
		add('Port',	:port)
		@sw = sw
	end

	private

	def init(l, m)
		case l
		when /^Date/
			changeto('Date')
		when /^Switch/
		when /^-------/
		when /^$/
		end
	end

	def date(l, m)
		changeto('Count')
	end

	def count(l, m)
		changeto('Port')
	end

	def port_name_normalize(port0, name, speed)
		port0.delete!(' ')
		# XXX: should check actual port capability...
		if ! name || name.empty?
			case speed
			when /^(10|100|1000)BASE/
				name = 'Gigabit'
			when /^10GBASE/
				name = 'TenG'
			when /^40GBASE/
				name = 'FortyG'
			when /^100GBASE/
				name = 'HundredG'
			when '-'
			else
				raise "Unknown Speed: #{speed}"
			end
		elsif @sw.product =~ /^AX3[0-9]{3}/
			#
			# AX3000 series uses 3 numbers for port numbers
			# in many commands of CLI but ``show port''
			# command returns 2 numbers only like below.
			#
			#    0/23 tengeth1/0/23  up 1000BASE-SX...
			#
			if name !~ /^[a-z]+([0-9\/]+)$/
				raise "Invalid port format: \"#{name}\""
			end
			port0 = $1
		end
		case name
		when /^TenG/i
			prefix = 'Ten'
		when /^FourtyG/i
			prefix = 'Fourty'
		when /^HundredG/i
			prefix = 'Hundred'
		else
			prefix = ''
		end
		return "#{prefix}GigabitEthernet #{port0}"
	end

	def port(l, m)
		if l =~ /^Switch/
			changeto('Init')
			return
		end
		return if l =~ /^$/	# AX2500, or others...
		if l !~ PORT_RE
			raise "CLI invalid format of port: #{l}"
		end
		name = port_name_normalize($1, $2, $4)
		@sw.ports.add(name, nil, $4, $4, $5)
		@sw.ports[name].up = $3 == 'up'
	end
end

end
