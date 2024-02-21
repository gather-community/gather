# Gather Deploy

In addition to deploying everything manually as described in the project's root README, you can use Docker Compose or Helm + Kubernetes. For local development, Docker Compose is recommended, but if you are interested in developing in an environment closer to how Gather is deployed in production, you should use the Helm charts along with either [Docker Desktop with Kubernetes](https://docs.docker.com/desktop/kubernetes/) or [Minikube](https://minikube.sigs.k8s.io/docs/).

## Docker Compose

### Requirements
* [Docker Compose V2](https://docs.docker.com/compose/) either installed manually or as part of [Docker Desktop](https://docs.docker.com/desktop/release-notes/)
* A Gather OAuth client via the [Google API Console](https://support.google.com/cloud/answer/6158849?hl=en)
* Ruby (see [.ruby-version file](.ruby-version) for exact version, [rbenv](https://github.com/sstephenson/rbenv) is recommended for Ruby version management)
* [Bundler](http://bundler.io/) installed using `gem install bundler`


### Configuration

Docker Compose is configured with a [YAML file](docker/compose.yml) that describes each service and their environments. You shouldn't need to edit this file unless you're developing the local environment itself. All configuration of Gather and related services can be done with three files defining environment variables:

---

#### [.env](docker/.env)
```shell
# PostgreSQL Configuration
POSTGRES_USER=dev
POSTGRES_PASSWORD=dev
POSTGRES_PORT=5432
POSTGRES_HOST=postgres
PGDATABASE=gather_development
# MinIO Configuration
MINIO_ROOT_USER=dev
MINIO_ROOT_PASSWORD=dev
MINIO_DEFAULT_BUCKETS=gather
```

> [!CAUTION]
> DO NOT ADD SECRETS TO THIS FILE AS IT IS COMMITTED TO THE REPOSITORY. You shouldn't need to edit this file unless you intend to change the default development values.

---

#### [.env.gather](docker/.env.gather)
```shell
# Map Docker environment variables to Gather Settings environment variables
SETTINGS__DATABASE__HOST=$POSTGRES_HOST
SETTINGS__DATABASE__USERNAME=$POSTGRES_USER
SETTINGS__DATABASE__PASSWORD=$POSTGRES_PASSWORD
SETTINGS__DATABASE__PORT=$POSTGRES_PORT
SETTINGS__DATABASE__DATABASE=$PGDATABASE
SETTINGS__OAUTH__GOOGLE__CLIENT_ID=$OAUTH_CLIENT_ID
SETTINGS__OAUTH__GOOGLE__CLIENT_SECRET=$OAUTH_CLIENT_SECRET
```

> [!CAUTION]
> DO NOT ADD SECRETS TO THIS FILE AS IT IS COMMITTED TO THE REPOSITORY. Only edit this file if you need to map additional environment variables to Gather settings.

---

#### [.env.local](docker/.env.local.example)

1. Copy [docker/.env.local.example](docker/.env.local.example) to `docker/.env.local`
2. Set `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` to the values created in the requirements section above.
3. As described in the project README, copy `config/settings.local.yml.example` to `config/settings.local.yml` and configure it as needed. You'll use the same values for everything there that you will in the deploy config. Note that if you aren't planning on running Gather outside of Docker, simply copying the file will be enough to allow you to run `rake secret` in subsequent steps.
4. If you haven't yet run `bundle install` in the project root, run that now.
5. Run `rake secret` and use its output as the value for `GATHER_SECRET_KEY_BASE`
6. Set the email variables to whatever you need

> [!IMPORTANT]
> If you are planning to run Gather outside of Docker and point it at the Dockerized services, edit `config/settings.local.yml` and set all of the values there to the same ones used in this file

```shell
# Environment variables for local docker compose
OAUTH_CLIENT_ID="YOUR VALUE HERE"
OAUTH_CLIENT_SECRET="YOUR VALUE HERE"
# You can create a new secret key by running `rake secret`
GATHER_SECRET_KEY_BASE="YOUR VALUE HERE"
GATHER_EMAIL_FROM="YOUR EMAIL"
GATHER_EMAIL_NO_REPLY="SOME OTHER EMAIL"
GATHER_EMAIL_WEBMASTER="SOME OTHER EMAIL"
```

> [!TIP]
> You can add any secrets to this file that you need and they will be added to the Docker Compose environment. It will be ignored by `git` unless you mess with `.gitignore`. As always, double check your commits to make sure you don't accidentally push secrets.

---

### Deploying

#### First Deployment
1. Make sure all configuration steps above are completed.
2. Trust the development certificate. On a Mac, you can run `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain config/ssl/gatherdev.org.crt`
3. Run `make data-up`
4. Run `make init-dev`