RSpec.describe Fixpoint, order: :defined do
  let(:fixpoints_path) { File.join(__dir__, 'fixpoints') }
  let(:connection) { ActiveRecord::Base.connection }

  before(:each) do
    FileUtils.mkdir_p(fixpoints_path)
    Book.delete_all
  end

  after(:all) do
    described_class.remove('fp_one')
    described_class.remove('fp_two')
    described_class.remove('fp_tmp')
  end

  it 'raises if there is no fixpoints path' do # this test must come first, so we do not destroy fixpoints...
    FileUtils.rm_rf(fixpoints_path)
    expect { described_class.from_database(connection).save_to_file('fp_one') }.to raise_error(Fixpoint::Error)
  end

  it 'saves and restores fixpoint' do
    Book.create(title: 'Book A')
    Author.create(first_name: 'Faker', last_name: 'Fakerson')
    described_class.from_database(connection).save_to_file('fp_one')

    # fixpoint contain one book entry, one author entry
    fp = described_class.from_file('fp_one')
    expect(fp.records_in_tables['books'].count).to eq(1)
    expect(fp.records_in_tables['authors'].count).to eq(1)

    # database should have 1 entry
    Book.delete_all
    Author.delete_all
    fp.load_into_database(connection)
    expect(Book.count).to eq(1)
    expect(Book.first.title).to eq('Book A')
    expect(Author.count).to eq(1)
    expect(Author.first.first_name).to eq('Faker')
  end

  it 'saves and restores fixpoint ignoring a table' do
    Book.delete_all
    Author.delete_all
    Book.create(title: 'Book A')
    Author.create(first_name: 'Faker', last_name: 'Fakerson')
    described_class.from_database(connection, exclude_tables: ['authors']).save_to_file('fp_one')

    # fixpoint contain one book entry, no authors
    fp = described_class.from_file('fp_one')
    expect(fp.records_in_tables['books'].count).to eq(1)
    expect(fp.records_in_tables['authors']).to eq(nil)

    # database should have 1 book entry, no authors
    Book.delete_all
    Author.delete_all
    fp.load_into_database(connection)
    expect(Book.count).to eq(1)
    expect(Book.first.title).to eq('Book A')
    expect(Author.count).to eq(0)
  end

  describe IncrementalFixpoint do
    it 'stores & restores new record from parent' do
      described_class.from_file('fp_one').load_into_database(connection)

      Book.create(title: 'Book B')
      described_class.from_database('fp_one', connection).save_to_file('fp_two')

      # fixpoint should contain two entries but the first one empty (because it is incremental)
      fp = described_class.from_file('fp_two')
      expect(fp.changes_in_tables['books'].count).to eq(2)
      expect(fp.changes_in_tables['books'].first.keys.count).to eq(0)

      # database should contain two entries
      fp.load_into_database(connection)
      expect(Book.count).to eq(2)
    end

    it 'stores & restores updated record' do
      described_class.from_file('fp_one').load_into_database(connection)

      Book.find_by(title: 'Book A').update!(summary: 'Lorem and stuff')
      described_class.from_database('fp_one', connection).save_to_file('fp_tmp')

      # fixpoint should contain one entry, with only one change
      fp = described_class.from_file('fp_tmp')
      expect(fp.changes_in_tables['books'].count).to eq(1)
      expect(fp.changes_in_tables['books'].first.keys.count).to eq(1)

      # attribute in database should have changed
      fp.load_into_database(connection)
      expect(Book.first.summary).to eq('Lorem and stuff')
    end

    it 'stores & restores deleted record & restores' do
      described_class.from_file('fp_one').load_into_database(connection)

      Book.find_by(title: 'Book A').destroy
      described_class.from_database('fp_one', connection).save_to_file('fp_tmp')

      # fixpoint should contain one (deletion) entry
      fp = described_class.from_file('fp_tmp')
      expect(fp.changes_in_tables['books'].count).to eq(1)

      # there should be no record in database
      fp.load_into_database(connection)
      expect(Book.count).to eq(0)
    end

    it 'loads chained fixpoints' do
      described_class.from_file('fp_two').load_into_database(connection)

      Book.create(title: 'Book C')
      described_class.from_database('fp_two', connection).save_to_file('fp_tmp')

      # there should be three entries
      described_class.from_file('fp_tmp').load_into_database(connection)
      expect(Book.count).to eq(3)
    end
  end
end
