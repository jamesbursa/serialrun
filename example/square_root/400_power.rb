#!/usr/bin/env ruby
#
# Example serialrun job in Ruby.
#

require "optparse"
require_relative "utils"

#
# Main entry point.
#
def main
  flags = read_command_flags()
  start_logging()

  LOG.info("reading #{flags[:inpath]}")
  xs = File.open(flags[:inpath], "r").readlines().map { |line| Integer(line) }
  LOG.info("done, #{xs.length} numbers")

  LOG.info("compute start")
  total = 0.0
  xs.each do |x|
    total += x**flags[:exp]
    # Make CPU usage pattern more interesting
    sleep(0.1) if (x % 500).zero?
  end
  mean = total / xs.length
  LOG.info("sum  x^#{flags[:exp]} = #{total}")
  LOG.info("mean x^#{flags[:exp]} = #{mean}")
  LOG.info("compute done")

  LOG.info("done")
end

#
# Read command line flags.
#
def read_command_flags
  flags = { exp: 2 }

  op = OptionParser.new
  op.on("--input=PATH", "Input file path") { |path| flags[:inpath] = path }
  op.on("--exponent=N", "Exponent to use [2]") { |exp| flags[:exp] = Float(exp) }
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
  return flags if errors == []
  puts(errors)
  puts("")
  puts(op.help)
  exit 1
end

main() if __FILE__ == $PROGRAM_NAME
