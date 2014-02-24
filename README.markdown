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

### Regions

Many of the Rackspace cloud products are available in multiple regions. When
required, you can specify a region using a symbol with the 3-letter region code.

Currently, the following regions are valid:

* :ord - Chicago
* :iad - Northern Virginia
* :syd - Sydney
* :dfw - Dallas-Fort Worth
* :hkg - Hong Kong

### Identity

To authenticate and begin any interaction with rackspace, you must create a
Raca::Account instance.

    account = Raca::Account.new("username", "api_key")

You can view the token that will be used for subsequent requests:

    puts account.auth_token

Or you can view the URLs for each rackspace cloud API:

    puts account.public_endpoint("cloudFiles", :ord)
    puts account.service_endpoint("cloudFiles", :ord)

### Cloud Files

Using an existing Raca::Account object, retrieve a collection of Cloud Files
containers in a region like so:

    ord_containers = account.containers(:ord)

You can retrieve a single container from the collection:

    dir = ord_containers.get("container_name")

Retrieve some metadata on the collection:

    put ord_containers.metadata

With a single container, you can perform a range of operations on the container
and objects inside it.

    dir = ord_containers.get("container_name")

Download a file:

    dir.download("remote_key.txt", "/home/jh/local_file.txt")

Upload a file:

    dir.upload("target_path.txt", "/home/jh/local_file.txt")

List keys in the container, optionally limiting the results to those
starting with a prefix:

    puts dir.list
    puts dir.list(prefix: "subdir/")

Delete an object:

    dir.delete("target_path.txt")

View metadata on the container:

    puts dir.metadata
    puts dir.cdn_metadata

Enable access to the container contents via a public CDN. Use this with caution, it will make *all* objects public!

It accepts an argument telling the CDN edge nodes how long they can cache each object for (in seconds).

    dir.cdn_enable(60 * 60 * 24) # 1 day

Purge an object from the CDN:

    dir.purge_from_akamai("target_path.txt", "notify@example.com")

Generate a public URL to an object in a private container. The second argument
is the temp URL key that can be set using Raca::Containers#set_temp_url_key

    ord_containers = account.containers(:ord)
    ord_containers.set_temp_url_key("secret")
    dir = ord_containers.get("container_name")
    puts dir.expiring_url("remote_key.txt", "secret", Time.now.to_i + 60)

### Cloud Servers

    account = Raca::Account.new("username", "api_key")
    server = account.servers(:ord).get("foo")
    puts server.public_addresses

## Why not fog?

[fog](http://rubygems.org/gems/fog) is the [official](http://developer.rackspace.com)
ruby library for interacting with the Rackspace API. It is a very capable
library and supports much more of the API than this modest gem.

As of version 1.20.0, fog supports dozens of providers, contains ~152000 lines
of ruby and adds ~500ms to the boot time of our rails apps. raca is a
lightweight alternative with minimal dependencies that should have a negligable
impact on application boot times.

## Compatibility

The Raca version number is < 1.0 because it's highly unstable. Until we release
a 1.0.0, consider the API of this gem to be unstable.
