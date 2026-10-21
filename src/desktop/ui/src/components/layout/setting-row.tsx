import type { ReactNode } from "react";

import { HelpTooltip } from "~/components/ui/help-tooltip";

/** An optional leading icon, a title with detail under it, and a trailing control. */
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
  const Title = controlId ? "label" : "span";
  return (
    <div data-slot="setting-row" className="flex items-center gap-3 px-4 py-3">
      {leading}
      <div className="flex min-w-0 flex-col gap-0.5">
        <div className="flex items-center gap-[3px]">
          <Title htmlFor={controlId} className="text-row-title text-fg">
            {title}
          </Title>
          {help ? <HelpTooltip text={help} /> : null}
        </div>
        {detail ? <p className="text-row-detail text-fg-secondary">{detail}</p> : null}
      </div>
      <div className="ml-auto flex shrink-0 items-center pl-3">{children}</div>
    </div>
  );
}

export { SettingRow };
