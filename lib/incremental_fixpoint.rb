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
