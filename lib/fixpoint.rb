# A fixpoint is a snapshot of the database contents.
# It is saved to the +spec/fixpoints+ folder.
# A fixpoint (file) contains a mapping of table names to a list if their records.
#
# Empty tables are stripped from files.
#
# Make sure to run the tests in the right order: In a single RSpec file, you can use the order in which the tests are defined (`RSpec.describe 'MyFeature', order: :defined do`).
# However, tests in groups might follow a slightly different order (see https://relishapp.com/rspec/rspec-core/docs/configuration/overriding-global-ordering)
#
# If you did a lot of changes to a test, you can remove a fixpoint file from its directory.
# It will be recreated when the test producing it runs again.
# Don't forget re-running the tests _based on_ it because their fixpoints might have to change too.
# Example: You need to add something to the database's seeds.rb. All subsequent fixpoints are missing the required entry.
# To update all fixpoints, just remove the whole `spec/fixpoints` folder and re-run all tests. Now all fixpoints should be updated.
# Be careful though, don't just remove the fixpoints if you are not sure what is going on.
# A change in a fixpoint might point to an unintended change in code.
#
# We need to be be careful to use +let+ and +let!+ with factories.
# Records might be created twice when using create in there (once by the fixpoint and once by the factory).
#
# KNOWN ISSUES
# Under certain conditions you may get `duplicate key value violates unique constraint` because the primary key sequences are not updated correctly.
# If this happens, just add a Fixpoint.reset_pk_sequences! at the beginning of your test. We need to dig a little deeper here at some point...
#
# LIMITATIONS
# The records in tables are ordered by their id.
# If there is no id for a table, we use database's order (what the SELECT query returns).
# This order may be instable.
class Fixpoint
  class Error < StandardError; end

  FIXPOINT_FOLDER = 'fixpoints'
  TABLES_TO_SKIP = %w[ar_internal_metadata delayed_jobs schema_info schema_migrations].freeze

  class << self
    def exists?(fixname)
      File.exist?(fixpoint_path(fixname))
    end

    def from_file(fixname)
      raise Fixpoint::Error, "The requested fixpoint (\"#{fixname}\") could not be found. Re-run the test which stores the fixpoint." unless exists?(fixname)

      file_path = fixpoint_path(fixname)
      new(YAML.load_file(file_path))
    end

    # Creates a Fixpoint from the database contents. Empty tables are skipped.
    def from_database
      new(read_database_records)
    end

    def remove(fixname)
      FileUtils.rm_f(fixpoint_path(fixname))
    end

    # reset primary key sequences for all tables
    # useful when tests sometimes run before the storing the first fixpoint.
    # these test might have incremented the id sequence already, so the ids in the fixpoints chance (which leads to differences).
    def reset_pk_sequences!
      return unless conn.respond_to?(:reset_pk_sequence!)
      conn.tables.each { |table_name| conn.reset_pk_sequence!(table_name) }
    end

    def fixpoint_path(fixname)
      fspath = self.fixpoints_path
      raise Fixpoint::Error, 'Can not automatically infer the base path for the specs, please set `rspec_config.fixpoints_path` explicitly' if fspath.nil?
      raise Fixpoint::Error, "Please create the fixpoints folder (and maybe create a .gitkeep): #{fspath}" if !File.exist?(fspath)

      File.join(fspath, "#{fixname}.yml")
    end

    def conn
      ActiveRecord::Base.connection
    end

    protected

    def fixpoints_path
      return RSpec.configuration.fixpoints_path unless RSpec.configuration.fixpoints_path.nil?
      return Rails.root.join(RSpec.configuration.default_path, FIXPOINT_FOLDER) if defined?(Rails)
      # now this is ugly, but necessary. we go up from the current example's path until we find the spec folder...
      return nil if RSpec.current_example.nil?
      spec_path = Pathname.new(RSpec.current_example.file_path).ascend.find { |pn| pn.basename.to_s == RSpec.configuration.default_path }.expand_path

      File.join(spec_path, FIXPOINT_FOLDER)
    end

    def read_database_records
      # adapted from: https://yizeng.me/2017/07/16/generate-rails-test-fixtures-yaml-from-database-dump/
      tables = conn.tables
      tables.reject! { |table_name| TABLES_TO_SKIP.include?(table_name) }

      tables.each_with_object({}) do |table_name, acc|
        result = conn.select_all("SELECT * FROM #{table_name}")
        next if result.count.zero?

        rows = result.to_a
        rows.sort_by! { |row| row['id'] } if result.columns.include?('id') # let's make the order of items stable
        acc[table_name] = rows
      end
    end
  end

  attr_reader :records_in_tables # the complete records in the tables

  def initialize(records_in_tables)
    @records_in_tables = records_in_tables
  end

  def load_into_database
    # Here some more pointers on implementation details of fixtures:
    # - https://github.com/rails/rails/blob/2998672fc22f0d5e1a79a29ccb60d0d0e627a430/activerecord/lib/active_record/fixtures.rb#L612
    # - http://api.rubyonrails.org/v5.2.4/classes/ActiveRecord/FixtureSet.html#method-c-create_fixtures
    # - https://github.com/rails/rails/blob/67feba0c822d64741d574dfea808c1a2feedbcfc/activerecord/test/cases/fixtures_test.rb
    #
    # Note from the past (useful if we want to get back to using Rails' +create_fixtures+ method)
    # we used to do: ActiveRecord::FixtureSet.create_fixtures(folder_path, filename_without_extension) # this will also clear the table
    # but we abandoned this approach because we want to one file per fixpoint (not one file per table)
    # ActiveRecord::FixtureSet.reset_cache # create_fixtures does use only the table name as cache key. we always invalidate the cache because we may want to read different fixpoints but with the same table names

    # let's remove all data
    conn.tables.each { |table| conn.select_all("DELETE FROM #{conn.quote_table_name(table)}") }

    # actually insert
    conn.insert_fixtures_set(@records_in_tables)
    self.class.reset_pk_sequences!
  end

  def save_to_file(fixname)
    file_path = self.class.fixpoint_path(fixname)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, contents_for_file)
  end

  def table_names
    @records_in_tables.keys
  end

  # Returns the records for the given +table_name+ as a list of Hashes.
  # +ignore_columns+ array of columns to remove from each record Hash.
  #     Aside from having the form <tt>[:created_at, :updated_at]</tt>,
  #     it can contain attributes scoped by a table name <tt>[:created_at, :updated_at, users: [:password_hash]]</tt>
  def records_for_table(table_name, ignore_columns = [])
    strip_columns_from_records(@records_in_tables[table_name], table_name, ignore_columns)
  end

  protected

  delegate :conn, to: :class

  def contents_for_file
    YAML.dump(@records_in_tables)
  end

  # see #records_for_table
  def strip_columns_from_records(records, table_name, columns)
    return nil if records.nil?

    if columns.last.is_a?(Hash) # columns has the a table names at the end (e.g. [:created_at, :updated_at, users: [:password_hash]])
      columns = columns.dup
      all_table_scoped = columns.pop.stringify_keys
      table_scoped = all_table_scoped[table_name]
      columns += table_scoped if table_scoped
    end
    columns = columns.collect(&:to_s)

    records.collect do |attributes|
      attributes.reject { |col, _value| columns.include?(col) }
    end
  end
end
