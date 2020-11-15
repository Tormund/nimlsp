import nimlsppkg / [ baseprotocol, utfmapping, suggestlib, utils, protocol, messages2, messageenums ]
# include nimlsppkg / messages
import streams, tables, strutils, os, hashes, json, options

const
  version = block:
    var version = "0.0.0"
    let nimbleFile = staticRead(currentSourcePath().parentDir().parentDir() / "nimlsp.nimble")
    for line in nimbleFile.splitLines:
      let keyval = line.split("=")
      if keyval.len == 2:
        if keyval[0].strip == "version":
          version = keyval[1].strip(chars = Whitespace + {'"'})
          break
    version
  # This is used to explicitly set the default source path
  explicitSourcePath {.strdefine.} = getCurrentCompilerExe().parentDir.parentDir

var nimpath = explicitSourcePath


var
  ins = newFileStream(stdin)
  outs = newFileStream(stdout)
  gotShutdown = false
  initialized = false
  projectFiles = initTable[string, tuple[nimsuggest: NimSuggest, openFiles: int]]()
  openFiles = initTable[string, tuple[projectFile: string, fingerTable: seq[seq[tuple[u16pos, offset: int]]]]]()
  messageHandlers = initTable[string, proc(message: JsonNode): JsonNode]()

# proc parseId(node: JsonNode): int =
#   if node.kind == JString:
#     parseInt(node.getStr)
#   elif node.kind == JInt:
#     node.getInt
#   else:
#     raise newException(MalformedFrame, "Invalid id node: " & repr(node))

# proc respond(request: RequestMessage, data: JsonNode) =
#   let resp = create(ResponseMessage, "2.0", parseId(request["id"]), some(data), none(ResponseError)).JsonNode
#   debugLog("respond <<<< ", resp)
#   outs.sendJson(resp)

# proc error(request: RequestMessage, errorCode: int, message: string, data: JsonNode) =
#   outs.sendJson create(ResponseMessage, "2.0", parseId(request["id"]), none(JsonNode), some(create(ResponseError, errorCode, message, data))).JsonNode

# proc notify(notification: string, data: JsonNode) =
#   outs.sendJson create(NotificationMessage, "2.0", notification, some(data)).JsonNode

template respond(req, resp: JsonNode) =
  var r = newJObject()
  r["id"] = req{"id"}
  r["result"] = resp
  # resp["id"] = req{"id"}
  debugLog(">> ", r)
  outs.sendJson(r)

template getNimsuggest(fileuri: string): Nimsuggest =
  projectFiles[openFiles[fileuri].projectFile].nimsuggest

# proc handleRequest(message: JsonNode) =

proc registerMessageHandler*(str: string, cb: proc(msg: JsonNode): JsonNode) =
  messageHandlers[str] = cb

proc none[T](field: var Option[T]) =
  field = none(T)

registerMessageHandler("initialize") do(msg: JsonNode) -> JsonNode:
  debugLog "got initialize request ", msg
  var request = msg.to(InitializeRequest)
  var resp: InitializeResult

  resp.serverInfo.name = "nimlsp"
  resp.serverInfo.version = version & "beta"

  resp.capabilities.textDocumentSync.openClose = true
  resp.capabilities.textDocumentSync.change = TextDocumentSyncKind.Full.int
  resp.capabilities.completionProvider.resolveProvider = true
  resp.capabilities.completionProvider.triggerCharacters = @[".", " "]
  resp.capabilities.hoverProvider = true
  resp.capabilities.declarationProvider = false
  resp.capabilities.definitionProvider = true
  # resp.capabilities.typeDefinitionProvider = true
  # resp.capabilities.implementationProvider = true
  resp.capabilities.referencesProvider = true
  resp.capabilities.completionProvider.allCommitCharacters.none()
  resp.capabilities.signatureHelpProvider.none()
  resp.capabilities.codeLensProvider.none()
  resp.capabilities.documentLinkProvider.none()
  resp.capabilities.documentOnTypeFormattingProvider.none()
  resp.capabilities.executeCommandProvider.none()
  resp.capabilities.workspace.none()
  resp.capabilities.experimental.none()
  # documentHighlightProvider
  # resp.capabilities.renameProvider = true
  debugLog("resp 0")
  debugLog("resp ", %resp)
  result = %resp

# registerMessageHandler("textDocument/completion") do(msg: JsonNode) -> JsonNode:

debugLog("nimlsp starting...")

proc serve() =
  debugLog("Version: " & version & "gg")
  debugLog("explicitSourcePath: " & explicitSourcePath)
  for i in 1..paramCount():
    debugLog("Argument " & $i & ": " & paramStr(i))

  if paramCount() == 1:
    case paramStr(1):
      of "--help":
        echo "Usage: nimlsp [OPTION | PATH]\n"
        echo "--help, shows this message"
        echo "--version, shows only the version"
        echo "PATH, path to the Nim source directory, defaults to \"", nimpath, "\""
        quit 0
      of "--version":
        echo "nimlsp v", version, "wtf"
        quit 0
      else: nimpath = expandFilename(paramStr(1))
  if not existsFile(nimpath / "config/nim.cfg"):
    stderr.write "Unable to find \"config/nim.cfg\" in \"" & nimpath & "\". " &
      "Supply the Nim project folder by adding it as an argument.\n"
    quit 1

  debugLog "*** NIMLSP STARTED! ***"

  while true:
    try:
      debugLog "Trying to read frame"
      let frame = ins.readFrame
      let message = frame.parseJson
      let meth = message{"method"}.getStr()
      let handler = messageHandlers.getOrDefault(meth)
      debugLog meth, " handler ", handler.isNil
      if not handler.isNil:
        var resp = handler(message)
        if resp.isNil:
          message.respond(resp)
      else:
        debugLog "Unknown message ", message
      continue

    except Exception as e:
      debugLog "Got exception: ", e.msg, "\n", getStackTrace(e)
      continue

serve()
debugLog("Exit nimlsp")


      # whenValid(message, RequestMessage):
      #   debugLog "Got valid Request message of type " & message["method"].getStr
      #   if not initialized and message["method"].getStr != "initialize":
      #     message.error(-32002, "Unable to accept requests before being initialized", newJNull())
      #     continue
      #   case message["method"].getStr:
      #     of "shutdown":
      #       debugLog "Got shutdown request, answering"
      #       message.respond(newJNull())
      #       gotShutdown = true
      #     of "initialize":
      #       debugLog "Got initialize request, answering"
      #       initialized = true
      #       message.respond(create(InitializeResult, create(ServerCapabilities,
      #         textDocumentSync = some(create(TextDocumentSyncOptions,
      #           openClose = some(true),
      #           change = some(TextDocumentSyncKind.Full.int),
      #           willSave = some(false),
      #           willSaveWaitUntil = some(false),
      #           save = some(create(SaveOptions, some(true)))
      #         )), # ?: TextDocumentSyncOptions or int or float
      #         hoverProvider = some(true), # ?: bool
      #         completionProvider = some(create(CompletionOptions,
      #           resolveProvider = some(true),
      #           triggerCharacters = some(@[".", " "])
      #         )), # ?: CompletionOptions
      #         signatureHelpProvider = none(SignatureHelpOptions),
      #         #signatureHelpProvider = some(create(SignatureHelpOptions,
      #         #  triggerCharacters = some(@["(", ","])
      #         #)), # ?: SignatureHelpOptions
      #         definitionProvider = some(true), #?: bool
      #         typeDefinitionProvider = none(bool), #?: bool or TextDocumentAndStaticRegistrationOptions
      #         implementationProvider = none(bool), #?: bool or TextDocumentAndStaticRegistrationOptions
      #         referencesProvider = some(true), #?: bool
      #         documentHighlightProvider = none(bool), #?: bool
      #         documentSymbolProvider = none(bool), #?: bool
      #         workspaceSymbolProvider = none(bool), #?: bool
      #         codeActionProvider = none(bool), #?: bool
      #         codeLensProvider = none(CodeLensOptions), #?: CodeLensOptions
      #         documentFormattingProvider = none(bool), #?: bool
      #         documentRangeFormattingProvider = none(bool), #?: bool
      #         documentOnTypeFormattingProvider = none(DocumentOnTypeFormattingOptions), #?: DocumentOnTypeFormattingOptions
      #         renameProvider = some(true), #?: bool
      #         documentLinkProvider = none(DocumentLinkOptions), #?: DocumentLinkOptions
      #         colorProvider = none(bool), #?: bool or ColorProviderOptions or TextDocumentAndStaticRegistrationOptions
      #         executeCommandProvider = none(ExecuteCommandOptions), #?: ExecuteCommandOptions
      #         workspace = none(WorkspaceCapability), #?: WorkspaceCapability
      #         experimental = none(JsonNode) #?: any
      #       )).JsonNode)
      #     of "textDocument/completion":
      #       message.textDocumentRequest(CompletionParams, compRequest):
      #         debugLog "Running equivalent of: sug ", fileuri.toPath(), ";", filestash, ":",
      #           rawLine + 1, ":",
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         let suggestions = getNimsuggest(fileuri).sug(fileuri.toPath(), dirtyfile = filestash,
      #           rawLine + 1,
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         )
      #         debugLog "Found suggestions: ",
      #           suggestions[0..(if suggestions.len > 10: 10 else: suggestions.high)],
      #           (if suggestions.len > 10: " and " & $(suggestions.len-10) & " more" else: "")
      #         var completionItems = newJarray()
      #         for suggestion in suggestions:
      #           completionItems.add(
      #             create(
      #               CompletionItem,
      #               label = suggestion.qualifiedPath[^1],
      #               kind = some(nimSymToLSPKind(suggestion).int),
      #               detail = some(nimSymDetails(suggestion)),
      #               documentation = some(suggestion.nimDocstring),
      #               deprecated = none(bool),
      #               preselect = none(bool),
      #               sortText = none(string),
      #               filterText = none(string),
      #               insertText = none(string),
      #               insertTextFormat = none(int),
      #               textEdit = none(TextEdit),
      #               additionalTextEdits = none(seq[TextEdit]),
      #               commitCharacters = none(seq[string]),
      #               command = none(Command),
      #               data = none(JsonNode)
      #             ).JsonNode
      #           )
      #         message.respond completionItems
      #     of "textDocument/hover":
      #       message.textDocumentRequest(TextDocumentPositionParams, hoverRequest):
      #         debugLog "Running equivalent of: def ", fileuri.toPath(), ";", filestash, ":",
      #           rawLine + 1, ":",
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar), ">>>>"
      #         let suggestions = getNimsuggest(fileuri).def(fileuri.toPath(), dirtyfile = filestash,
      #           rawLine + 1,
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         )
      #         debugLog "Found suggestions: ",
      #           suggestions[0..(if suggestions.len > 10: 10 else: suggestions.high)],
      #           (if suggestions.len > 10: " and " & $(suggestions.len-10) & " more" else: "")
      #         if suggestions.len == 0:
      #           message.respond newJNull()
      #         else:
      #           var label = suggestions[0].qualifiedPath.join(".")
      #           if suggestions[0].forth != "":
      #             label &= ": " & suggestions[0].forth
      #           let
      #             wordLen = (if suggestions[0].qualifiedPath.len > 0: suggestions[0].qualifiedPath[^1].len else: 0)
      #             rangeopt =
      #               some(create(Range,
      #                 create(Position, rawLine, rawChar),
      #                 create(Position, rawLine, rawChar + wordLen)
      #               ))
      #             markedString = create(MarkedStringOption, "nim", label)
      #           if suggestions[0].doc != "":
      #             message.respond create(Hover,
      #               @[
      #                 markedString,
      #                 create(MarkedStringOption, "", suggestions[0].nimDocstring),
      #               ],
      #               rangeopt
      #             ).JsonNode
      #           else:
      #             message.respond create(Hover, markedString, rangeopt).JsonNode
      #     of "textDocument/references":
      #       message.textDocumentRequest(ReferenceParams, referenceRequest):
      #         debugLog "Running equivalent of: use ", fileuri.toPath(), ";", filestash, ":",
      #           rawLine + 1, ":",
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         let suggestions = getNimsuggest(fileuri).use(fileuri.toPath(), dirtyfile = filestash,
      #           rawLine + 1,
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         )
      #         debugLog "Found suggestions: ",
      #           suggestions[0..(if suggestions.len > 10: 10 else: suggestions.high)],
      #           (if suggestions.len > 10: " and " & $(suggestions.len-10) & " more" else: "")
      #         var response = newJarray()
      #         for suggestion in suggestions:
      #           if suggestion.section == ideUse or referenceRequest["context"]["includeDeclaration"].getBool:
      #             response.add(create(Location,
      #               suggestion.filepath.pathToUri(),
      #               create(Range,
      #                 create(Position, suggestion.line-1, suggestion.column),
      #                 create(Position, suggestion.line-1, suggestion.column + suggestion.qualifiedPath[^1].len)
      #               )
      #             ).JsonNode)
      #         if response.len == 0:
      #           message.respond newJNull()
      #         else:
      #           message.respond response
      #     of "textDocument/rename":
      #       message.textDocumentRequest(RenameParams, renameRequest):
      #         debugLog "Running equivalent of: use ", fileuri.toPath(), ";", filestash, ":",
      #           rawLine + 1, ":",
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         let suggestions = getNimsuggest(fileuri).use(fileuri.toPath(), dirtyfile = filestash,
      #           rawLine + 1,
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         )
      #         debugLog "Found suggestions: ",
      #           suggestions[0..(if suggestions.len > 10: 10 else: suggestions.high)],
      #           (if suggestions.len > 10: " and " & $(suggestions.len-10) & " more" else: "")
      #         if suggestions.len == 0:
      #           message.respond newJNull()
      #         else:
      #           var textEdits = newJObject()
      #           for suggestion in suggestions:
      #             let k = suggestion.filepath.pathToUri()
      #             if not textEdits.hasKey(k):
      #               textEdits[k] = newJArray()
      #             textEdits[k].add create(TextEdit,
      #               create(Range,
      #                 create(Position, suggestion.line-1, suggestion.column),
      #                 create(Position, suggestion.line-1, suggestion.column + suggestion.qualifiedPath[^1].len)
      #               ),
      #               renameRequest["newName"].getStr
      #             ).JsonNode
      #           message.respond create(WorkspaceEdit,
      #             some(textEdits),
      #             none(seq[TextDocumentEdit])
      #           ).JsonNode
      #     of "textDocument/definition":
      #       message.textDocumentRequest(TextDocumentPositionParams, definitionRequest):
      #         debugLog "Running equivalent of: def ", fileuri.toPath(), ";", filestash, ":",
      #           rawLine + 1, ":",
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         let declarations = getNimsuggest(fileuri).def(fileuri.toPath(), dirtyfile = filestash,
      #           rawLine + 1,
      #           openFiles[fileuri].fingerTable[rawLine].utf16to8(rawChar)
      #         )
      #         debugLog "Found suggestions: ",
      #           declarations[0..(if declarations.len > 10: 10 else: declarations.high)],
      #           (if declarations.len > 10: " and " & $(declarations.len-10) & " more" else: "")
      #         if declarations.len == 0:
      #           message.respond newJNull()
      #         else:
      #           var response = newJarray()
      #           for declaration in declarations:
      #             debugLog "declaration ", declaration.filepath.replace("\\","/")
      #             response.add(create(Location,
      #               pathToUri(declaration.filepath),
      #               create(Range,
      #                 create(Position, declaration.line-1, declaration.column),
      #                 create(Position, declaration.line-1, declaration.column + declaration.qualifiedPath[^1].len)
      #               )
      #             ).JsonNode)
      #           message.respond response

      #     of "textDocument/signatureHelp":
      #       if message["params"].isSome:
      #         let signRequest = message["params"].unsafeGet
      #         whenValid(signRequest, TextDocumentPositionParams):
      #           let
      #             fileuri = signRequest["textDocument"]["uri"].getStr
      #             filestash = storage / (hash(fileuri).toHex & ".nim" )
      #           debugLog "Got signature request for URI: ", fileuri, " copied to " & filestash
      #           let
      #             rawLine = signRequest["position"]["line"].getInt
      #             rawChar = signRequest["position"]["character"].getInt
      #             suggestions = getNimsuggest(fileuri).con(fileuri.toPath(), dirtyfile = filestash, rawLine + 1, rawChar)

      #     else:
      #       debugLog "Unknown request"
      #       continue

      # whenValid(message, NotificationMessage):
      #   debugLog "Got valid Notification message of type " & message["method"].getStr
      #   if not initialized and message["method"].getStr != "exit":
      #     continue
      #   case message["method"].getStr:
      #     of "exit":
      #       debugLog "Exiting"
      #       if gotShutdown:
      #         quit 0
      #       else:
      #         quit 1
      #     of "initialized":
      #       debugLog "Properly initialized"
      #     of "textDocument/didOpen":
      #       message.textDocumentNotification(DidOpenTextDocumentParams, textDoc):
      #         let
      #           file = open(filestash, fmWrite)
      #           projectFile = getProjectFile(fileuri.toPath())
      #         debugLog "New document opened for URI: ", fileuri, " saving to " & filestash
      #         openFiles[fileuri] = (
      #           #nimsuggest: initNimsuggest(fileuri.toPath()),
      #           projectFile: projectFile,
      #           fingerTable: @[]
      #         )
      #         if not projectFiles.hasKey(projectFile):
      #           debugLog "Initialising project with ", projectFile, ":", nimpath
      #           projectFiles[projectFile] = (nimsuggest: initNimsuggest(projectFile, nimpath), openFiles: 1)
      #         else:
      #           projectFiles[projectFile].openFiles += 1
      #         for line in textDoc["textDocument"]["text"].getStr.splitLines:
      #           openFiles[fileuri].fingerTable.add line.createUTFMapping()
      #           file.writeLine line
      #         file.close()
      #     of "textDocument/didChange":
      #       message.textDocumentNotification(DidChangeTextDocumentParams, textDoc):
      #         let file = open(filestash, fmWrite)
      #         debugLog "Got document change for URI: ", fileuri, " saving to " & filestash
      #         openFiles[fileuri].fingerTable = @[]
      #         for line in textDoc["contentChanges"][0]["text"].getStr.splitLines:
      #           openFiles[fileuri].fingerTable.add line.createUTFMapping()
      #           file.writeLine line
      #         file.close()
      #     of "textDocument/didClose":
      #       message.textDocumentNotification(DidCloseTextDocumentParams, textDoc):
      #         let projectFile = getProjectFile(fileuri.toPath())
      #         debugLog "Got document close for URI: ", fileuri, " copied to " & filestash
      #         removeFile(filestash)
      #         projectFiles[projectFile].openFiles -= 1
      #         if projectFiles[projectFile].openFiles == 0:
      #           debugLog "Trying to stop nimsuggest"
      #           debugLog "Stopped nimsuggest with code: " & $getNimsuggest(fileuri).stopNimsuggest()
      #         openFiles.del(fileuri)
      #     of "textDocument/didSave":
      #       message.textDocumentNotification(DidSaveTextDocumentParams, textDoc):
      #         if textDoc["text"].isSome:
      #           let file = open(filestash, fmWrite)
      #           debugLog "Got document save for URI: ", fileuri, " saving to ", filestash
      #           openFiles[fileuri].fingerTable = @[]
      #           for line in textDoc["text"].unsafeGet.getStr.splitLines:
      #             openFiles[fileuri].fingerTable.add line.createUTFMapping()
      #             file.writeLine line
      #           file.close()
      #         debugLog "fileuri: ", fileuri, ", project file: ", openFiles[fileuri].projectFile, ", dirtyfile: ", filestash
      #         let diagnostics = getNimsuggest(fileuri).chk(fileuri.toPath(), dirtyfile = filestash)
      #         debugLog "Got diagnostics: ",
      #           diagnostics[0..(if diagnostics.len > 10: 10 else: diagnostics.high)],
      #           (if diagnostics.len > 10: " and " & $(diagnostics.len-10) & " more" else: "")
      #         if diagnostics.len == 0:
      #           notify("textDocument/publishDiagnostics", create(PublishDiagnosticsParams,
      #             fileuri,
      #             @[]).JsonNode
      #           )
      #         else:
      #           var response: seq[Diagnostic]
      #           for diagnostic in diagnostics:
      #             if diagnostic.line == 0:
      #               continue
      #             if diagnostic.filePath != fileuri[7..^1]:
      #               continue
      #             # Try to guess the size of the identifier
      #             let
      #               message = diagnostic.nimDocstring
      #               endcolumn = diagnostic.column + message.rfind('\'') - message.find('\'') - 1
      #             response.add create(Diagnostic,
      #               create(Range,
      #                 create(Position, diagnostic.line-1, diagnostic.column),
      #                 create(Position, diagnostic.line-1, max(diagnostic.column, endcolumn))
      #               ),
      #               some(case diagnostic.forth:
      #                 of "Error": DiagnosticSeverity.Error.int
      #                 of "Hint": DiagnosticSeverity.Hint.int
      #                 of "Warning": DiagnosticSeverity.Warning.int
      #                 else: DiagnosticSeverity.Error.int),
      #               none(int),
      #               some("nimsuggest chk"),
      #               message,
      #               none(seq[DiagnosticRelatedInformation])
      #             )
      #           notify("textDocument/publishDiagnostics", create(PublishDiagnosticsParams,
      #             fileuri,
      #             response).JsonNode
      #           )
      #     else:
      #       debugLog "Got unknown notification message"
      #   continue
    # except IOError:
    #   break
    # except CatchableError as e:
    #   debugLog "Got exception: ", e.msg, "\n", getStackTrace(e)
    #   continue
