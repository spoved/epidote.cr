# epidote

[![Build Status](https://travis-ci.com/spoved/epidote.cr.svg?branch=master)](https://travis-ci.com/spoved/epidote.cr)

Epidote is yet another ORM for crystal.

## Goals of Epidote

There are a couple differences from most other ORMs but the main goals are the following:

* Provide support for RW and RO connections
* Provide support for UUID and JSON objects
* Keep model definition simple
  * Define all attributes, indexes, and options via macros
  * All model methods should be generated off the information provided in definition

## Database Support

Currently the following databases are supported:

* Mongo 4
* MySQL 8

### Features

The following model actions are currently supported on all models:

| Action | Method     | Static | Description                                           |
| ------ | ---------- | ------ | ----------------------------------------------------- |
| create | `.save`    | no     | Will save a new record                                |
| delete | `.destroy` | no     | Will delete an existing record                        |
| update | `.update`  | no     | Will update an existing record with changes           |
| query  | `.query`   | yes    | Will return an array of records that match query      |
| find   | `.find`    | yes    | Will return single record that matches the primary id |
| all    | `.all`     | yes    | Will return an array of all records                   |
| each   | `.each`    | yes    | Will yield each record to block                       |

### TODO: Missing Features / Future Enhancements

The following are possible additions that may come over time but are missing now.

* Relations
* Pagination for queries and `.all`

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     epidote:
       github: spoved/epidote.cr
   ```

2. Run `shards install`

## Usage

Example models are found in: [](spec/fixtures.cr). Documentation can be generated via `crystal doc` and verbose examples are found in the specs.

### Environmental Variables

The following are the env variables you should set to allow epidote to establish connections to the database. All envs follow the `<adapter>_<var>` pattern.

```text
MONGODB_HOST=127.0.0.1
MONGODB_PORT=27017
MONGODB_USER=root
MONGODB_PASS=example
MONGODB_DB_NAME=epidote_test

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASS=mysql
MYSQL_DB_NAME=epidote_test
```

In addition setting envs with `<adapter>_RO_HOST` or `<adapter>_RO_PORT` will establish RO connections that will be used for querying. In the example below we define the DNS name of the master which will be used for any Creates, Deletes, or Updates. Then a RO loadbalancer DNS entry is defined for any Read operations.

```text
# RW Host information
MYSQL_HOST=mysql-master.mysql.svc.cluster.local
MYSQL_PORT=3306

# RO Host information
MYSQL_RO_HOST=mysql-slaves.mysql.svc.cluster.local
MYSQL_RO_PORT=3306

# Shared credentials
MYSQL_USER=root
MYSQL_PASS=mysql
MYSQL_DB_NAME=epidote_test
```

### MongoDB example

```crystal
require "epidote/model/mongo"

class MyModel::Mongo < Epidote::Model::Mongo
  collection(:my_model)
  attributes(name: String, unique_name: {
    index:  true,
    unique: true,
    type:   String,
  })
  attribute :default_value, String, default: "a string"
  attribute :not_nil_value, Int32, not_nil: true

  add_index [:id, :unique_name], unique: true
end
```

### MySQL example

```crystal
require "epidote/model/mysql"

class MyModel::MySQL < Epidote::Model::MySQL
  table(:my_model)
  attributes(
    id: {
      primary_key:    true,
      type:           Int32,
      auto_increment: true,
    },
    name: String,
    unique_name: {
      index:  true,
      unique: true,
      type:   String,
    })

  attribute :default_value, String, default: "a string"
  attribute :not_nil_value, Int32, not_nil: true
  attribute :uuid, UUID
  attribute :extra_data, JSON::Any

  add_index [:id, :unique_name], unique: true
end
```

## Development

Testing can be done via `docker-compose` and a `.env` file. The default `.env` values for the specs are defined above. The example MySQL database and table will be created automatically by the docker container, but for manual tests you will need to load [](spec/mysql/mysql.sql) before running specs.

## Contributing

1. Fork it (<https://github.com/spoved/epidote.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

* [Holden Omans](https://github.com/kalinon) - creator and maintainer
