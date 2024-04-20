export default function (str: string) {
  if (!isNaN(parseFloat(str))) {
    return Number(str)
  } else {
    throw new Error(`'${str}' isn't a number`)
  }
}
