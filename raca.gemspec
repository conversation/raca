Gem::Specification.new do |s|
  s.name              = "raca"
  s.version           = "0.1.1"
  s.summary           = "A simple wrapper for the Rackspace Cloud API with no dependencies"
  s.description       = "A simple wrapper for the Rackspace Cloud API with no dependencies"
  s.authors           = ["James Healy"]
  s.email             = ["james.healy@theconversation.edu.au"]
  s.homepage          = "http://github.com/conversation/raca"
  s.has_rdoc          = true
  s.rdoc_options      << "--title" << "Raca" << "--line-numbers"
  s.files             =  Dir.glob("{lib}/**/*") + ["Rakefile","README.markdown"]
  s.license           = "MIT"

  s.add_development_dependency("rake", "~> 10.0")
  s.add_development_dependency("rspec", "~>2.0")
  s.add_development_dependency("webmock")
  s.add_development_dependency("ir_b")
  s.add_development_dependency("cane")
end
