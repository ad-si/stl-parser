declare module "buffertrim" {
  export function trim(buffer: Buffer): Buffer
  export function trimStart(buffer: Buffer): Buffer
  export function trimEnd(buffer: Buffer): Buffer
}
