# Enhances Fixpoint to only save incremental changes.
#
# A fixpoint can be saved fully, where all records are saved to the file or one can give a parent fixpoint.
# When doing so, only the difference (aka. changes) to the parent is saved in the file.
# Yet, if a record does not change parent an empty hash is saved. This is done, so removals from the database can be tracked.
#
# LIMITATIONS
# Assume you remove a record at the end of a table and then add another one.
# Then the fixpoint diff will complain that an entry has changed instead of noticing the addition/removal.
class IncrementalFixpoint < Fixpoint
  PARENT_YAML_KEY = '++parent_fixpoint++'

  attr_reader :changes_in_tables # only the difference to the parent (in tables)

  def initialize(changes_in_tables, parent_fixname=nil)
    @parent_fixname = parent_fixname
    @changes_in_tables = changes_in_tables
    if parent_fixname.nil?
      super(changes_in_tables)
    else
      parent = self.class.from_file(parent_fixname)
      super(FixpointDiff.apply_changes(parent.records_in_tables, @changes_in_tables))
    end
  end

  def self.from_file(fixname)
    raise Fixpoint::Error, "The requested fixpoint (\"#{fixname}\") could not be found. Re-run the test which stores the fixpoint." unless exists?(fixname)

    file_path = fixpoint_path(fixname)
    changes_in_tables = YAML.load_file(file_path)
    parent_fixname = changes_in_tables.delete(PARENT_YAML_KEY)
    new(changes_in_tables, parent_fixname)
  end

  # Creates a Fixpoint from the database contents. Empty tables are skipped.
  def self.from_database(parent_fixname=nil)
    return super() if parent_fixname.nil?

    parent = from_file(parent_fixname)
    changes_in_tables = FixpointDiff.extract_changes(parent.records_in_tables, read_database_records)
    new(changes_in_tables, parent_fixname)
  end

  protected

  def contents_for_file
    file_contents = @changes_in_tables.dup
    file_contents[PARENT_YAML_KEY] = @parent_fixname unless @parent_fixname.nil?
    return YAML.dump(file_contents)
  end
end

# Helper methods to be included into RSpec
module FixpointTestHelpers
  def restore_fixpoint(fixname)
    IncrementalFixpoint.from_file(fixname).load_into_database
  end

  # Compares the fixpoint with the records in the database.
  # If there is no such fixpoint yet, it will write a new one to the file system.
  # The latter is useful if the fixpoint was deleted to accommodate changes to it (see example in class description).
  #
  # +tables_to_compare+ can either be +:all+ or a list of table names (e.g. ['users', 'posts'])
  # +ignored_columns+ see Fixnum#records_for_table
  # +not_exists_handler+ when given and the fixpoint does not exists, it will be called with the fixname as argument
  # 
  # ---
  # If we refactor this to a gem, we should rely on rspec (e.g. use minitest or move comparison logic to Fixpoint class).
  # Anyhow, we keep it like this for now, because the expectations give much nicer output than the minitest assertions.
  def compare_fixpoint(fixname, ignored_columns=[:updated_at, :created_at], tables_to_compare=:all, &not_exists_handler)
    if !IncrementalFixpoint.exists?(fixname)
      not_exists_handler.call(fixname) if not_exists_handler
      return
    end

    database_fp = IncrementalFixpoint.from_database
    fixpoint_fp = IncrementalFixpoint.from_file(fixname)

    tables_to_compare = (database_fp.table_names + fixpoint_fp.table_names).uniq if tables_to_compare == :all
    tables_to_compare.each do |table_name|
      db_records = database_fp.records_for_table(table_name, ignored_columns)
      fp_records = fixpoint_fp.records_for_table(table_name, ignored_columns)

      # if a table is present in a fixpoint, there must be records in it because empty tables are stripped from fixpoints
      expect(db_records).not_to be_empty, "#{table_name} not in database, but in fixpoint"
      expect(fp_records).not_to be_empty, "#{table_name} not in fixpoint, but in database"
      # we assume that the order of records returned by SELECT is stable (so we do not do any sorting)
      expect(db_records).to eq(fp_records), "Database records for table \"#{table_name}\" did not match fixpoint \"#{fixname}\". Consider removing the fixpoint and re-running the test if the change is intended."
    end
  end

  def store_fixpoint_and_fail(fixname, parent_fixname=nil)
    store_fixpoint(fixname, parent_fixname)
    pending("Fixpoint \"#{fixname}\" did not exist yet. Skipping comparison, but created fixpoint from database")
    fail
  end

  # it is not a good idea to overwrite the fixpoint each time because timestamps may change (which then shows up in version control).
  # Hence we only provide a method to write to it if it does not exist.
  def store_fixpoint_unless_present(fixname, parent_fixname=nil)
    store_fixpoint(fixname, parent_fixname) unless IncrementalFixpoint.exists?(fixname)
  end

  # +parent_fixname+ when given, only the (incremental) changes to the parent are saved
  # please see store_fixpoint_unless_present for note on why not to use this method
  def store_fixpoint(fixname, parent_fixname=nil)
    IncrementalFixpoint.from_database(parent_fixname).save_to_file(fixname)
  end
end
