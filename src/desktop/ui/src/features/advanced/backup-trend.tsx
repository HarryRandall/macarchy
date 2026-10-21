import { useState } from "react";

/** Backups per calendar day, oldest first, as in the native overview. */
export function BackupTrend({ snapshots }: { snapshots: { created: number }[] }) {
  const [now] = useState(() => Date.now());
  const days = Array.from({ length: 14 }, (_, index) => {
    const day = new Date(now);
    day.setHours(0, 0, 0, 0);
    day.setDate(day.getDate() + index - 13);
    const end = new Date(day);
    end.setDate(end.getDate() + 1);
    return snapshots.filter((snapshot) => snapshot.created >= +day && snapshot.created < +end)
      .length;
  });
  const maximum = Math.max(1, ...days);
  return (
    <svg
      viewBox="0 0 130 22"
      className="h-[22px] w-full text-accent-stroke"
      role="img"
      aria-label="Backups over the last fortnight"
    >
      <polyline
        points={days
          .map((count, index) => `${index * 10},${21 - (count / maximum) * 20}`)
          .join(" ")}
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
      />
    </svg>
  );
}
