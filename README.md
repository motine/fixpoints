# Fixpoints

Fixpoints enables saving, restoring and comparing the database state before & after tests.

## Motivation

TODO

Link to `https://tomrothe.de/posts/behaviour-driven-test-data.html`

## Usage

Add this line to your application's Gemfile: `gem 'fixpoints'`

TODO: Write usage instructions here


```ruby
# TODO: update this code
it 'registers a user' do
  visit new_user_path
  fill_in 'Name', with: 'Hans'
  click_on 'Save'

  store_fixpoint :registred_user
  # creates YAML files containing all records (/spec/fixpoints/[table_name].yml)
end

it 'posts an item' do
  restore_fixpoint :registered_user
  
  user = User.find_by(name: 'Hans')
  visit new_item_path(user)
  fill_in 'Item', with: '...'
  click_on 'Post'

  compare_fixpoint(:posted_item, ignore_columns: [:release_date], store_fixpoint_and_fail: true)
  # compares the database state with the previously saved fixpoint and
  # raises if there is a difference. when there is no previous fixpoint,
  # it writes it and fails the test (so it can be re-run)  
end
```

## Development

```bash
docker run --rm -ti -v (pwd):/app -w /app ruby:2.7 bash
bundle install
rspec
pry # require_relative 'lib/fixpoints.rb'

gem build
gem install fixpoints-0.1.0.gem
pry -r fixpoints
gem uninstall fixpoints
```


## Development

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/motine/fixpoints.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
