# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'netutils/version'

Gem::Specification.new do |spec|
  spec.name          = "netutils"
  spec.version       = Netutils::VERSION
  spec.authors       = ["Motoyuki OHMORI"]
  spec.email         = ["ohmori@tottori-u.ac.jp"]

  spec.summary       = %q{Networking utitlities to operate network equipment.}
  spec.description   = %q{Networking utitlities to operate network equipment made by Cisco, AlaxalA, NEC IX, Palo Alto, Aruba Wireless Controller and so on.}
  spec.homepage      = "https://github.com/ohmori7/netutils"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.com"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_runtime_dependency "mail"
  spec.add_runtime_dependency "net-ssh"
  spec.add_runtime_dependency "net-ssh-telnet"
  spec.add_runtime_dependency "net-telnet"
end
