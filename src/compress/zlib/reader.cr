# A read-only `IO` object to decompress data in the zlib format.
#
# Instances of this class wrap another IO object. When you read from this instance
# instance, it reads data from the underlying IO, decompresses it, and returns
# it to the caller.
class Compress::Zlib::Reader < IO
  include IO::Buffered

  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  # Creates a new reader from the given *io*.
  def initialize(@io : IO, @sync_close = false, dict : Bytes? = nil)
    Compress::Zlib::Reader.read_header(io, dict)
    @flate_io = Compress::Deflate::Reader.new(@io, dict: dict)
    @adler32 = ::Digest::Adler32.initial
    @end = false
  end

  # Creates a new reader from the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false, dict : Bytes? = nil, &)
    reader = new(io, sync_close: sync_close, dict: dict)
    yield reader ensure reader.close
  end

  protected def self.read_header(io, dict)
    cmf = io.read_byte || invalid_header

    cm = cmf & 0xF
    if cm != 8 # the compression method must be 8
      invalid_header
    end

    flg = io.read_byte || invalid_header

    # CMF and FLG, when viewed as a 16-bit unsigned integer stored
    # in MSB order (CMF*256 + FLG), must be a multiple of 31
    unless (cmf.to_u16*256 + flg.to_u16).divisible_by?(31)
      invalid_header
    end

    fdict = flg.bit(5) == 1
    if fdict
      unless dict
        raise Compress::Zlib::Error.new("Missing dictionary")
      end

      checksum = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
      dict_checksum = ::Digest::Adler32.checksum(dict)
      if checksum != dict_checksum
        raise Compress::Zlib::Error.new("Dictionary ADLER-32 checksum mismatch")
      end
    end
  end

  # See `IO#read`.
  def unbuffered_read(slice : Bytes) : Int32
    check_open

    return 0 if slice.empty?
    return 0 if @end

    read_bytes = @flate_io.read(slice)
    if read_bytes == 0
      # Check ADLER-32
      @end = true
      @flate_io.close
      adler32 = @io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
      if adler32 != @adler32
        raise Compress::Zlib::Error.new("ADLER-32 checksum mismatch")
      end
    else
      # Update ADLER-32 checksum
      @adler32 = ::Digest::Adler32.update(slice[0, read_bytes], @adler32)
    end
    read_bytes
  end

  # Always raises `IO::Error` because this is a read-only `IO`.
  def unbuffered_write(slice : Bytes) : NoReturn
    raise IO::Error.new "Can't write to Compress::Zlib::Reader"
  end

  def unbuffered_flush : NoReturn
    raise IO::Error.new "Can't flush Compress::Zlib::Reader"
  end

  def unbuffered_close : Nil
    return if @closed
    @closed = true

    @flate_io.close
    @io.close if @sync_close
  end

  def unbuffered_rewind : Nil
    check_open

    @io.rewind

    initialize(@io, @sync_close, @flate_io.dict)
  end

  protected def self.invalid_header
    raise Compress::Zlib::Error.new("Invalid header")
  end
end
