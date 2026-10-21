export interface RingGeometry {
  centre: number;
  radius: number;
  circumference: number;
  /** Each arc's length along the ring, after its share of the gaps. */
  arc: number;
  /** Each arc's rotation in degrees, clockwise from the top once the ring is turned -90°. */
  angles: number[];
}

/**
 * The ring split into `count` equal arcs with `gap` pixels between them,
 * clockwise in order. One arc closes the ring with no gap.
 */
export function ringGeometry(
  count: number,
  size: number,
  stroke: number,
  gap: number,
): RingGeometry {
  const centre = size / 2;
  const radius = Math.max(0, (size - stroke) / 2);
  const circumference = 2 * Math.PI * radius;
  const parts = Math.max(1, count);
  const spacing = parts === 1 ? 0 : gap;
  const arc = Math.max(0, circumference / parts - spacing);
  const offset = circumference > 0 ? (spacing / 2 / circumference) * 360 : 0;
  const angles = Array.from({ length: count }, (_, index) => (360 / parts) * index + offset);
  return { centre, radius, circumference, arc, angles };
}

/** Stroke and gap that read at a ring's size: thin at 16px in a bar, bolder at 40px. */
export function ringWeight(size: number) {
  return size <= 24 ? { stroke: 3, gap: 1.75 } : { stroke: 4, gap: 3 };
}
