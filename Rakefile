require 'rspec/core/rake_task'
require "cane/rake_task"

task default: [:cane, :spec]

desc "Run all rspec files"
RSpec::Core::RakeTask.new("spec") do |t|
  t.rspec_opts  = ["--color", "--format progress"]
  t.ruby_opts = "-w"
end

desc "Run cane to check quality metrics"
Cane::RakeTask.new(:cane) do |cane|
  # keep the ABC complexity of methods to something reasonable
  cane.abc_max = 15

  # keep line lengths to something that fit into a reasonable split terminal
  cane.style_measure = 110

  # 0 is the goal
  cane.max_violations = 18
end
