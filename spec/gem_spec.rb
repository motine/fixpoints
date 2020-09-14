RSpec.describe Fixpoints do
  it "has a version number" do
    expect(Fixpoints::VERSION).not_to be nil
  end

  it "database to be setup" do
    book = Book.create!(title: "The Tail of Points that were Fixed")
    expect(Book.count).to eq(1)
  end
end
