import { CircleHelp } from "lucide-react";

import { focusRing } from "./focus-ring";
import { Tooltip } from "./tooltip";

/**
 * The question mark beside a title. A real button so Tab and VoiceOver reach
 * it; the help text is its description, so its name stays short.
 */
function HelpTooltip({ text }: { text: string }) {
  return (
    <Tooltip content={text}>
      <button
        type="button"
        aria-label="Help"
        className={`inline-grid size-5 shrink-0 place-items-center rounded-small text-fg-tertiary transition-colors hover:bg-hover hover:text-fg ${focusRing}`}
      >
        <CircleHelp aria-hidden className="size-3.5" strokeWidth={1.75} />
      </button>
    </Tooltip>
  );
}

export { HelpTooltip };
