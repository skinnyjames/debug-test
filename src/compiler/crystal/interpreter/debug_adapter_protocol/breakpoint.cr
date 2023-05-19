require "./protocol_message"

module DebugAdapterProtocol
  # algorithim can be: 'MD5' | 'SHA1' | 'SHA256' | 'timestamp';
  record(Checksum, algorithim : String, checksum : String) do
    include JSON::Serializable
  end

  record(
    Source,
    name : String?,
    path : String?,
    sourceReference : Int32?,
    presentationHint : String?,
    origin : String?,
    sources : Array(Source)?,
    adapterData : String?,
    checksums : Array(Checksum)?
  ) do
    include JSON::Serializable
  end

  record(
    SourceBreakpoint,
    line : Int32,
    column : Int32? = nil,
    condition : String? = nil,
    hitCondition : String? = nil,
    logMessage : String? = nil
  ) do
    include JSON::Serializable
  end

  record(
    Breakpoint,
    id : Int32? = nil, 
    verified : Bool = false, 
    message : String? = nil, 
    source : Source? = nil,
    line : Int32? = nil,
    column : Int32? = nil,
    end_line : Int32? = nil,
    end_column : Int32? = nil,
    instructionReference : String? = nil,
    offset : Int32? = nil
  ) do 
    include JSON::Serializable

    def generate_id
      Digest::M
    end
  end

  record BreakpointEventBody, reason : String, breakpoint : Breakpoint do
    include JSON::Serializable
  end

  class BreakPointEvent < Event(BreakpointEventBody)
    include JSON::Serializable

    def initialize(json : String)
      super("breakpoint")
      @body = BreakpointEventBody.from_json(json)
    end
  end

  record SetBreakpointsResponseArgs, breakpoints : Array(Breakpoint) do
    include JSON::Serializable
  end

  record(
    SetBreakpointsArguments,
    source : Source,
    breakpoints : Array(SourceBreakpoint)?,
    lines : Array(Int32)?,
    sourceModified : Bool? = false
  ) do
    include JSON::Serializable
  end
end