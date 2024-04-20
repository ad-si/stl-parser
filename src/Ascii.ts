export default class Ascii {
  whitespaces = [" ", "\r", "\n", "\t", "\v", "\f"]
  content: string | null
  index: number

  constructor(fileContent: string) {
    this.content = fileContent
    this.index = 0
  }

  skipWhitespaces() {
    let skip = true
    return (() => {
      const result = []
      while (skip) {
        if (this.currentCharIsWhitespace() && !this.reachedEnd()) {
          result.push(this.index++)
        } else {
          result.push((skip = false))
        }
      }
      return result
    })()
  }

  nextText() {
    this.skipWhitespaces.call(this)
    return this.readUntilWhitespace()
  }

  currentChar() {
    return this.content?.[this.index]
  }

  currentCharIsWhitespace() {
    for (const space of Array.from(this.whitespaces)) {
      if (this.currentChar() === space) {
        return true
      }
    }
    return false
  }

  readUntilWhitespace() {
    let readContent = ""
    while (!this.currentCharIsWhitespace() && !this.reachedEnd()) {
      readContent = readContent + this.currentChar()
      this.index++
    }
    return readContent
  }

  reachedEnd() {
    return this.index === this.content?.length
  }
}
