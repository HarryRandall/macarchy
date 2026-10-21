import type { ReactNode } from "react";

/** A heading introducing a run of cards or a grid, with optional trailing meta. */
function SectionHeading({
  title,
  trailing,
  id,
}: {
  title: string;
  trailing?: ReactNode;
  id?: string;
}) {
  return (
    <div className="flex items-baseline justify-between gap-3 pt-1">
      <h2 id={id} className="text-section-title text-fg">
        {title}
      </h2>
      {trailing ? <span className="text-meta text-fg-meta">{trailing}</span> : null}
    </div>
  );
}

export { SectionHeading };
