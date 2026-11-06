import type { ReactNode } from "react";

import { TopBarActions } from "./page-chrome";

/**
 * The page's title for VoiceOver; the breadcrumb and sidebar already name
 * the page, so nothing is drawn. Actions go to the top bar.
 */
function PageHeader({
  title,
  actions,
}: {
  title: string;
  /** Not shown: Studio drops the line under each title. Kept so callers compile. */
  subtitle?: string;
  /** Not shown, as `subtitle`. */
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <>
      <h1 className="sr-only">{title}</h1>
      {actions ? <TopBarActions>{actions}</TopBarActions> : null}
    </>
  );
}

export { PageHeader };
