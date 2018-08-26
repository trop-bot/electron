'use strict'

const { remote } = require('electron')

module.exports = function (usage) {
  if (!remote) {
    throw new Error(`${usage} requires remote, which is not enabled`)
  }
  return remote
}
