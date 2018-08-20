#!/usr/bin/env ruby
#
# Example serialrun job in Ruby.
#

require "net/http"
require "optparse"
require "ostruct"

def main
  opts = OpenStruct.new
  opts.dir = "."
  OptionParser.new do |op|
    op.on("--dir=PATH", "Directory for files") { |path| opts.dir = path; }
  end.parse!
  opts.to_h.each { |opt, value| puts("option: #{opt}=#{value}") }

  data = Net::HTTP.get(URI("http://www.gutenberg.org/cache/epub/83/pg83.txt"))
  File.new(File.expand_path("pg83.txt", opts.dir), "w").write(data)
end

main() if __FILE__ == $PROGRAM_NAME
