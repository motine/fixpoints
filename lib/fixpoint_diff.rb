# Helper module which implements diff-ing for fixpoints
module FixpointDiff
  DELETED_KEY = '++DELETED++'
  IGNORE_ATTRIBUTES = ['updated_at']


  def apply_changes(parent_records_in_tables, changes_in_tables)
    tables = (parent_records_in_tables.keys + changes_in_tables.keys).uniq

    tables.each_with_object({}) do |table, records|
      records[table] = apply_records_changes(parent_records_in_tables[table], changes_in_tables[table])
    end
  end

  def extract_changes(parent_records_in_tables, records_in_tables)
    tables = (parent_records_in_tables.keys + records_in_tables.keys).uniq

    tables.each_with_object({}) do |table, changes_in_tables|
      changes_in_tables[table] = extract_records_changes(parent_records_in_tables[table], records_in_tables[table])
    end
  end

  module_function :apply_changes, :extract_changes

  protected

  def apply_records_changes(parent_records, changes)
    return parent_records if changes.blank?

    parent_records ||= [] # the table was not part of an earlier fixpoint
    changes.zip(parent_records).collect do |change, parent_record| # we can rely on the fact that changes has always more entries than parent_records
      next change if parent_record.nil? # we do have a new record
      next nil if change[DELETED_KEY]

      parent_record.merge(change)
    end.compact
  end

  def extract_records_changes(parent_records, records)
    return records if parent_records.blank?
    records ||= []

    # we pad parent_records with nil values so we can zip them together
    parent_records = parent_records + [nil] * (records.count - parent_records.count) if parent_records.count < records.count
    
    parent_records.zip(records).collect do |parent, record|
      next { DELETED_KEY => true } if record.nil?
      next record if parent.nil? # newly added record

      parent.each_with_object({}) do |(parent_key, parent_value), changes| # we can rely on the fact that both hashes have the same attributes
        record_value = record[parent_key]
        changes[parent_key] = record_value unless record_value == parent_value || IGNORE_ATTRIBUTES.include?(parent_key)
      end
    end
  end

  module_function :apply_records_changes, :extract_records_changes
end
