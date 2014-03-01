# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Yoshihisa Tanaka"]
  gem.email         = ["yt.hisa@gmail.com"]
  gem.description   = %q{Extended tail input plugin}
  gem.summary       = %q{Extended tail input plugin}
  gem.homepage      = "https://github.com/bryanyork/fluent-plugin-tail-ex-asis"
  gem.license       = "Apache 2.0"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "fluent-plugin-tail-ex-asis"
  gem.require_paths = ["lib"]
  gem.version       = "0.1.2"

  #requires = ['fluentd', 'fluent-mixin-config-placeholders']
  #requires.each {|name| gem.add_runtime_dependency name}
  gem.add_runtime_dependency 'fluentd', '~>0.10', '>=0.10.34'
  gem.add_runtime_dependency 'fluent-mixin-config-placeholders', '~>0.2', '>=0.2.2'
  requires = ['rake', 'flexmock']
  requires.each {|name| gem.add_development_dependency name}
end
