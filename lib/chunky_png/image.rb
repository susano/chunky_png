module ChunkyPNG
  class Image
    
    attr_reader :pixels
    
    def initialize(width, height, background_color = ChunkyPNG::Pixel::TRANSPARENT)
      @pixels = ChunkyPNG::PixelMatrix.new(width, height, background_color)
    end
    
    def width
      pixels.width
    end
    
    def height
      pixels.height
    end
    
    def write(io)
      datastream = ChunkyPNG::Datastream.new

      palette = pixels.palette
      if palette.indexable?
        datastream.header_chunk = ChunkyPNG::Chunk::Header.new(:width => width, :height => height, :color => ChunkyPNG::Chunk::Header::COLOR_INDEXED)
        datastream.palette_chunk = palette.to_plte_chunk
        datastream.data_chunks  = datastream.idat_chunks(pixels.to_pixelstream(ChunkyPNG::Chunk::Header::COLOR_INDEXED, palette))
        datastream.end_chunk    = ChunkyPNG::Chunk::End.new
      else
        datastream.header_chunk = ChunkyPNG::Chunk::Header.new(:width => width, :height => height)
        datastream.data_chunks  = datastream.idat_chunks(pixels.to_pixelstream(ChunkyPNG::Chunk::Header::COLOR_TRUECOLOR))
        datastream.end_chunk    = ChunkyPNG::Chunk::End.new
      end
      
      datastream.write(io)
    end
  end
end