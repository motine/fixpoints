# Fixpoints

Fixpoints enables saving, restoring and comparing the database state before & after tests.

This gem came about during my time at [Netskin GmbH](https://www.netskin.com/en). Check it out, we do great (Rails) work there.

## Motivation

When running behavior tests, we seed the database with a defined snapshot called fixpoint.
We do run the behavior test and save the resulting database state as another fixpoint.
This method allows testing complex business processes in legacy applications without having to implement fixtures/factories upfront.
By building one fixpoint on top of another, we can ensure that the process chain works without any gaps.
Comparing each resulting database state at the end of a test with a previously recorded state ensures that refactoring did not have unintended side effects.

**Advantages**

- No need to write fixtures or factories
- discover which records were created/changed by the test’s actions by reading the fixpoint file (YAML)
- get notified about differences in database state (i.e. unintended side effects) after refactoring something
- allow version control to save the "ground truth" at the end of a test

Please check out the full article: [Behavior-Driven Test Data](https://tomrothe.de/posts/behaviour-driven-test-data.html).

## Installation

Add this line to your application's Gemfile: `gem 'fixpoints'` and make sure to add:

```ruby
# rails_helper.rb
RSpec.configure do |config|
  # ...
  config.include FixpointTestHelpers
end
```

## Usage

We save the fixpoint (database snapshot) after the test. Other tests can build on them.

A fixpoint is a snapshot of the database contents as YAML file.
It is saved to the `spec/fixpoints` folder.
The file contains a mapping of table names to a list if their records.
Empty tables are stripped from files.

**Order & Bootstrapping** We need to mind the order though.
When bootstrapping (when there is no fixpoints saved to the disk yet), we need to make sure that all tests that depend on a certain fixpoint run _after_ it was stored.
In a single RSpec file, you can use the order in which the tests are defined (`RSpec.describe 'MyFeature', order: :defined do`).
However, tests in groups might follow a slightly different order (see [RSpec Docs](https://relishapp.com/rspec/rspec-core/docs/configuration/overriding-global-ordering))

```ruby
RSpec.describe 'User Flow', order: :defined do # !!! mind the order here !!!
  it 'registers a user' do
    visit new_user_path
    fill_in 'Name', with: 'Tom'
    click_on 'Save'

    store_fixpoint_unless_present :registered_user
    # creates a YAML file containing all records (/spec/fixpoints/registred_user.yml)
  end

  it 'posts an item' do
    restore_fixpoint :registered_user

    user = User.find_by(name: 'Hans')
    visit new_item_path(user)
    fill_in 'Item', with: '...'
    click_on 'Post'

    compare_fixpoint(:item_posted, store_fixpoint_and_fail: true)
    # compares the database state with the previously saved fixpoint and
    # raises if there is a difference. when there is no previous fixpoint,
    # it writes the fixpoint and fails the test (so it can be re-run)
  end
end
```

**Changes** If you did a lot of changes to a test, you can remove a fixpoint file from its directory.
It will be recreated when the test producing it runs again.
Don't forget re-running the tests based on it because their fixpoints might have to change too.
Example: You need to add something to the database's `seeds.rb`. All subsequent fixpoints are missing the required entry.
To update all fixpoints, just remove the whole `spec/fixpoints` folder and re-run all tests. Now all fixpoints should be updated.
Be careful though, don't just remove the fixpoints if you are not sure what is going on.
A change in a fixpoint might point to an unintended change in code.

We need to be be careful to use `let` and `let!` with factories.
Records might be created twice when using create in there (once by the fixpoint and once by the factory).

**Ignoring columns** Often you might want to add more columns to ignore (e.g. login time stamps):

```ruby
let(:ignored_fixpoint_columns) { [:updated_at, :created_at, users: [:last_login_at] }
# ignores timestamps for all tables, and last_login_at for the users table

it 'logs in' do
  restore_fixpoint :registered_user
  # ...
  compare_fixpoint(:registered_user, ignored_fixpoint_columns)
  # asserts that there is no change
end
```

**Incremental** By the default the `FixpointTestHelpers` use the `IncrementalFixpoint` instead of the more verbose `Fixpoint` version.
This means that only changes are saved to the YAML file.
In order to achieve this, we must make sure that we let the store function know who daddy is.

```ruby
  it 'posts an item' do
    restore_fixpoint :registered_user
    # ...
    compare_fixpoint(fixname, store_fixpoint_and_fail: true, parent_fixname: :registered_user)
    # now only changes to compared to the previous fixpoint are stored
    # instead of using the name of the last restored fixpoint, you can also use `:last_restored`
  end
```

**Multiple Databases** If an application uses multiple databases, you can use the optional `connection` parameter
to specify the database connection to use.

```ruby
  it 'posts an item' do
    restore_fixpoint :registered_user, connection: ActiveRecord::Base.connection
    # ...
  end
```

**Exclude Tables** If a database contains tables that are irrelevant to your tests, you can use the optional `exclude_tables` parameter
to specify a set of tables to exclude from the fixpoint.

```ruby
  it 'excludes versions' do
    restore_fixpoint :registered_user, exclude_tables: ['versions']
    # ...
  end
```

## Limitations & Known issues

- The records in tables are ordered by their id.
    If there is no id for a table, we use database's order (what the SELECT query returns).
    This order may be instable.
- We do not clean the database after each test, depending on your cleaning strategy (e.g. transaction), we might leak primary key sequence counters from one test to another.
    If you have problems try running `Fixpoint.reset_pk_sequences!` and create am issue, so we can investigate.
- Under certain conditions you may get `duplicate key value violates unique constraint` because the primary key sequences are not updated correctly.
    If this happens, just add a `Fixpoint.reset_pk_sequences!` at the beginning of your test. We need to dig a little deeper here at some point...

# Development

```bash
docker run --rm -ti -v (pwd):/app -w /app ruby:2.7 bash
bundle install
rspec
pry # require_relative 'lib/fixpoints.rb'

gem build
gem install fixpoints-0.1.0.gem
pry -r fixpoints
gem uninstall fixpoints
gem push fixpoints
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/motine/fixpoints.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
