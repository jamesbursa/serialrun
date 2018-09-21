#
# Utility functions.
#
module SerialRun
  module_function

  #
  # Format a size as bytes, K, or M.
  #
  def format_size(size)
    return sprintf("%iM", size / 1024 / 1024) if 1024 * 1024 <= size
    return sprintf("%iK", size / 1024) if 1024 <= size
    return sprintf("%i", size)
  end
end
