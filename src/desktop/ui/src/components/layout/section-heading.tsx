import type { ReactNode } from "react";

import { SectionLabel } from "~/components/ui/card";

/**
 * An earlier name for `SectionLabel`, with optional trailing meta. Its
 * callers space it with their own gap, so it drops the label's margin.
 */
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
    <SectionLabel
      id={id}
      className="mb-0"
      action={trailing ? <span className="text-meta text-fg-tertiary">{trailing}</span> : undefined}
    >
      {title}
    </SectionLabel>
  );
}

export { SectionHeading };
