#!/usr/bin/env ruby
#
# Example serialrun job in Ruby.
#

require "optparse"
require_relative "utils"

# Increase SAMPLE_SIZE to decrease speed and increase CPU usage.
SAMPLE_SIZE = 1000

#
# Main entry point.
#
def main
  flags = read_command_flags()
  start_logging()

  LOG.info("writing #{flags[:count]} numbers to #{flags[:path].inspect}")
  File.open(flags[:path], "w") do |file|
    xs = []
    1.upto flags[:count] do |i|
      # Each number is the mean of SAMPLE_SIZE random numbers
      sum = 0
      1.upto(SAMPLE_SIZE) { sum += rand(1000000000) }
      x = sum / SAMPLE_SIZE
      file.puts(x)
      # Make memory usage pattern more interesting
      xs.push([x] * 10)
      if (i % 1000).zero?
        LOG.info(sprintf("generated %i/%i (%.1f%%)", i, flags[:count], 100.0 * i / flags[:count]))
      end
      # Make CPU usage pattern more interesting
      sleep(3) if (i % 43210).zero?
    end
  end
  LOG.info("done")
end

#
# Read command line flags.
#
def read_command_flags
  flags = { count: 100000 }

  op = OptionParser.new
  op.on("--output=PATH", "Output file path") { |path| flags[:path] = path }
  op.on("--count=COUNT", "Number of values") { |count| flags[:count] = count }
  op.on_tail("--help", "Display this help and exit") do
    puts(op.help)
    exit
  end

  errors = []
  begin
    op.parse(ARGV)
  rescue OptionParser::ParseError => error
    errors.push(error)
  end

  errors.push("--output=PATH is required") if flags[:path].nil?
  return flags if errors == []
  puts(errors)
  puts("")
  puts(op.help)
  exit 1
end

main() if __FILE__ == $PROGRAM_NAME
