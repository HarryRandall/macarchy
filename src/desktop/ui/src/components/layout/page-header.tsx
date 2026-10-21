import type { ReactNode } from "react";

/** A large title, an optional subtitle and trailing actions that wrap below when narrow. */
function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-x-4 gap-y-3 pb-2">
      <div className="flex min-w-0 flex-col gap-1.5">
        <h1 className="text-page-title text-fg">{title}</h1>
        {subtitle ? <p className="text-row-title text-fg-secondary">{subtitle}</p> : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </header>
  );
}

export { PageHeader };
