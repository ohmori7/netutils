require "netutils/version"
require 'mail'
require 'netutils/switch'
require 'config/config'

module Netutils

#
$progname = File.basename($0)

#
ACL_MAX_SEQ = 4294967294
#
$log = ''

def mail(s, b)
	m = Mail.new do
		delivery_method :smtp, address: MAILSERVER
		from MAILFROM
		to MAILTO
		subject s
		body b
	end
	m.charset = 'ascii'
	m.deliver!
end

def valid_ip_address?(s)
	return false if s !~ /^(?:[0-9]+\.){3}[0-9]+$/
	results = s.split('.').collect { |i| i.to_i.between?(0, 255) }
	return results.count(true) === 4
end

def interface_sanity_check(host, port)
	# XXX: need more checks to detect backbone links.
	if port !~ /^[gf]/i
		raise "Suppress shutdown #{port}, which may be backbone link."
	end
end

def log_without_newline(m)
	print m
	$log += m
end

def log(m)
	puts m
	$log += m + "\n"
end

def log_buffer
	return $log
end

def vlans_by_switch_name(swname, vlan)
	vlan = vlan.to_i
	vlans = []
	vlans = VLANS[swname].dup if VLANS.has_key?(swname)
	vlans.unshift(vlan) if vlan && ! vlans.include?(vlan)
	return vlans
end

def interface_name_vlan_id(name)
	return $1 if name =~ /^vlan([0-9]+)$/i
	nil
end

def static_neighbor_resolve(name, ifname)
	key = "#{name}_#{ifname}"
	n = STATIC_NEIGHBOR[key]
	return nil if n.nil?
	Switch.get(n[:name], Switch::Type::ROUTER, nil, nil, nil, n[:ia])
end

def tunnel_nexthop_resolve(sw, rt)
	return rt.nh if rt.nh
	c = CDP.new(nil)
	c.parse(sw.cli.cmd("show cdp neighbors #{rt.interface} detail"))
	c.ias[0]
end

def router_locate(ia)
	root = SWITCHES[0]
	sw = Switch.new(root[0], Switch::Type::ROUTER, root[1])
	sw.login

	while true
		rts = sw.route_gets(ia)
		raise "No route found for #{ia}" if ! rts
		bestrt = nil
		rts.each do |rt|
			case rt.proto
			when 'connected'
				return sw, ia
			when 'static', 'rip', 'ospf', 'bgp'
				# just in case for redistributed routes.
				next if rt.nh === nil && ! rt.tunnel?
				bestrt = rt.compare(bestrt)
			end
		end
		raise "No valid route found for #{ia}" if ! bestrt

		if OTHER_NEXTHOPS.include?(bestrt.nh)
			return sw, bestrt.nh
		end

		if bestrt.tunnel?
			nh = tunnel_nexthop_resolve(sw, bestrt)
		else
			nh = bestrt.nh
		end
		sw = Switch.new(nil, Switch::Type::ROUTER, nh)
		sw.login
	end
end

end
