#
# Configuration for example job.
#

FLAGS = {
  "200_generate_random_numbers" => {
    "output" => "/tmp/randnums",
  },
  "300_shuffle" => {
    "input" => "/tmp/randnums",
    "output" => "/tmp/randnums2",
  },
  "305_sort" => {
    "input" => "/tmp/randnums2",
    "output" => "/tmp/randnums3",
  },
  "400_power" => {
    "input" => "/tmp/randnums3",
    "exponent" => 2,
  },
  "400_cube" => {
    "input" => "/tmp/randnums3",
    "exponent" => 3,
  },
  "400_square_root" => {
    "input" => "/tmp/randnums3",
    "exponent" => 0.5,
  },
}.freeze
