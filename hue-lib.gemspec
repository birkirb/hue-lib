# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "hue-lib"
  s.version     = '0.7.3'
  s.authors     = ["Birkir A. Barkarson", "Aaron Hurley"]
  s.email       = ["birkirb@stoicviking.net"]
  s.homepage    = "https://github.com/birkirb/hue-lib"
  s.summary     = %q{Ruby library for controlling the Philips Hue system's lights and bridge.}
  s.description = %q{Library allowing registration and invocation of a registered Philips Hue app.
    Convinient objects allow executing commands on the bridge or individual bulbs.}

  s.rubyforge_project = "hue-lib"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency("json")
  s.add_development_dependency("rake")
  s.add_development_dependency("rspec", '>= 2.6.0')
  s.add_development_dependency("mocha", '>= 0.9.0')
  s.add_development_dependency("webmock", '>= 1.8.0')
end
