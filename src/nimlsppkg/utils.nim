import messageenums
import strutils, uri, os, options, hashes

const storage = getTempDir() / "nimlsp"

discard existsOrCreateDir(storage)

proc getStorage*(): string = storage

when defined(debugLogging):
  let logPath = when defined(localLogFile): getAppDir() / "nimlsp.log" else: storage / "nimlsp.log"
  var logFile = open(logPath, fmWrite)

template debugLog*(args: varargs[string, `$`]) =
  when defined(debugLogging):
    stderr.write(join args)
    stderr.write("\n")
    logFile.write(join args)
    logFile.write("\n\n")
    logFile.flushFile()

template writeLog*(args: varargs[string, `$`]) =
  when defined(debugLogging):
    logFile.write(join args)
    logFile.write("\n\n")
    logFile.flushFile()

template whenValid*(data, kind, body, elseblock) =
  if data.isValid(kind, allowExtra = true):
    var data = kind(data)
    body
  else:
    elseblock

template whenValid*(data, kind, body) =
  whenValid(data, kind, body):
    debugLog("Unable to parse data as " & $kind)

proc toPath*(s: string): string =
  s[7..^1]

template textDocumentRequest*(message, kind, name, body) {.dirty.} =
  if message["params"].isSome:
    let name = message["params"].unsafeGet
    whenValid(name, kind):
      let
        fileuri = name["textDocument"]["uri"].getStr
        filestash = storage / (hash(fileuri).toHex & ".nim" )
      debugLog "Got request for URI: ", fileuri, " copied to " & filestash
      let
        rawLine = name["position"]["line"].getInt
        rawChar = name["position"]["character"].getInt
      body

template textDocumentNotification*(message, kind, name, body) {.dirty.} =
  if message["params"].isSome:
    let name = message["params"].unsafeGet
    whenValid(name, kind):
      if not name["textDocument"].hasKey("languageId") or name["textDocument"]["languageId"].getStr == "nim":
        let
          fileuri = name["textDocument"]["uri"].getStr
          filestash = storage / (hash(fileuri).toHex & ".nim" )
        body

proc stashFile*(path: string): string =
  storage / (hash(path).toHex & ".nim" )

proc pathToUri*(path: string): string =
  # This is a modified copy of encodeUrl in the uri module. This doesn't encode
  # the / character, meaning a full file path can be passed in without breaking
  # it.
  debugLog "pathToUri> ", path

  when defined(windows):
    var path = path.replace("\\", "/")
  result = path
  if result[0] == '/':
    result = "file://" & result
  else:
    result = "file:///" & result
  debugLog "pathToUri< ", result


type Certainty {.pure.} = enum
  None,
  Folder,
  Cfg,
  Nimble

proc getProjectFile*(file: string): string =
  result = file.decodeUrl
  when defined(windows):
    result.removePrefix "/"   # ugly fix to "/C:/foo/bar" paths from "file:///C:/foo/bar"
  let (dir, _, _) = result.splitFile()
  var
    path = dir
    certainty = Certainty.None
  while path.len > 0 and path != "/":
    let
      (dir, fname, ext) = path.splitFile()
      current = fname & ext
    if fileExists(path / current.addFileExt(".nim")) and certainty <= Certainty.Folder:
      result = path / current.addFileExt(".nim")
      certainty = Certainty.Folder
    if fileExists(path / current.addFileExt(".nim")) and
      (fileExists(path / current.addFileExt(".nim.cfg")) or
      fileExists(path / current.addFileExt(".nims"))) and certainty <= Certainty.Cfg:
      result = path / current.addFileExt(".nim")
      certainty = Certainty.Cfg
    if fileExists(path / current.addFileExt(".nimble")) and certainty <= Certainty.Nimble:
      # Read the .nimble file and find the project file
      discard
    path = dir
