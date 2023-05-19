require "./protocol_message"

module DebugAdapterProtocol
  # Initialize request
  record(
    InitializeRequestArguments,
    clientId : String?,
    clientName : String?,
    adapterId : String?,
    locale : String?,
    lineStartAt1 : Bool?,
    columnStartAt1 : Bool?,
    pathFormat : String?,
    supportsVariableType : Bool?,
    supportsVariablePaging : Bool?,
    supportsRunInTerminalRequest : Bool?,
    supportsMemoryReferences : Bool?,
    supportsProgressReporting : Bool?,
    supportsInvalidateEvent : Bool?,
    supportsMemoryEvent : Bool?,
    supportsArgsCanBeInterpretedByShell : Bool?,
    supportsStartDebuggingRequest : Bool?
  ) do 
    include JSON::Serializable
  end

  class InitializeRequest < Request(InitializeRequestArguments)
    property command : String = "initialize"
    property arguments : InitializeRequestArguments?
  end

  # Initalize response
  record(
    Capabilities,
    supportsConfigurationDoneRequest : Bool = true,
    supportsFunctionBreakpoints : Bool = false,
    supportsConditionalBreakpoints : Bool = false,
    supportsHitConditionalBreakpoints : Bool = false,
    supportsEvaluateForHovers : Bool = false,
    exceptionBreakpointFilters : Nil = nil, # well.. look it up if you care ;)
    supportsStepBack : Bool = false,
    supportsSetVariable : Bool = false,
    supportsRestartFrame : Bool = false,
    supportsGotoTargetRequest : Bool = false,
    supportsStepInTargetsRequest : Bool = false,
    supportsCompletionsRequest : Bool = false,
    completionTriggerCharacters : Array(String)? = nil,
    supportsModulesRequest : Bool = false,
    additionalModuleColumns : Nil = nil, # ditto
    supportedChecksumAlgorithims : Nil = nil,
    supportsRestartRequest : Bool = false,
    supportsExceptionOptions : Bool = false,
    supportsValueFormattingOptions : Bool = false,
    supportsExceptionInfoRequest : Bool = false,
    supportTerminateDebuggee : Bool = false,
    supportSuspendDebuggee : Bool = false,
    supportsDelayedStackTraceLoading : Bool = false,
    supportsLoadedSourcesRequest : Bool = false,
    supportsLogPoints : Bool = false,
    supportsTerminateThreadsRequest : Bool = false,
    supportsSetExpression : Bool = false,
    supportsTerminateRequest : Bool = false,
    supportsDataBreakpoints : Bool = false,
    supportsReadMemoryRequest : Bool = false,
    supportsWriteMemoryRequest : Bool = false,
    supportsDisassembleRequest : Bool = false,
    supportsCancelRequest : Bool = false,
    supportsBreakpointLocationsRequest : Bool = false,
    supportsClipboardContext : Bool = false,
    supportsSteppingGranularity : Bool = false,
    supportsInstructionBreakpoints : Bool = false,
    supportsExceptionFilterOptions : Bool = false,
    supportsSingleThreadExectutionRequests : Bool = false
  ) do
    include JSON::Serializable
  end

  class InitializeResponse < Response(Capabilities)
  end
end