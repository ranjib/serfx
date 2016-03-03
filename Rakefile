require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new("spec")

RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ['lib/**/*.rb']
end

YARD::Rake::YardocTask.new do |task|
  task.files   = ['README.md', 'lib/**/*.rb']
  task.options = [
    '--output-dir', 'doc/yard',
    '--markup', 'markdown'
  ]
end
