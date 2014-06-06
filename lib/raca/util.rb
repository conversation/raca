module Raca
  # Misc helper methods used across the codebase
  class Util
    # CGI.escape, but without special treatment on spaces
    def self.url_encode(str)
      str.gsub(%r{([^a-zA-Z0-9_./-])}) do |match|
        '%' + match.unpack('H*').first.scan(/../).join("%").upcase
      end
    end
  end
end
