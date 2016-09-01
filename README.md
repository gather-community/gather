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

1. **Install gems in the project**
  - Run `bundle install`

1. **Set local config**
  - Copy `config/initializers/local_config.rb.example` to `config/initializers/local_config.rb`
  - Edit `config/initializers/local_config.rb` as follows:
      Get `<client ID>` and `<client secret>` from your Google Developers MESS OAuth client.
      Get a `<secret key>` by running `rake secret`
      Replace `<hostname>` with your web and smtp servers. 

1. **Create development and test databases**
  - Copy `config/database.yml.example` to `config/database.yml`
  - Create development and test databases: `rake db:create`
  - Create schema in both databases: `rake db:schema:load`

1. **Seed the db** 
  - Copy `db/seeds.rb.example` to `db/seeds.rb`
  - Edit `db/seeds.rb`: replace `<your gmail name>` with your GMail name.
  - Run `rake db:seed` to create one community, household, and user (with admin privileges and your gmail name)

1. **Run the tests**
  - Run `bundle exec rspec`
  - All tests should pass.

1. **Start the server**
  - Run `bundle exec rails s`
  - Leave this console open.

1. **Start DelayedJob**
  - Open a new console.
  - Go to the project directory.
  - Run `bin/delayed_job start`

1. **Start using the system**
  - Open `http://localhost:3000` in a browser
  - Click `Log in with Google`
  - Enjoy!
