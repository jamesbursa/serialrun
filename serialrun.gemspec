#
# Gem specification for SerialRun.
#
# See https://guides.rubygems.org/specification-reference/
#

require_relative "lib/serialrun/version"

Gem::Specification.new do |spec|
  spec.name          = "serialrun"
  spec.version       = SerialRun::VERSION
  spec.authors       = ["James Bursa"]
  spec.email         = ["james@zamez.org"]

  spec.summary       = "Run a job consisting of numbered steps."
  spec.description   = <<~DESCRIPTION
    Run a job consisting of numbered steps, logging to a database, and optionally reporting
    success or failure by email.

    - A job is a directory of executable files named NNN_name (e.g. 100_hello).
    - Each step may be in any language.
    - Steps run serially in numerical order.
    - Steps with the same number are launched in parallel.
    - Dry-run mode shows steps that will run.
    - Status and logs of each step written to a MySQL database.
    - Optional reporting of success or failure by email.
    - Flags for each step can be configured independently.
    - Web interface to view history and current status.
  DESCRIPTION
  spec.homepage      = "https://github.com/jamesbursa/serialrun"
  spec.license       = "GPL"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = Dir["lib/**/*.rb"]
  spec.bindir        = "./"
  spec.executables   = ["serialrun"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_dependency "mysql2"
  spec.add_dependency "pony"
end
