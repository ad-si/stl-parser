import Polygon from "./Polygon"

export default class Binary {
  polygons: Polygon[]
  importErrors: string[]

  constructor() {
    this.polygons = []
    this.importErrors = []
  }

  addPolygon(stlPolygon: Polygon) {
    return this.polygons.push(stlPolygon)
  }

  addError(str: string) {
    return this.importErrors.push(str)
  }
}
