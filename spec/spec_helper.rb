require "bundler/setup"
require "active_record"
require "fixpoints"

DB_PATH = File.join(__dir__, '../tmp/test.sqlite3')
Warning[:deprecated] = false # let's get rid of the annoying kwargs deprecation notice in ActiveRecord

class Book < ActiveRecord::Base
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # setup test database
  config.before(:suite) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: DB_PATH)
    ActiveRecord::Base.logger = Logger.new(STDOUT, level: :info)

    ActiveRecord::Schema.define do
      create_table :books do |t|
        t.string :title
        t.string :summary
        t.timestamps
      end
    end
  end

  config.after(:suite) do
    ActiveRecord::Base.remove_connection
    File.unlink(DB_PATH)
  end
end
