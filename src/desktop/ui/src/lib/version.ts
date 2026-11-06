/**
 * True when dotted version `a` is newer than `b`. Missing parts count as
 * zero, so "1.2" equals "1.2.0"; parts that are not numbers count as zero too.
 */
export function isNewer(a: string, b: string): boolean {
  const left = a.split(".").map((part) => Number(part) || 0);
  const right = b.split(".").map((part) => Number(part) || 0);
  for (let index = 0; index < Math.max(left.length, right.length); index++) {
    const difference = (left[index] ?? 0) - (right[index] ?? 0);
    if (difference !== 0) return difference > 0;
  }
  return false;
}
