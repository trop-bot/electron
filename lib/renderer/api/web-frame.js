'use strict'

const { EventEmitter } = require('events')
const { webFrame, WebFrame } = process.atomBinding('web_frame')
const { deprecate } = require('electron')

// WebFrame is an EventEmitter.
Object.setPrototypeOf(WebFrame.prototype, EventEmitter.prototype)
EventEmitter.call(webFrame)

// Lots of webview would subscribe to webFrame's events.
webFrame.setMaxListeners(0)
webFrame.setIsolatedWorldSecurityOrigin = (worldId, securityOrigin) => {
  deprecate.warn('webFrame.setIsolatedWorldSecurityOrigin', 'webFrame.setIsolatedWorldInfo')
  webFrame._setIsolatedWorldSecurityOrigin(worldId, securityOrigin)
}

webFrame.setIsolatedWorldContentSecurityPolicy = (worldId, csp) => {
  deprecate.warn('webFrame.setIsolatedWorldContentSecurityPolicy', 'webFrame.setIsolatedWorldInfo')
  webFrame._setIsolatedWorldContentSecurityPolicy(worldId, csp)
}

webFrame.setIsolatedWorldHumanReadableName = (worldId, name) => {
  deprecate.warn('webFrame.setIsolatedWorldHumanReadableName', 'webFrame.setIsolatedWorldInfo')
  webFrame._setIsolatedWorldHumanReadableName(worldId, name)
}

module.exports = webFrame
