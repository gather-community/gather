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

## Development Setup Guide
Follow these steps to setup a development environment for MESS.

1. **Install all above dependencies**

1. **Retrieve project files using Git**

  ```
  git clone ssh://git@github.com:touchstonecohousing/mess.git
  cd mess
  ```

  If developing, it's best to work off the development branch:

  ```
  git checkout develop
  ```

1. **Set local config**
  - `cp config/initializers/local_config.rb.example config/initializers/local_config.rb`
  - Edit `config/initializers/local_config.rb` to set config specific to your environment.

1. **Create development and test databases**
  - See `createdb` command.
  - Should be named `mess_development` and `mess_test`.
  - Ensure adquate privileges for table creation, etc.

1. **Insert a row in the users table so you can login**
  - e.g. `INSERT INTO users (email, google_email, created_at, updated_at) VALUES ('you@example.com', 'you@gmail.com', now(), now())`
  - Replace `you@gmail.com` with a Google account you control.

1. **Bundle, configure, and migrate**
  - Install the required gems by running `bundle install` in the project directory.
  - Run database migrations: `bundle exec rake db:migrate`.

1. **Run the tests**
  - Run `bundle exec rspec`.
  - All tests should pass.

1. **Start the server**
  - Run `bundle exec rails s`.

1. **Start using the system**
  - Navigate to http://localhost:3000
  - Login with the Google account given above
  - Enjoy!
