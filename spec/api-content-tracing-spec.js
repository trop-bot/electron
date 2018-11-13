const { remote } = require('electron')
const chai = require('chai')
const dirtyChai = require('dirty-chai')
const fs = require('fs')
const path = require('path')

const { expect } = chai
const { app, contentTracing } = remote

chai.use(dirtyChai)

const timeout = async (milliseconds) => {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds)
  })
}

const getPathInATempFolder = (filename) => {
  return path.join(app.getPath('temp'), filename)
}

describe('contentTracing', () => {
  const startRecording = async (options) => {
    return new Promise((resolve) => {
      contentTracing.startRecording(options, () => {
        resolve()
      })
    })
  }

  const stopRecording = async (filePath) => {
    return new Promise((resolve) => {
      contentTracing.stopRecording(filePath, (resultFilePath) => {
        resolve(resultFilePath)
      })
    })
  }

  const record = async (options, outputFilePath) => {
    await app.whenReady()
    const recordTimeInMilliseconds = 1e3

    await startRecording(options)
    await timeout(recordTimeInMilliseconds)
    const resultFilePath = await stopRecording(outputFilePath)

    return resultFilePath
  }

  describe('startRecording', function () {
    this.timeout(5e3)

    const outputFilePath = getPathInATempFolder('trace.json')
    const getFileSizeInKiloBytes = (filePath) => {
      const stats = fs.statSync(filePath)
      const fileSizeInBytes = stats.size
      const fileSizeInKiloBytes = fileSizeInBytes / 1000
      return fileSizeInKiloBytes
    }

    beforeEach(() => {
      fs.unlinkSync(outputFilePath)
    })

    it('accepts an empty config', async () => {
      const config = {}
      await record(config, outputFilePath)

      expect(fs.existsSync(outputFilePath)).to.be.true()

      const fileSizeInKiloBytes = getFileSizeInKiloBytes(outputFilePath)
      expect(fileSizeInKiloBytes).to.be.above(0,
        `the trace output file is empty, check "${outputFilePath}"`)
    })

    it('accepts a trace config', async () => {
      // XXX(alexeykuzmin): All categories are deliberately excluded,
      // so only metadata gets into the output file.
      const config = {
        excluded_categories: ['*']
      }
      await record(config, outputFilePath)

      expect(fs.existsSync(outputFilePath)).to.be.true()

      // If the `excluded_categories` param above is not respected
      // the file size will be above 50KB.
      const fileSizeInKiloBytes = getFileSizeInKiloBytes(outputFilePath)
      expect(fileSizeInKiloBytes).to.be.above(0,
        `the trace output file is empty, check "${outputFilePath}"`)
      expect(fileSizeInKiloBytes).to.be.below(5,
        `the trace output file is suspiciously large (${fileSizeInKiloBytes}KB),
        check "${outputFilePath}"`)
    })

    it('accepts "categoryFilter" and "traceOptions" as a config', async () => {
      // XXX(alexeykuzmin): All categories are deliberately excluded,
      // so only metadata gets into the output file.
      const config = {
        categoryFilter: '__ThisIsANonexistentCategory__',
        traceOptions: ''
      }
      await record(config, outputFilePath)

      expect(fs.existsSync(outputFilePath)).to.be.true()

      // If the `categoryFilter` param above is not respected
      // the file size will be above 50KB.
      const fileSizeInKiloBytes = getFileSizeInKiloBytes(outputFilePath)
      expect(fileSizeInKiloBytes).to.be.above(0,
        `the trace output file is empty, check "${outputFilePath}"`)
      expect(fileSizeInKiloBytes).to.be.below(5,
        `the trace output file is suspiciously large (${fileSizeInKiloBytes}KB),
        check "${outputFilePath}"`)
    })
  })

  describe('stopRecording', function () {
    this.timeout(5e3)

    it('calls its callback with a result file path', async () => {
      const outputFilePath = getPathInATempFolder('trace.json')
      const resultFilePath = await record({}, outputFilePath)
      expect(resultFilePath).to.be.a('string').and.be.equal(outputFilePath)
    })
  })
})
