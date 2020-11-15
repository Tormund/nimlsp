import messageenums
import json, options, options, tables
# import jsonschema
# import sequtils


# Anything below here comes from the LSP specification
type
  Message* = object of RootObj
    jsonrpc: string

  Params* = object of RootObj
  ResponseErrorData* = object of RootObj

  RequestMessage* = object of Message
    # id: int or float or string
    id: JsonNode
    `method`: string
    params: Option[JsonNode] # todo: think about use Params

  ResponseMessage* = object of Message
    # id: int or float or string or nil
    id: JsonNode
    `result`: Option[JsonNode] # todo: think about use ResponseResult
    error: Option[ResponseError]

  ResponseError* = object
    # code: int or float
    code*: int
    message*: string
    data*: Option[JsonNode] # todo: think about use ResponseErrorData here

  NotificationMessage* = object of Message
    `method`: string
    params: Option[JsonNode]

  CancelParams* = object
    # id: int or float or string
    id: JsonNode

  #todo: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress

  Position* = object
    line*: int
    character*: int

  Range* = object
    start*: Position
    `end`*: Position

  DocumentUri* = string

  Location* = object
    uri*: DocumentUri
    `range`*: Range

  LocationLink* = object
    originSelectionRange*: Option[Range]
    targetUri*: DocumentUri
    targetRange*: Range
    targetSelectionRange*: Range

  Diagnostic* = object
    `range`*: Range
    severity*: Option[int]
    code: Option[JsonNode] # int | string
    source*: Option[string]
    message*: Option[string]
    tags*: Option[int]
    relatedInformation*: Option[seq[DiagnosticRelatedInformation]]

  DiagnosticRelatedInformation* = object
    location*: Location
    message*: string

  Command* = object
    title*: string
    command*: string
    arguments: Option[JsonNode]

  TextEdit* = object
    `range`*: Range
    newText*: string

  TextDocumentEdit* = object
    textDocument*: VersionedTextDocumentIdentifier
    edits*: seq[TextEdit]

  #todo: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#resourceChanges

  WorkspaceEdit* = object
    changes*: Option[Table[DocumentUri, seq[TextEdit]]] # This is a uri(string) to TextEdit[] mapping
    documentChanges*: Option[seq[TextDocumentEdit]]

  #todo: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspaceEditClientCapabilities

  TextDocumentIdentifier* = object of RootObj
    uri*: DocumentUri

  TextDocumentItem* = object
    uri*: DocumentUri
    languageId*: string
    version*: int
    text*: string

  VersionedTextDocumentIdentifier* = object of TextDocumentIdentifier
    version*: Option[int] # int | nil
    languageId*: Option[string] # SublimeLSP adds this field erroneously

  TextDocumentPositionParams* = object
    textDocument*: TextDocumentIdentifier
    position*: Position

  DocumentFilter* = object
    language*: Option[string]
    scheme*: Option[string]
    pattern*: Option[string]

  StaticRegistrationOptions* = object
    id*: Option[string]

  TextDocumentRegistrationOptions* = object
    documentSelector*: Option[seq[DocumentFilter]]

  # TextDocumentAndStaticRegistrationOptions* extends TextDocumentRegistrationOptions:
  #   id?: string

  MarkupContent* = object
    kind*: MarkupKind
    value*: string

  #todo: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workDoneProgress

  ClientInfo* = object
    name*: string
    version*: Option[string]

  InitializeParams* = object of Params
    processId*: Option[int] # int | nil
    rootPath*: Option[string] # string | nil
    rootUri*: Option[DocumentUri] # DocumentUri | nil
    initializationOptions: Option[JsonNode]
    capabilities*: ClientCapabilities
    trace*: Option[Trace] # 'off' or 'messages' or 'verbose'
    workspaceFolders*: Option[seq[WorkspaceFolder]] # seq[WorkspaceFolder] | nil

# **********************
  BaseClientCapabilities* = object of RootObj
    dynamicRegistration*: Option[bool]

  TextDocumentSyncClientCapabilities* = object of BaseClientCapabilities
    willSave*: Option[bool]
    willSaveWaitUntil*: Option[bool]
    didSave*: Option[bool]

  CompletionClientCapabilities* = object of BaseClientCapabilities
    completionItem*: Option[CompletionItemCapability]
    completionItemKind*: Option[CompletionItemKindCapability]
    contextSupport*: Option[bool]

  CompletionItemCapability* = object
    snippetSupport*: Option[bool]
    commitCharactersSupport*: Option[bool]
    documentFormat*: Option[seq[MarkupKind]] # MarkupKind
    deprecatedSupport*: Option[bool]
    preselectSupport*: Option[bool]
    tagSupport*: Option[CompletionItemKindCapability]

  BaseValueSet*[T] = object of RootObj
    valueSet*: Option[seq[T]]

  CompletionItemKindCapability* = object of BaseValueSet[int]

  HoverClientCapabilities* = object of BaseClientCapabilities
    contentFormat*: Option[seq[MarkupKind]]

  SignatureInformationCapability* = object
    documentationFormat*: Option[seq[MarkupKind]]

  SignatureHelpClientCapabilities* = object of BaseClientCapabilities
    signatureInformation*: Option[SignatureInformationCapability]
    contextSupport*: Option[bool]

  DeclarationClientCapabilities* = object of BaseClientCapabilities
    linkSupport*: Option[bool]

  DefinitionClientCapabilities* = object of DeclarationClientCapabilities
  TypeDefinitionClientCapabilities* = object of DeclarationClientCapabilities
  ImplementationClientCapabilities* = object of DeclarationClientCapabilities
  ReferenceClientCapabilities* = object of BaseClientCapabilities
  DocumentHighlightClientCapabilities* = object of BaseClientCapabilities

  DocumentSymbolClientCapabilities* = object of BaseClientCapabilities
    symbolKind*: Option[BaseValueSet[int]]
    hierarchicalDocumentSymbolSupport*: Option[bool]

  CodeActionLiteralSupport* = object
    codeActionKind*: BaseValueSet[CodeActionKind]

  CodeActionClientCapabilities* = object of BaseClientCapabilities
    codeActionLiteralSupport*: Option[CodeActionLiteralSupport]
    isPreferredSupport*: Option[bool]

  CodeLensClientCapabilities* = object of BaseClientCapabilities
  DocumentLinkClientCapabilities* = object of BaseClientCapabilities
    tooltopSupport*: Option[bool]
  DocumentColorClientCapabilities* = object of BaseClientCapabilities
  DocumentFormattingClientCapabilities* = object of BaseClientCapabilities
  DocumentRangeFormattingClientCapabilities* = object of BaseClientCapabilities
  DocumentOnTypeFormattingClientCapabilities* = object of BaseClientCapabilities
  RenameClientCapabilities* = object of BaseClientCapabilities
    prepareSupport*: Option[bool]

  PublishDiagnosticsClientCapabilities* = object
    relatedInformation*: Option[bool]
    tagSupport*: Option[BaseValueSet[int]]
    versionSupport*: Option[bool]

  FoldingRangeClientCapabilities* = object of BaseClientCapabilities
    rangeLimit*: Option[int]
    lineFoldingOnly*: Option[bool]

  SelectionRangeClientCapabilities* = object of BaseClientCapabilities
# ****************

  TextDocumentClientCapabilities* = object
    synchronization*: Option[TextDocumentSyncClientCapabilities]
    completion*: Option[CompletionClientCapabilities]
    hover*: Option[HoverClientCapabilities]
    signatureHelp*: Option[SignatureHelpClientCapabilities]
    declaration*: Option[DeclarationClientCapabilities]
    definition*: Option[DefinitionClientCapabilities]
    typeDefinition*: Option[TypeDefinitionClientCapabilities]
    implementation*: Option[ImplementationClientCapabilities]
    references*: Option[ReferenceClientCapabilities]
    documentHighlight*: Option[DocumentHighlightClientCapabilities]
    documentSymbol*: Option[DocumentSymbolClientCapabilities]
    codeAction*: Option[CodeActionClientCapabilities]
    codeLens*: Option[CodeLensClientCapabilities]
    documentLink*: Option[DocumentLinkClientCapabilities]
    colorProvider*: Option[DocumentColorClientCapabilities]
    formatting*: Option[DocumentFormattingClientCapabilities]
    rangeFormatting*: Option[DocumentRangeFormattingClientCapabilities]
    onTypeFormatting*: Option[DocumentOnTypeFormattingClientCapabilities]
    rename*: Option[RenameClientCapabilities]
    publishDiagnostics*: Option[PublishDiagnosticsClientCapabilities]
    foldingRange*: Option[FoldingRangeClientCapabilities]
    selectionRange*: Option[SelectionRangeClientCapabilities]

  WorkspaceEditClientCapabilities* = object
    label*: Option[string]
    edit*: Option[WorkspaceEdit]

  DidChangeConfigurationClientCapabilities* = ref object of BaseClientCapabilities
  DidChangeWatchedFilesClientCapabilities* = ref object of BaseClientCapabilities
  WorkspaceSymbolClientCapabilities* = ref object of BaseClientCapabilities
    symbolKind*: Option[BaseValueSet[int]]
  ExecuteCommandClientCapabilities* = ref object of BaseClientCapabilities

  WorkspaceClientCapabilities* = object
    applyEdit*: Option[bool]
    workspaceEdit*: Option[WorkspaceEditClientCapabilities]
    didChangeConfiguration*: Option[DidChangeConfigurationClientCapabilities]
    didChangeWatchedFiles*: Option[DidChangeWatchedFilesClientCapabilities]
    symbol*: Option[WorkspaceSymbolClientCapabilities]
    executeCommand*: Option[ExecuteCommandClientCapabilities]
    workspaceFolders*: Option[bool]
    configuration*: Option[bool]

  ClientCapabilities* = object
    # workspace*: Option[WorkspaceClientCapabilities]
    textDocument*: Option[TextDocumentClientCapabilities]
    experimental*: Option[JsonNode]

  ServerInfo* = object
    name*: string
    version*: string

  InitializeError* = object
    retry*: bool


  CompletionOptions* = object
    triggerCharacters*: seq[string]
    allCommitCharacters*: Option[seq[string]]
    resolveProvider*: bool

  SignatureHelpOptions* = object
    triggerCharacters*: Option[seq[string]]
    retriggerCharacters*: Option[seq[string]]

  CodeLensOptions* = object
    resolveProvider*: Option[bool]

  DocumentLinkOptions* = object
    resolveProvider*: Option[bool]

  DocumentOnTypeFormattingOptions* = object
    firstTriggerCharacter*: Option[string]
    moreTriggerCharacter*: Option[seq[string]]

  ExecuteCommandOptions* = object
    commands*: seq[string]

  WorkspaceFoldersServerCapabilities* = object
    supported*: Option[bool]
    changeNotification*: Option[string] # string | bool

  WorkspaceServerCapability* = object
    workspaceFolders*: Option[WorkspaceFoldersServerCapabilities]

  TextDocumentSyncOptions* = object
    openClose*: bool
    change*: int # or float
    # willSave?: bool
    # willSaveWaitUntil?: bool
    # save?: SaveOptions

  ServerCapabilities* = object
    textDocumentSync*: TextDocumentSyncOptions #TextDocumentSyncOptions | int
    completionProvider*: CompletionOptions
    hoverProvider*: bool
    signatureHelpProvider*: Option[SignatureHelpOptions]
    declarationProvider*: bool
    definitionProvider*: bool
    typeDefinitionProvider*: bool # or TextDocumentAndStaticRegistrationOptions
    implementationProvider*: bool # or TextDocumentAndStaticRegistrationOptions
    referencesProvider*: bool
    documentHighlightProvider*: bool
    documentSymbolProvider*: bool
    codeActionProvider*: bool
    codeLensProvider*: Option[CodeLensOptions]
    documentLinkProvider*: Option[DocumentLinkOptions]
    colorProvider*: bool
    documentFormattingProvider*: bool
    documentRangeFormattingProvider*: bool
    documentOnTypeFormattingProvider*: Option[DocumentOnTypeFormattingOptions]
    renameProvider*: bool
    foldingRangeProvider*: bool
    executeCommandProvider*: Option[ExecuteCommandOptions]
    selectionRangeProvider*: bool
    workspaceSymbolProvider*: bool
    workspace*: Option[WorkspaceServerCapability]
    experimental*: Option[JsonNode]

  InitializedParams* = object of Params

  ShowMessageParams* = object of Params
    `type`*: int # MessageType
    message*: string

  ShowMessageRequestParams* = object of ShowMessageParams
    actions*: Option[seq[MessageActionItem]]

  MessageActionItem* = object
    title*: string

  LogMessageParams* = object of ShowMessageParams

  Registration* = object
    id*: string
    `method`*: string

  WorkspaceFolder* = object
    uri*: DocumentUri
    name*: string

  #   registrationOptions?: any

  # RegistrationParams:
  #   registrations: Registration[]

  # Unregistration:
  #   id: string
  #   "method": string

  # UnregistrationParams:
  #   unregistrations: Unregistration[]

  # WorkspaceEditCapability:
  #   documentChanges?: bool

  # DidChangeConfigurationCapability:
  #   dynamicRegistration?: bool

  # DidChangeWatchedFilesCapability:
  #   dynamicRegistration?: bool

  # SymbolKindCapability:
  #   valueSet?: int # SymbolKind enum

  # SymbolCapability:
  #   dynamicRegistration?: bool
  #   symbolKind?: SymbolKindCapability

  # ExecuteCommandCapability:
  #   dynamicRegistration?: bool


  # SynchronizationCapability:
  #   dynamicRegistration?: bool
  #   willSave?: bool
  #   willSaveWaitUntil?: bool
  #   didSave?: bool

  # CompletionItemCapability:
  #   snippetSupport?: bool
  #   commitCharactersSupport?: bool
  #   documentFormat?: string[] # MarkupKind
  #   deprecatedSupport?: bool

  # CompletionItemKindCapability:
  #   valueSet?: int[] # CompletionItemKind enum

  # CompletionCapability:
  #   dynamicRegistration?: bool
  #   completionItem?: CompletionItemCapability
  #   completionItemKind?: CompletionItemKindCapability
  #   contextSupport?: bool

  # HoverCapability:
  #   dynamicRegistration?: bool
  #   contentFormat?: string[] # MarkupKind

  # SignatureInformationCapability:
  #   documentationFormat?: string[] # MarkupKind

  # SignatureHelpCapability:
  #   dynamicRegistration?: bool
  #   signatureInformation?: SignatureInformationCapability

  # ReferencesCapability:
  #   dynamicRegistration?: bool

  # DocumentHighlightCapability:
  #   dynamicRegistration?: bool

  # DocumentSymbolCapability:
  #   dynamicRegistration?: bool
  #   symbolKind?: SymbolKindCapability

  # FormattingCapability:
  #   dynamicRegistration?: bool

  # RangeFormattingCapability:
  #   dynamicRegistration?: bool

  # OnTypeFormattingCapability:
  #   dynamicRegistration?: bool

  # DefinitionCapability:
  #   dynamicRegistration?: bool

  # TypeDefinitionCapability:
  #   dynamicRegistration?: bool

  # ImplementationCapability:
  #   dynamicRegistration?: bool

  # CodeActionCapability:
  #   dynamicRegistration?: bool

  # CodeLensCapability:
  #   dynamicRegistration?: bool

  # DocumentLinkCapability:
  #   dynamicRegistration?: bool

  # ColorProviderCapability:
  #   dynamicRegistration?: bool

  # RenameCapability:
  #   dynamicRegistration?: bool

  # PublishDiagnosticsCapability:
  #   dynamicRegistration?: bool


  # CodeLensOptions:
  #   resolveProvider?: bool

  # DocumentOnTypeFormattingOptions:
  #   firstTriggerCharacter: string
  #   moreTriggerCharacter?: string[]

  # DocumentLinkOptions:
  #   resolveProvider?: bool

  # ExecuteCommandOptions:
  #  commands: string[]

  # SaveOptions:
  #   includeText?: bool

  # ColorProviderOptions:
  #   DUMMY?: nil # This is actually an empty object

  # WorkspaceFolderCapability:
  #   supported?: bool
  #   changeNotifications?: string or bool




  # WorkspaceFoldersChangeEvent:
  #   added: WorkspaceFolder[]
  #   removed: WorkspaceFolder[]

  # DidChangeWorkspaceFoldersParams:
  #   event: WorkspaceFoldersChangeEvent

  # DidChangeConfigurationParams:
  #   settings: any

  # ConfigurationParams:
  #   "items": ConfigurationItem[]

  # ConfigurationItem:
  #   scopeUri?: string
  #   section?: string

  # FileEvent:
  #   uri: string # DocumentUri
  #   "type": int # FileChangeType

  # DidChangeWatchedFilesParams:
  #   changes: FileEvent[]

  # DidChangeWatchedFilesRegistrationOptions:
  #   watchers: FileSystemWatcher[]

  # FileSystemWatcher:
  #   globPattern: string
  #   kind?: int # WatchKindCreate (bitmap)

  # WorkspaceSymbolParams:
  #   query: string

  # ExecuteCommandParams:
  #   command: string
  #   arguments?: any[]

  # ExecuteCommandRegistrationOptions:
  #   commands: string[]

  # ApplyWorkspaceEditParams:
  #   label?: string
  #   edit: WorkspaceEdit

  # ApplyWorkspaceEditResponse:
  #   applied: bool

  # DidOpenTextDocumentParams:
  #   textDocument: TextDocumentItem

  # DidChangeTextDocumentParams:
  #   textDocument: VersionedTextDocumentIdentifier
  #   contentChanges: TextDocumentContentChangeEvent[]

  # TextDocumentContentChangeEvent:
  #   range?: Range
  #   rangeLength?: int or float
  #   text: string

  # TextDocumentChangeRegistrationOptions extends TextDocumentRegistrationOptions:
  #   syncKind: int or float

  # WillSaveTextDocumentParams:
  #   textDocument: TextDocumentIdentifier
  #   reason: int # TextDocumentSaveReason

  # DidSaveTextDocumentParams:
  #   textDocument: TextDocumentIdentifier
  #   text?: string

  # TextDocumentSaveRegistrationOptions extends TextDocumentRegistrationOptions:
  #   includeText?: bool

  # DidCloseTextDocumentParams:
  #   textDocument: TextDocumentIdentifier

  # PublishDiagnosticsParams:
  #   uri: string # DocumentUri
  #   diagnostics: Diagnostic[]

  # CompletionParams extends TextDocumentPositionParams:
  #   context?: CompletionContext

  # CompletionContext:
  #   triggerKind: int # CompletionTriggerKind
  #   triggerCharacter?: string

  # CompletionList:
  #   isIncomplete: bool
  #   "items": CompletionItem[]

  # CompletionItem:
  #   label: string
  #   kind?: int # CompletionItemKind
  #   detail?: string
  #   documentation?: string or MarkupContent
  #   deprecated?: bool
  #   preselect?: bool
  #   sortText?: string
  #   filterText?: string
  #   insertText?: string
  #   insertTextFormat?: int #InsertTextFormat
  #   textEdit?: TextEdit
  #   additionalTextEdits?: TextEdit[]
  #   commitCharacters?: string[]
  #   command?: Command
  #   data?: any

  # CompletionRegistrationOptions extends TextDocumentRegistrationOptions:
  #   triggerCharacters?: string[]
  #   resolveProvider?: bool

  # MarkedStringOption:
  #   language: string
  #   value: string

  # Hover:
  #   contents: string or MarkedStringOption or string[] or MarkedStringOption[] or MarkupContent
  #   range?: Range

  # SignatureHelp:
  #   signatures: SignatureInformation[]
  #   activeSignature?: int or float
  #   activeParameter?: int or float

  # SignatureInformation:
  #   label: string
  #   documentation?: string or MarkupContent
  #   parameters?: ParameterInformation[]

  # ParameterInformation:
  #   label: string
  #   documentation?: string or MarkupContent

  # SignatureHelpRegistrationOptions extends TextDocumentRegistrationOptions:
  #   triggerCharacters?: string[]

  # ReferenceParams extends TextDocumentPositionParams:
  #   context: ReferenceContext

  # ReferenceContext:
  #   includeDeclaration: bool

  # DocumentHighlight:
  #   "range": Range
  #   kind?: int # DocumentHighlightKind

  # DocumentSymbolParams:
  #   textDocument: TextDocumentIdentifier

  # SymbolInformation:
  #   name: string
  #   kind: int # SymbolKind
  #   deprecated?: bool
  #   location: Location
  #   containerName?: string

  # CodeActionParams:
  #   textDocument: TextDocumentIdentifier
  #   "range": Range
  #   context: CodeActionContext

  # CodeActionContext:
  #   diagnostics: Diagnostic[]

  # CodeLensParams:
  #   textDocument: TextDocumentIdentifier

  # CodeLens:
  #   "range": Range
  #   command?: Command
  #   data?: any

  # CodeLensRegistrationOptions extends TextDocumentRegistrationOptions:
  #   resolveProvider?: bool

  # DocumentLinkParams:
  #   textDocument: TextDocumentIdentifier

  # DocumentLink:
  #   "range": Range
  #   target?: string # DocumentUri
  #   data?: any

  # DocumentLinkRegistrationOptions extends TextDocumentRegistrationOptions:
  #   resolveProvider?: bool

  # DocumentColorParams:
  #   textDocument: TextDocumentIdentifier

  # ColorInformation:
  #   "range": Range
  #   color: Color

  # Color:
  #   red: int or float
  #   green: int or float
  #   blue: int or float
  #   alpha: int or float

  # ColorPresentationParams:
  #   textDocument: TextDocumentIdentifier
  #   color: Color
  #   "range": Range

  # ColorPresentation:
  #   label: string
  #   textEdit?: TextEdit
  #   additionalTextEdits?: TextEdit[]

  # DocumentFormattingParams:
  #   textDocument: TextDocumentIdentifier
  #   options: any # FormattingOptions

  # #FormattingOptions:
  # #  tabSize: int or float
  # #  insertSpaces: bool
  # #  [key: string]: boolean | int or float | string (jsonschema doesn't support variable key objects)

  # DocumentRangeFormattingParams:
  #   textDocument: TextDocumentIdentifier
  #   "range": Range
  #   options: any # FormattingOptions

  # DocumentOnTypeFormattingParams:
  #   textDocument: TextDocumentIdentifier
  #   position: Position
  #   ch: string
  #   options: any # FormattingOptions

  # DocumentOnTypeFormattingRegistrationOptions extends TextDocumentRegistrationOptions:
  #   firstTriggerCharacter: string
  #   moreTriggerCharacter?: string[]

  # RenameParams:
  #   textDocument: TextDocumentIdentifier
  #   position: Position
  #   newName: string
