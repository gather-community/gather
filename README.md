# Gather

The App for Community - https://info.gather.coop

## Platform
Gather is a Ruby on Rails application with some client-side JavaScript for dynamic view elements. HTML is generally rendered server-side. [SCSS](http://sass-lang.com/) is used for styling. No special IDE is required for Ruby on Rails development.

Ruby on Rails applications are best developed and run on Linux, Unix, or Mac OS. Development is also possible, though not recommended, on Windows. See the [Rails download page](http://rubyonrails.org/download/) for more information.

## System Dependencies
To install the software below we recommend the following package managers:

- Mac OS X: [Homebrew](http://brew.sh/)
- Linux/Unix: bundled package manager (e.g. apt-get, yum)

For both production and development environments:

1. Ruby (see [.ruby-version file](.ruby-version) for exact version, [rbenv](https://github.com/sstephenson/rbenv) is recommended for Ruby version management)
1. [Bundler](http://bundler.io/)
    1. Once Ruby is installed, run `gem install bundler` to install.
1. Node.js (see [.nvmrc file](.nvmrc) for exact version, nvm is recommended for Node version management)
1. Yarn (`npm install -g yarn`)
1. PostgreSQL 9.2+ (database)
1. Redis 4.0+ (cache, key-value store)
1. Elasticsearch 6.2+ (search engine) (Can be installed via homebrew on Mac OS X)
1. libvips v8.8+ (image manipulation; PNG, JPG, and GIF support needed)
1. Mailcatcher for testing email (run `gem install mailcatcher` to install).
    1. Note, this gem is deliberately not in the Gemfile because it is a standalone development tool.
1. A Gather OAuth client via the [Google API Console](https://support.google.com/cloud/answer/6158849?hl=en).
1. Mailman 3 (see instructions below).

## Development Environment Setup

Follow these steps to setup a development environment for Gather.

1. Install all above dependencies
    1. **Note:** For Elasticsearch, we recommend setting the maximum heap size to 200m unless you have lots of memory on your development machine. To do so, edit the `jvm.options` file. [See here for instructions](https://stackoverflow.com/a/40333263/2066866).
    1. For Mailman 3:
      1. Mailman is only required if you're working on the Mailman API integration. If so...
        mkdir ../mailman && cd ../mailman
        python3 -m venv venv
        source venv/bin/activate
        pip3 install mailman
        mailman start
        curl -v http://restadmin:restpass@localhost:8001/3.1/lists
        pip3 install postorius hyperkitty whoosh
        git clone https://github.com/gather-community/mailman-suite.git
        cd mailman-suite/mailman-suite_project/
        git clone https://github.com/gather-community/discoursessoclient.git
        python3 manage.py migrate
        python3 manage.py collectstatic
        python3 manage.py runserver
        curl -v http://localhost:8000 # To test. Run in a new tab.
1. Retrieve project files using Git
        git clone https://github.com/gather-community/gather.git
        cd gather

    If developing, it's best to work off the development branch:

        git checkout develop

    The remaining steps should all be done from the project directory.
1. Install gems
    1. Run `bundle install` to install the required gems.
1. Set local config
    1. Copy `config/settings.local.yml.example` to `config/settings.local.yml`.
    1. Edit `config/settings.local.yml` to fit your environment. Be sure to read all the comments within that file for guidance.
1. Create development and test databases and schemas
    1. Copy `config/database.yml.example` to `config/database.yml`.
    1. Run `rake db:create` to create `gather_development` and `gather_test` databases.
    1. Run `rake db:schema:load` to create the schema in both databases.
1. Create some fake data and a user so you can sign in
    1. Run:
            rake db:new_cluster ADMIN_FNAME="Your" ADMIN_LNAME="Name" ADMIN_EMAIL="you@example.com" SUPER_ADMIN=y
        to add one cluster, one community, and a full complement of fake data. This command will also add a user with superadmin privileges with the Gmail address you entered in `settings.local.yml`.
1. Run the tests
    1. Run `bundle exec rspec`.
    1. All tests should pass.
1. Ensure Redis is running.
    1. If you installed via Homebrew, try `brew services start redis`.
    1. If you are on Linux try `sudo systemctl start redis` or `sudo service redis start`.
1. Trust the development certificate
    1. On MacOS you can do `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain config/ssl/gatherdev.org.crt`.
    2. On other platforms you will need to figure this out. Search for "trust local ssl certificate".
1. Install javascript packages
    1. Run `yarn install`
1. Start the server
    1. Run `bin/dev`.
    1. Leave this console open.
1. Start DelayedJob
    1. Open a new console.
    1. Go to the project directory.
    1. Run `bin/delayed_job run`.
    1. The logs for jobs will mostly go to log/development.log. The log/delayed_job.log file is sparse and
       contains only information about the initialization and resulting state of jobs.
1. Start using the system
    1. In a browser, go to `https://gatherdev.org:3000` to start Gather.
    1. Sign in with the username and password created in rake new_cluster task (the username and password will be shown in the output.)
    1. Enjoy!

Later, to re-start your development environment, the following should be sufficient:

    bundle install
    bundle exec rake db:migrate
    brew services start redis

To run the rails console you will need to set a tenant:
    1. At the console run `CH.tenant(1)` or whatever Community id you would like.

And if working with Mailman, in a separate terminal:

    cd ../mailman
    source venv/bin/activate
    mailman start
    cd mailman-suite/mailman-suite_project/
    python3 manage.py runserver

## Caching

Caching is off by default in development mode since it can lead to confusing issues where changes to views don't show up.

If you are testing some caching behavior you can enable it temporarily by doing:

```
CACHE=1 rails server
```

## Linters

Linters are strongly recommended for checking your code. The CI system will run linters as well and pull requests won't be approved until all issues are resolved or cancelled by the reviewer. We recommend eslint, rubocop, and scss_lint.

### Troubleshooting

If the Elasticsearch index is returning 403 errors, try the following to reset the index (assumes development environment is where the problem is ocurring):

```
rails console -e development
Work::Shift.__elasticsearch__.create_index!(force: true)
```

After re-creating the search index in development mode, if you want to be able to search existing data, you'll need to re-populate the index:

    ActsAsTenant.current_tenant = Cluster.find(...)
    Work::Shift.find_each { |s| s.__elasticsearch__.index_document }

### Tools
Most code editors have plugins for linting. They will identify and let you click directly into problematic lines. You are encouraged to try one out!

## Acknowledgements
This project is happily tested with BrowserStack!
[![Tested with BrowserStack](https://www.browserstack.com/images/layout/browserstack-logo-600x315.png)](https://www.browserstack.com)
