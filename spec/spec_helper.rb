require 'raca'
require 'webmock/rspec'


# A custom argument matcher for StringIO objects. Say you have a method call
# like this:
#
#   foo.bar(StringIO.new('chunky bacon'))
#
# This let's you create a mock like so:
#
#     foo.should_receive(:bar).with(string_io_containing("chunky bacon"))
#
require 'rspec/expectations'
RSpec::Matchers.define :string_io_containing do |expected|
  match do |actual|
    actual.is_a?(StringIO) && actual.string == expected
  end
end
