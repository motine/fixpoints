RSpec.describe Fixpoint, order: :defined do
  after(:all) do
    Fixpoint.remove(:some_fixpoint)
  end

  it 'fails comparison if fixpoint does not exist' do # this needs to be tested _before_ we store the fixpoint
    expect { compare_fixpoint(:some_fixpoint) }.to raise_error(Fixpoint::Error)
  end

  it 'stores the fixpoint if fixpoint does not exist exist' do # this needs to be tested _before_ we store the fixpoint
    # TODO
    # expect { compare_fixpoint(:some_fixpoint, store_fixpoint_and_fail: true) }.not_to raise_error
    # expect { restore_fixpoint :some_fixpoint }.not_to raise_error # this would fail if it did not store the fixpoint
    # Fixpoint.remove(:some_fixpoint)
  end

  it 'stores fixpoints' do
    Book.create!(title: 'Super Book')
    store_fixpoint_unless_present :some_fixpoint
  end

  it 'restores fixpoints' do
    restore_fixpoint :some_fixpoint
    expect(Book.count).to eq(1)
    expect(Book.first.title).to eq('Super Book')
  end

  it 'compare does nothing when equal' do
    restore_fixpoint :some_fixpoint
    expect { compare_fixpoint(:some_fixpoint) }.not_to raise_error
  end

  it 'compare raises on difference' do
    restore_fixpoint :some_fixpoint
    Book.first.update!(title: 'Changed Title')
    expect { compare_fixpoint(:some_fixpoint) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end
end
