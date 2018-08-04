# Netutils

Netutils is a set of utilities to operate network equipment such as routers, switches, firewalls, wireless controller and so on.
Netutils currently can:
* automatically find network equipment,
* collect configurations,
* deploy certificate files to switches,
* reboot switches in safer order,
* locate a switch and port to which a host connects to,
* add/delete a MAC address filter,
* shut down or bring up a port, and so on.

## Features

* vendor lock free
* multiple accounts support
* auto neighbor discovery using Link Layer Discovery Protocol (LLDP) and Cisco Discovery Protocol (CDP)

## Acutually Tested Equipment

* Cisco
** C1812J, catalyst 6500, 3560, 2960
* AlaxalA
** AX8600, AX3800, AX3650, AX2530, AX2200, AX620
* Palo Alto Networks
** PA-5220, PA-3020, PA-850
* Aruba wireless LAN controller
** Aruba7210-JP
* NEC IX series
** IX2215, Palo Alto Networks 

## Installation

	$ git clone https://github.com/ohmori7/netutils
	$ cd netutils
	$ bundle install
	$ cp config/config-sample.rb config/config.rb
	$ vi config/config.rb

## Usage

	$ bundle exec netutils/bin/config-gets
	$ bundle exec netutils/bin/alaxala-deploy
	$ bundle exec netutils/bin/host-locate-on-demand
	$ bundle exec netutils/bin/acl
	$ bundle exec netutils/bin/port-shutdown

## TODO

* remove global methods
* use yaml for configuration
* out-of-band CLI output message handling (partially done but..)
* restructure class methods and variables
* introduce test codes
* more product support

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ohmori7/netutils.
