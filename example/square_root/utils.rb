#
# Common utility code.
#

require "logger"
require "socket"
require "English"

PROGRAM_NAME = File.basename($PROGRAM_NAME, ".rb")
START_TIME = Time.now()
LOG = Logger.new(STDERR)
LOG.formatter = proc do |severity, datetime, _progname, msg|
  sprintf("%s%s %s\n", severity[0], datetime.utc.strftime("%m%d %H%M%S.%L"), msg)
end
raise "Requires Ruby 2.2 or later" unless 2.2 <= RUBY_VERSION.split(".")[0, 2].join(".").to_f

#
# Log useful info at program start and exit.
#
def start_logging
  LOG.info(sprintf("start %s: %s %s %s %s, hostname %s, user %s",
                   PROGRAM_NAME, RUBY_ENGINE, RUBY_VERSION, RUBY_PATCHLEVEL, RUBY_PLATFORM,
                   Socket.gethostname, ENV["USER"]))
  LOG.info("invoked as: #{$PROGRAM_NAME} #{ARGV.join(' ')}")

  at_exit do
    unless $ERROR_INFO.nil? || $ERROR_INFO.class == SystemExit
      LOG.fatal("#{$ERROR_INFO.class}: #{$ERROR_INFO.message}")
      $ERROR_INFO.backtrace.each { |bt| LOG.fatal("  #{bt}") }
    end
    io_stats = read_io_stats()
    LOG.info(sprintf("exit %s: pid %i, real %.3fs, user %.2fs, system %.2fs, "\
                     "read %s, wrote %s",
                     PROGRAM_NAME, Process.pid,
                     Time.now() - START_TIME, Process.times.utime, Process.times.stime,
                     format_size(io_stats["rchar"]), format_size(io_stats["wchar"])))
  end
end

#
# Read I/O statistics from Linux /proc filesystem.
#
# See http://man7.org/linux/man-pages/man5/proc.5.html for an explanation of the fields.
#
def read_io_stats
  io_stats = {}
  File.open("/proc/self/io").readlines.each do |line|
    name, value = line.chomp.split(": ")
    io_stats[name] = value.to_i
  end
  return io_stats
end

#
# Format a size as bytes, K, or M.
#
def format_size(size)
  return sprintf("%iM", size / 1024 / 1024) if 1024 * 1024 <= size
  return sprintf("%iK", size / 1024) if 1024 <= size
  return sprintf("%i", size)
end
