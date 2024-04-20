import Vector from "./Vector"

export default class Polygon {
  vertices: Vector[]
  normal: Vector

  constructor() {
    this.vertices = []
    this.normal = new Vector(0, 0, 0)
  }

  setNormal(normal: Vector) {
    this.normal = normal
  }

  addVertex(vertex: Vector) {
    return this.vertices.push(vertex)
  }
}
