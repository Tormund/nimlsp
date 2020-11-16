import messageenums
import strutils, uri, os, options, hashes, times

const storage = getTempDir() / "nimlsp"
const auxProjFile = storage / "auxproject.nim.cfg"

discard existsOrCreateDir(storage)

if not fileExists(auxProjFile):
  writeFile(auxProjFile, "")

proc getStorage*(): string = storage

when defined(debugLogging):
  var logPath = when defined(localLogFile): getAppDir() else: storage
  var logFile = open(logPath / "nimlsp_" & $int(epochTime()) & ".log", fmWrite)


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

proc toPath*(s: string): string =
  when defined(windows):
    result = s[8..^1]
  else:
    result = s[7..^1]

proc stashFile*(path: string): string =
  storage / (hash(path.toPath).toHex & ".nim" )


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


# type Certainty {.pure.} = enum
#   None,
#   Folder,
#   Cfg,
#   Nimble

proc isProjectFile(p: string): bool =
  let sp = p.splitFile()
  result = sp.ext in [".nims", ".nim.cfg"]

proc isBuildFile(p: string): bool =
  let sp = p.splitFile()
  result = sp.ext in [".nimble", ".nakefile"]

proc getProjectFile*(path: string): string =
  if path.len == 0: return auxProjFile
  var file = path.decodeUrl

  while result.len == 0 and file.len > 0:
    var (dir, fname, ext) = file.splitFile()
    for f in walkDir(dir):
      if f.path.isProjectFile:
        result = f.path
        break
      elif f.path.isBuildFile:
        debugLog("found proj file ", f.path)
        break
      if result.len != 0:
        break
      file = dir

  if result.len == 0:
    result = auxProjFile

  debugLog("getProjectFile ", path, " r ", result, " isProjectFile ", result.isProjectFile, " isBuildFile ", result.isBuildFile)
  # if result.len > 0 not result.isProjectFile:
  #   debugLog("isBuildFile ", result, " ", )

  # var
  #   path = dir
  #   certainty = Certainty.None
  # while path.len > 0 and path != "/":
  #   let
  #     (dir, fname, ext) = path.splitFile()
  #     current = fname & ext
  #   if fileExists(path / current.addFileExt(".nim")) and certainty <= Certainty.Folder:
  #     result = path / current.addFileExt(".nim")
  #     certainty = Certainty.Folder
  #   if fileExists(path / current.addFileExt(".nim")) and
  #     (fileExists(path / current.addFileExt(".nim.cfg")) or
  #     fileExists(path / current.addFileExt(".nims"))) and certainty <= Certainty.Cfg:
  #     result = path / current.addFileExt(".nim")
  #     certainty = Certainty.Cfg
  #   if fileExists(path / current.addFileExt(".nimble")) and certainty <= Certainty.Nimble:
  #     # Read the .nimble file and find the project file
  #     discard
  #   path = dir

  debugLog("getProjectFile ", file, " projFile ", result)
