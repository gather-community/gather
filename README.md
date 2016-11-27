# MESS
A cohousing meals management system.

## Platform
MESS is a Ruby on Rails application with some client-side JavaScript for dynamic view elements. HTML is generally rendered server-side. [SCSS](http://sass-lang.com/) is used for styling. No special IDE is required for Ruby on Rails development.

Ruby on Rails applications are best developed and run on Linux, Unix, or Mac OS. Development is also possible, though not recommended, on Windows. See the [Rails download page](http://rubyonrails.org/download/) for more information.

## Package Managers

To install the software below we recommend the following package managers:

- Mac OS X: [Homebrew](http://brew.sh/)
- Linux/Unix: bundled package manager (e.g. apt-get, yum)

## System dependencies
1. Ruby v2.2.x (see [.ruby-version file](.ruby-version) for exact version, [rbenv](https://github.com/sstephenson/rbenv) is recommended for Ruby version management)
1. [Bundler](http://bundler.io/)
  1. Once Ruby is installed, run `gem install bundler` to install.
1. PostgreSQL v9.2+ (database)
1. ImageMagick
1. Set up a MESS OAuth client, if you don't have one, on Google Developers.

## Development Setup Guide
Follow these steps to setup a development environment for MESS.

1. **Install all above dependencies**

1. **Retrieve project files using Git**
  ```
  git clone https://github.com/touchstone-cohousing/mess.git
  cd mess
  ```

  If developing, it's best to work off the development branch:
  ```
  git checkout develop
  ```

  The remaining steps should all be done from the project directory.

1. **Install gems**
  1. Run `bundle install` to install the required gems.

1. **Set local config**
  1. Copy `config/initializers/local_config.rb.example` to `config/initializers/local_config.rb`.
  1. Edit `config/initializers/local_config.rb` to fit your environment.

1. **Create development and test databases and schemas**
  1. Copy `config/database.yml.example` to `config/database.yml`.
  1. Run `rake db:create` to create `mess_development` and `mess_test` databases.
  1. Run `rake db:schema:load` to create the schema in both databases.

1. **Create a user so you can log in**
  1. Copy `lib/tasks/fake_user_data.rake.example` to `lib/tasks/fake_user_data.rake`.
  1. Edit `lib/tasks/fake_user_data.rake`, inserting your GMail name.
  1. Run `rake db:fake_user_data` to add one community, one household, and one user (with admin privileges and your GMail address) to the mess_development database.

1. **Run the tests**
  1. Run `bundle exec rspec`.
  1. All tests should pass.

1. **Start the server**
  1. Run `bundle exec rails s`.
  1. Leave this console open.

1. **Start DelayedJob**
  1. Open a new console.
  1. Go to the project directory.
  1. Run `bin/delayed_job start`.

1. **Start using the system**
  1. In a browser, go to `http://localhost:3000` to start MESS.
  1. Click "Log in with Google" to use MESS as the user you just created.
  1. Enjoy!
