#!/usr/bin/env ruby
#
# Example serialrun job in Ruby.
#

require "optparse"
require "English"
require_relative "utils"

# Increase SHUFFLE_COUNT to decrease speed and increase CPU usage.
SHUFFLE_COUNT = 1234

#
# Main entry point.
#
def main
  flags = read_command_flags()
  start_logging()

  sort_command = ["sort", "--numeric-sort", "--output=#{flags[:path]}", flags[:inpath]]
  LOG.info("running: #{sort_command}")
  unless system(*sort_command)
    LOG.error("sort command failed: #{$CHILD_STATUS}")
    exit(1)
  end
  LOG.info("done")

  # Allow serialrun to collect more accurate io statistics.
  sleep(1)
end

#
# Read command line flags.
#
def read_command_flags
  flags = {}

  op = OptionParser.new
  op.on("--input=PATH", "Input file path") { |path| flags[:inpath] = path }
  op.on("--output=PATH", "Output file path") { |path| flags[:path] = path }
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

  errors.push("--input=PATH is required") if flags[:inpath].nil?
  errors.push("--output=PATH is required") if flags[:path].nil?
  return flags if errors == []
  puts(errors)
  puts("")
  puts(op.help)
  exit 1
end

main() if __FILE__ == $PROGRAM_NAME
