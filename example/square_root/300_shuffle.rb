#!/usr/bin/env ruby
#
# Example serialrun job in Ruby.
#

require "optparse"
require_relative "utils"

# Increase SHUFFLE_COUNT to decrease speed and increase CPU usage.
SHUFFLE_COUNT = 1234

#
# Main entry point.
#
def main
  flags = read_command_flags()
  start_logging()

  LOG.info("reading #{flags[:inpath]}")
  xs = File.open(flags[:inpath], "r").readlines().map { |line| Integer(line) }
  LOG.info("done, #{xs.length} numbers")

  LOG.info("shuffle start")
  1.upto(SHUFFLE_COUNT) do |i|
    xs.shuffle!
    if (i % 100).zero? || i == SHUFFLE_COUNT
      LOG.info(sprintf("shuffled %i/%i (%.1f%%)", i, SHUFFLE_COUNT, 100.0 * i / SHUFFLE_COUNT))
    end
  end
  LOG.info("shuffle done")

  LOG.info("writing to #{flags[:path]}")
  File.open(flags[:path], "w") do |file|
    xs.each { |x| file.puts(x) }
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
