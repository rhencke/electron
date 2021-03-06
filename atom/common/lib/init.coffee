process = global.process
fs      = require 'fs'
path    = require 'path'
timers  = require 'timers'
Module  = require 'module'

process.atomBinding = (name) ->
  try
    process.binding "atom_#{process.type}_#{name}"
  catch e
    process.binding "atom_common_#{name}" if /No such module/.test e.message

# Global module search paths.
globalPaths = Module.globalPaths

# Don't lookup modules in user-defined search paths, see http://git.io/vf8sF.
homeDir =
  if process.platform is 'win32'
    process.env.USERPROFILE
  else
    process.env.HOME
if homeDir  # Node only add user-defined search paths when $HOME is defined.
  userModulePath = path.resolve homeDir, '.node_modules'
  globalPaths.splice globalPaths.indexOf(userModulePath), 2

# Add common/api/lib to module search paths.
globalPaths.push path.resolve(__dirname, '..', 'api', 'lib')

# setImmediate and process.nextTick makes use of uv_check and uv_prepare to
# run the callbacks, however since we only run uv loop on requests, the
# callbacks wouldn't be called until something else activated the uv loop,
# which would delay the callbacks for arbitrary long time. So we should
# initiatively activate the uv loop once setImmediate and process.nextTick is
# called.
wrapWithActivateUvLoop = (func) ->
  ->
    process.activateUvLoop()
    func.apply this, arguments
process.nextTick = wrapWithActivateUvLoop process.nextTick

if process.type is 'browser'
  # setTimeout needs to update the polling timeout of the event loop, when
  # called under Chromium's event loop the node's event loop won't get a chance
  # to update the timeout, so we have to force the node's event loop to
  # recalculate the timeout in browser process.
  global.setTimeout = wrapWithActivateUvLoop timers.setTimeout
  global.setInterval = wrapWithActivateUvLoop timers.setInterval
  global.setImmediate = wrapWithActivateUvLoop timers.setImmediate
  global.clearImmediate = wrapWithActivateUvLoop timers.clearImmediate
else
  # There are no setImmediate under renderer process by default, so we need to
  # manually setup them here.
  global.setImmediate = setImmediate
  global.clearImmediate = clearImmediate
