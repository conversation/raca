module Raca

  # Wrap an IO object and expose only a partial subset of the underlying data
  # in an IO-ish interface. Calling code will have access to the window of data
  # starting at 'offset' and the following 'length' bytes.
  class WindowedIO
    def initialize(io, offset, length)
      @io = io
      @offset = offset
      if @offset + length > @io.size
        @length = @io.size - offset
      else
        @length = length
      end
      @io.seek(@offset)
    end

    def eof?
      @io.pos >= @offset + @length
    end

    def pos
      @io.pos - @offset
    end

    def seek(to)
      if to <= 0
        @io.seek(@offset)
      elsif to >= @length
        @io.seek(@offset + @length)
      else
        @io.seek(@offset + to)
      end
    end

    def size
      @length
    end

    def each(bytes, &block)
      loop do
        line = read(bytes)
        break if line.nil? || line == ""
        yield line
      end
    end

    def read(bytes = 1024)
      @io.read(capped_bytes_to_read(bytes))
    end

    def readpartial(bytes = 1024, outbuf = nil)
      raise EOFError.new("end of file reached") if eof?
      bytes = capped_bytes_to_read(bytes)
      @io.readpartial(bytes, outbuf)
    end

    private

    def capped_bytes_to_read(bytes)
      if pos + bytes > @length
        size - pos
      else
        bytes
      end
    end
  end
end
