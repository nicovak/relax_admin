<p align="center">
  <img width="250" src="https://i.imgur.com/mm9gXtL.png" />
</p>

# SlashAdmin

[![Gem Version](https://badge.fury.io/rb/slash_admin.svg)](https://badge.fury.io/rb/slash_admin)
[![CircleCI](https://circleci.com/gh/nicovak/slash_admin/tree/master.svg?style=svg&circle-token=6e9ebd7fef3ebc881c75a769b0970808024a2ae9)](https://circleci.com/gh/nicovak/slash_admin/tree/master)

A modern and fully customizable admin, just the rails way.
Embedded admin user and authentication system, devise is not needded.

❤️ [Demo repository](https://github.com/nicovak/slash_admin_demo)
🚀 [Live running](https://slashadmin.herokuapp.com/admin)

User
`admin`

Password
`admin@admin`

#### Motivation:
- Provide to Ruby On Rails the admin it deserves without DSL or obscure logic.
- Provide an easy to use and modern experience to final users.

I tried to take the best from two greats existing gem:
- [rails_admin](https://github.com/sferik/rails_admin)
- [administrate](https://github.com/thoughtbot/administrate)

Design inspired from the awesome metronic admin theme:
- [keenthemes](http://keenthemes.com/preview/metronic/)

#### Screenshots

##### Login
![Image of Login screen](https://i.imgur.com/ftwC0rF.png)
##### Dashboard
![Image of Dashboard](https://i.imgur.com/3JzkvoT.png)
##### List
![Image of List](https://i.imgur.com/y6Vz6S1.png)
##### Edit / Create
![Image of Create / Edit](https://i.imgur.com/S2QqHWF.png)

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'slash_admin'
```

Then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install slash_admin
```

Gemfile

```
gem 'carrierwave'
```

Then:

```bash
$ rails g slash_admin:install
$ rails slash_admin:install:migrations
$ rails db:migrate
```

`config/initializers/mime_types.rb`

```ruby
Mime::Type.register "application/xls", :xls
```

If your apps uses Sprockets 4+, you'll need to add SlashAdmin assets to your `manifest.js` file. To do this, add these two lines to the file:

`app/assets/config/manifest.js`

```
//= link administrate/application.css
//= link administrate/application.js
```

`config/routes.rb`

```ruby
Rails.application.routes.draw do
  mount SlashAdmin::Engine => "/"
end
```

Mounted as '/' but prefixed in the gem and in routes definition of models admin. See the full example above.

```ruby
Rails.application.routes.draw do
  mount SlashAdmin::Engine => "/"

  namespace :slash_admin, path: "/admin" do
    scope module: 'models' do
      resources :pages # assume Page model
    end
  end
end
```

### Important

If you are using [friendly_id](https://github.com/norman/friendly_id) gem, you have to add `routes: :default` like so:

```ruby
friendly_id :title, use: :history, routes: :default
```

Example of create admin in `seed.rb` in your app:

```ruby
SlashAdmin::Admin.create!(
  username:               'admin',
  email:                  'contact@mysite.com',
  password:               'admin@admin',
  password_confirmation:  'admin@admin'
)
```

### Documentation

[Read the docs](https://github.com/nicovak/slash_admin/tree/master/docs/index.md)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nicovak/slash_admin. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the slash_admin project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nicovak/slash_admin/tree/master/CODE_OF_CONDUCT.md).
