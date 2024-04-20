export default class Vector {
  x: number
  y: number
  z: number

  constructor(x: number, y: number, z: number) {
    this.x = x
    this.y = y
    this.z = z
  }

  minus(vec: Vector) {
    return new Vector(this.x - vec.x, this.y - vec.y, this.z - vec.z)
  }

  add(vec: Vector) {
    return new Vector(this.x + vec.x, this.y + vec.y, this.z + vec.z)
  }

  crossProduct(vec: Vector) {
    return new Vector(
      this.y * vec.z - this.z * vec.y,
      this.z * vec.x - this.x * vec.z,
      this.x * vec.y - this.y * vec.x
    )
  }

  length() {
    return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z)
  }

  euclideanDistanceTo(vec: Vector) {
    return this.minus(vec).length()
  }

  multiplyScalar(scalar: number) {
    return new Vector(this.x * scalar, this.y * scalar, this.z * scalar)
  }

  normalized() {
    return this.multiplyScalar(1.0 / this.length())
  }
}
