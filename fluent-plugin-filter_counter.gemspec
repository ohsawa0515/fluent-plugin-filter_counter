# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-filter_counter"
  spec.version       = "0.0.1"
  spec.authors       = ["Shuichi Ohsawa"]
  spec.email         = ["ohsawa0515@gmail.com"]

  spec.summary       = %q{Fluentd filter plugin to count matched messages and stream if exceed the threshold.}
  spec.description   = %q{Fluentd filter plugin to count matched messages and stream if exceed the threshold.}
  spec.homepage      = "https://github.com/ohsawa0515/fluent-plugin-filter_counter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency "fluentd", ">= 0.12"
end
