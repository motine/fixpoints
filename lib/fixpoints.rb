require_relative "fixpoints/version"
require_relative "fixpoint_diff"

require_relative "fixpoint"
require_relative "incremental_fixpoint"
require_relative "fixpoint_test_helpers"

if defined?(RSpec) && RSpec.respond_to?(:configure)
  RSpec.configure { |c| c.add_setting :fixpoints_path }
end
