import filestream from "filestream"
const ReadableFileStream = filestream.read

import stlParser from "../../src/index"

const bufferedContainer = document.getElementById("bufferedLoading")
const streamedContainer = document.getElementById("streamedLoading")
const progressBar = document.querySelector("progress")

const getFinishString = (
  modelName: string,
  fileName: string,
  endTime: number
) => `✔ Parsed and loaded model \"${modelName}\" \
from file \"${fileName}\" \
in ${endTime} ms`

const checkFilesCount = function (files: FileList) {
  if (files.length > 1) {
    const warning = "Multiple files are not yet supported!"
    alert(warning)
    throw new Error(warning)
  }
}

const resetProgressDisplay = function () {
  streamedContainer.querySelector("p").textContent = ""
  return progressBar.setAttribute("value", "0")
}

const loadBuffered = function (changeEvent) {
  const { files } = changeEvent.target
  checkFilesCount(files)

  const startTime = new Date()

  const reader = new FileReader()

  reader.addEventListener("load", function (event) {
    bufferedContainer.querySelector("p").textContent = `✔ Loaded file ${
      files[0].name
    } \
in ${new Date() - startTime} ms`

    const parse = () =>
      stlParser(event.target.result).on(
        "data",
        (data) =>
          (bufferedContainer.querySelector("p").textContent = getFinishString(
            data.name,
            files[0].name,
            new Date() - startTime
          ))
      )

    return setTimeout(parse)
  })

  return reader.readAsArrayBuffer(files[0])
}

const loadStreamed = function (changeEvent) {
  changeEvent.preventDefault()
  changeEvent.stopPropagation()

  resetProgressDisplay()

  const { files } = changeEvent.target
  checkFilesCount(files)

  let faceCounter = 0
  const averageFaceSize = 240 // Byte
  let modelName = ""

  const fileStream = new ReadableFileStream(files[0])
  fileStream.on("error", function (error) {
    throw error
  })

  const streamingStlParser = stlParser({ blocking: false })
  streamingStlParser.on("data", function (data) {
    if (data.number == null) {
      faceCounter = data.faceCount
        ? data.faceCount
        : files[0].size / averageFaceSize
      return (modelName = data.name)
    } else {
      return progressBar.setAttribute(
        "value",
        String(data.number / faceCounter)
      )
    }
  })

  streamingStlParser.on("end", function () {
    progressBar.setAttribute("value", "1")
    return (streamedContainer.querySelector("p").textContent = getFinishString(
      modelName,
      files[0].name,
      new Date() - startTime
    ))
  })

  streamingStlParser.on("warning", console.error)
  streamingStlParser.on("error", console.error)

  var startTime = new Date()
  return fileStream.pipe(streamingStlParser)
}

bufferedContainer
  .querySelector("input")
  .addEventListener("change", loadBuffered)

streamedContainer
  .querySelector("input")
  .addEventListener("change", loadStreamed)
