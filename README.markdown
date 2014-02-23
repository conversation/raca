# Raca

A simple gem for interacting with Rackspace cloud APIs. The following APIs are
supported:

* Identity
* Cloud Files
* Cloud Servers

Raca intentionally has no dependencies outside the ruby standard library.

If loaded alongside Rails, it will utilise the rails cache to avoid repeated
requests to the rackspace identity API.

## Installation

    gem install raca

## Usage

For full usage details check the documentation for each class, but here's
a taste of the basics.

### Identity

    account = Raca::Account.new("username", "api_key")
    puts account.auth_token
    puts account.public_endpoint("cloudFiles", :ord)
    puts account.service_endpoint("cloudFiles", :ord)

### Cloud Files

    account = Raca::Account.new("username", "api_key")
    dir = account.containers(:ord).get("foo")
    puts dir.list

### Cloud Servers

    account = Raca::Account.new("username", "api_key")
    server = account.servers(:ord).get("foo")
    puts server.public_addresses

## Compatibility

The Raca version number is 0.0.x because it's highly unstable. Until we release
a 1.0.0, consider the API of this gem to be unstable.
