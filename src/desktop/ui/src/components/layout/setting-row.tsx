import type { ReactNode } from "react";

import { Row } from "~/components/ui/card";

/** An earlier name for `Row`: an optional leading icon, a title with detail, a trailing control. */
function SettingRow({
  title,
  detail,
  help,
  controlId,
  leading,
  children,
}: {
  title: ReactNode;
  /** Values or essential status, always visible. */
  detail?: ReactNode;
  /** Secondary explanation, shown on hover or focus of the help glyph. */
  help?: string;
  /** When the control is a native input, ties the title to it as its label. */
  controlId?: string;
  leading?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <Row
      // The desktop web tests find rows by this slot.
      data-slot="setting-row"
      title={title}
      description={detail}
      help={help}
      controlId={controlId}
      leading={leading}
      control={children}
    />
  );
}

export { SettingRow };
