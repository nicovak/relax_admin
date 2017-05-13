# [W.I.P] Relax Admin

A modern and overridable admin, just the rails way.
Embeded admin user and authentication system, devise is not needed.

#### Motivation:
- Provide to rails the admin it deserves without DSL or obscure logic.
- Provide an easy to use and modern experience to final users.
- Improve my personal skill and try rails engine

I tried to take the best from two greats existed gem:
- [rails_admin](https://github.com/sferik/rails_admin)
- [administrate](https://github.com/thoughtbot/administrate)

Design inspired from the awesome metronic admin theme:
- [keenthemes](http://keenthemes.com/preview/metronic/)

#### Screenshots

![Image of Login screen](http://i.imgur.com/HFQ9hfw.jpg)
![Image of List](http://i.imgur.com/p34HUU5.png)
![Image of Create / Edit](http://i.imgur.com/TzOx3i8.png)

### Installation
Add this line to your application's Gemfile:

```ruby
gem 'relax_admin'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install relax_admin
```

```ruby
Rails.application.routes.draw do
  mount RelaxAdmin::Engine => "/admin"
end
```

Then execute:

`rails relax_admin:install:migrations`
`rails db:migrate`

Example of create admin in `seed.rb` in your app:

```ruby
RelaxAdmin::Admin.create!(
  username:               'admin',
  email:                  'contact@mysite.com',
  password:               'admin@admin',
  password_confirmation:  'admin@admin'
)
```

### Techs

- Rails 5
- Bootstrap 4

### Dashboard
- [X] Charts
- [X] Easy widget system
- [ ] I18n
- [ ] Global search

### Create / Edit
- [X] WYSIWYG
- [X] Default params for create
- [X] Nested relations with `nested_attributes`

### List
- [X] Default export of model (excel and csv)
- [X] Filter system + search based on data type
- [X] Batch action
- [X] Pagination
- [ ] Handle `has_one` and `belongs_to`

### Miscellaneous

- [ ] Tests
- [ ] Heroku Demo
- [ ] Wiki
- [ ] Docs

### Generators (for overriding)

- [ ] Install & Initial setup
- [ ] Controllers
- [ ] Views

Icons available:
- http://fontawesome.io/ (eg: `fa fa-home`)
- http://simplelineicons.com/ (eg: `icon-home`)

Exemple of process to add a new 'page' model:

````ruby
module RelaxAdmin::DashboardHelper
  def menu_entries
    [
      {
        title: 'Dashboard',
        path: admin_dashboard_path,
        icon: 'icon-home',
      },
      {
        title: 'Content',
        icon: 'icon-crop',
        sub_menu: [
          {model: Page, icon: 'icon-book-open'},
        ],
      }
    ]
  end
end
````

## routes

No role or acccess security right now.
You can define `except` and `only` on ressources

````ruby
namespace :relax_admin do
  ...
  scope module: 'models' do
    resources :pages
  end
end
````

## Sample controller (mandatory), in `app/controllers/relax_admin/models` folder
For references see: app/controllers/admin/base_controller.rb
Everything is overridable for each controller and each model (params, views, field, etc)

**def list_params; end is mandatory**

````ruby
class AdsController < RelaxAdmin::BaseController
  def list_params
    [
      {attr: :image, type: 'image'},
      :title,
    ]
  end

  def export_params
    [
      :title,
    ]
  end
end
````

### Available and most commons usage

In controller:

```ruby
def handle_default
  @sub_title = nil
  @per = 10
  @page = 1
  @per_values = [10, 20, 50, 100, 150]
  @order_field = :id
  @order = 'DESC'
end
```

## Helpers

```erb
<% page_title('Title') %>
<% page_sub_title('Sub') %>
```

## Widgets
```erb
<%= statistic_progress_tile(title: 'My title', number: 18000, icon: 'fa fa-globe', percent: 80, progress_label: 'progression', status: 'success') %>
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
