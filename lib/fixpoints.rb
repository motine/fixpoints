require_relative "fixpoints/version"
require_relative "fixpoint_diff"

require_relative "fixpoint"
require_relative "incremental_fixpoint"

if defined?(RSpec)
  RSpec.configure { |c| c.add_setting :fixpoints_path }
end
