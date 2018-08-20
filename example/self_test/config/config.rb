#
# Configuration for example job.
#

ROOT_DIR = File.dirname(File.dirname(File.dirname(File.expand_path(__dir__))))

FLAGS = {
  "100_rubocop" => {
    "root" => ROOT_DIR,
  },
}.freeze
