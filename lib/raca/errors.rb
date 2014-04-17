module Raca
  # base error for unexpected HTTP responses from rackspace
  class HTTPError < RuntimeError; end

  # for 400 responses from rackspace
  class BadRequestError < HTTPError; end

  # for 401 responses from rackspace
  class NotAuthorizedError < HTTPError; end

  # for 404 responses from rackspace
  class NotFoundError < HTTPError; end

  # for 500 responses from rackspace
  class ServerError < HTTPError; end

  # for rackspace timeouts
  class TimeoutError < RuntimeError; end

end
