import messages2
import json, options

type
  InitializeRequest* = object
    params*: Option[InitializeParams]

  InitializeResult* = object
    capabilities*: ServerCapabilities
    serverInfo*: ServerInfo

  TextDocumentCompletionRequest* = object
    params*: CompletionParams

  TextDocumentHoverRequest* = object
    params*: HoverParams

  TextDocumentReferencesRequest* = object
    params*: ReferenceParams

  TextDocumentRenameRequest* = object
    params*: RenameParams

  TextDocumentDefinitionRequest* = object
    params*: DefinitionParams

  TextDocumentImplementationRequest* = object
    params*: ImplementationParams

  TextDocumentCodeLensRequest* = object
    params*: CodeLensParams

  TextDocumentSymbolRequest* = object
    params*: DocumentSymbolParams

  CompletionItemResolveRequest* = object
    params*: CompletionItem

  DidOpenTextDocumentNotification* = object
    params*: DidOpenTextDocumentParams

  DidChangedTextDocumentNotification* = object
    params*: DidChangeTextDocumentParams

  DidCloseTextDocumentNotification* = object
    params*: DidCloseTextDocumentParams

  DidSaveTextDocumentNotification* = object
    params*: DidSaveTextDocumentParams
