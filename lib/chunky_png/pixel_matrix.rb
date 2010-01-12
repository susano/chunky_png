module ChunkyPNG
  
  class PixelMatrix
    
    FILTER_NONE    = 0
    FILTER_SUB     = 1
    FILTER_UP      = 2
    FILTER_AVERAGE = 3
    FILTER_PAETH   = 4
    
    attr_reader :width, :height, :pixels
    
    def self.load(header, content)
      matrix = self.new(header.width, header.height)
      matrix.decode_pixelstream(content, header)
      return matrix
    end
    
    def [](x, y)
      @pixels[y * width + x]
    end
    
    def each_scanline(&block)
      height.times do |i|
        scanline = @pixels[width * i, width]
        yield(scanline)
      end
    end
    
    def []=(x, y, pixel)
      @pixels[y * width + x] = pixel
    end
    
    def initialize(width, height, background_color = ChunkyPNG::Pixel::WHITE)
      @width, @height = width, height
      @pixels = Array.new(width * height, background_color)
    end

    def decode_pixelstream(stream, header = nil)
      verify_length!(stream.length)
      @pixels = []
      
      pixel_size = Pixel.bytesize(header.color)
      decoded_bytes = Array.new(header.width * pixel_size, 0)
      height.times do |line_no|
        position       = line_no * (width * pixel_size + 1)
        line_length    = header.width * pixel_size
        bytes          = stream.unpack("@#{position}CC#{line_length}")
        filter         = bytes.shift
        decoded_bytes  = decode_scanline(filter, bytes, decoded_bytes, header)
        decoded_colors = decode_colors(decoded_bytes, header)
        @pixels += decoded_colors.map { |c| Pixel.new(c) }
      end
      
      raise "Invalid amount of pixels" if @pixels.size != width * height
    end
    
    def decode_colors(bytes, header)
      # TODO: other color modes / pixel size
      (0...width).map { |i| ChunkyPNG::Pixel.rgb(bytes[i*3+0], bytes[i*3+1], bytes[i*3+2]) }
    end
    
    def decode_scanline(filter, bytes, previous_bytes, pixelsize = 3)
      case filter
      when FILTER_NONE    then decode_scanline_none( bytes, previous_bytes, pixelsize)
      when FILTER_SUB     then decode_scanline_sub(  bytes, previous_bytes, pixelsize)
      when FILTER_UP      then decode_scanline_up(   bytes, previous_bytes, pixelsize)
      when FILTER_AVERAGE then raise "Average filter are not yet supported!"
      when FILTER_PAETH   then raise "Paeth filter are not yet supported!"
      else raise "Unknown filter type"
      end
    end
    
    def decode_scanline_none(bytes, previous_bytes, pixelsize = 3)
      bytes
    end
    
    def decode_scanline_sub(bytes, previous_bytes, pixelsize = 3)
      bytes.each_with_index { |b, i| bytes[i] = (b + (i >= pixelsize ? bytes[i-pixelsize] : 0)) % 256 }
      bytes
    end
    
    def decode_scanline_up(bytes, previous_bytes, pixelsize = 3)
      bytes.each_with_index { |b, i| bytes[i] = (b + previous_bytes[i]) % 256 }
      bytes
    end
    
    def verify_length!(bytes_count, pixelsize = 3)
      raise "Invalid stream length!" unless bytes_count == width * height * pixelsize + height
    end
    
    def encode_scanline(filter, bytes, previous_bytes = nil, pixelsize = 3)
      case filter
      when FILTER_NONE    then encode_scanline_none( bytes, previous_bytes, pixelsize)
      when FILTER_SUB     then encode_scanline_sub(  bytes, previous_bytes, pixelsize)
      when FILTER_UP      then encode_scanline_up(   bytes, previous_bytes, pixelsize)
      when FILTER_AVERAGE then raise "Average filter are not yet supported!"
      when FILTER_PAETH   then raise "Paeth filter are not yet supported!"
      else raise "Unknown filter type"
      end
    end
    
    def encode_scanline_none(bytes, previous_bytes = nil, pixelsize = 3)
      [FILTER_NONE] + bytes
    end
    
    def encode_scanline_sub(bytes, previous_bytes = nil, pixelsize = 3)
      encoded = (pixelsize...bytes.length).map { |n| (bytes[n-pixelsize] - bytes[n]) % 256 }
      [FILTER_SUB] + bytes[0...pixelsize] + encoded
    end
    
    def encode_scanline_up(bytes, previous_bytes, pixelsize = 3)
      encoded = (0...bytes.length).map { |n| previous_bytes[n] - bytes[n] % 256 }
      [FILTER_UP] + encoded
    end
    
    def palette
      ChunkyPNG::Palette.from_pixels(@pixels)
    end
    
    def opaque?
      pixels.all? { |pixel| pixel.opaque? }
    end
    
    def indexable?
      palette.indexable?
    end
    
    def to_pixelstream(color_mode = ChunkyPNG::Chunk::Header::COLOR_TRUECOLOR, palette = nil)
      
      pixel_encoder = case color_mode
        when ChunkyPNG::Chunk::Header::COLOR_TRUECOLOR       then lambda { |pixel| pixel.to_rgb_bytes }
        when ChunkyPNG::Chunk::Header::COLOR_TRUECOLOR_ALPHA then lambda { |pixel| pixel.to_rgba_bytes }
        when ChunkyPNG::Chunk::Header::COLOR_INDEXED         then lambda { |pixel| pixel.index(palette) }
        else "Cannot encode pixels for this mode: #{color_mode}!"
      end
      
      pixelsize = Pixel.bytesize(color_mode)
      
      stream = ""
      each_scanline do |line|
        bytes  = line.map(&pixel_encoder).flatten
        stream << encode_scanline(FILTER_NONE, bytes, nil, pixelsize).pack('C*')
      end
      return stream
    end
  end
end