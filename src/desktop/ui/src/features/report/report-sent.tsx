import { Check, CircleCheck } from "lucide-react";

import { Button } from "~/components/ui/button";
import { Card } from "~/components/ui/card";
import { Chip } from "~/components/ui/chip";
import { TruncatedText } from "~/components/ui/truncated-text";

// Opening the issue removes the button that had focus, so the result takes it.
// Stable, so later renders do not pull focus back from the buttons below.
const focusOnMount = (node: HTMLElement | null) => node?.focus();

/** Shown once the browser has the issue, which the person still has to submit there. */
export function ReportSent({
  title,
  included,
  notice,
  onBack,
  onAnother,
}: {
  title: string;
  /** What the issue carries or what to add to it, such as "2 screenshots to attach". */
  included: readonly string[];
  notice: string | null;
  onBack(): void;
  onAnother(): void;
}) {
  return (
    <Card className="mx-auto mt-6 w-full max-w-[460px] overflow-hidden">
      <div className="flex flex-col items-center gap-1 px-8 pt-8 pb-6 text-center">
        <span className="mb-2.5 grid size-11 place-items-center rounded-full bg-success-soft text-success">
          <CircleCheck aria-hidden className="size-5" />
        </span>
        <h2
          ref={focusOnMount}
          // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- focus target only, kept out of the tab order.
          tabIndex={-1}
          className="text-title text-fg outline-none"
        >
          Opened in your browser
        </h2>
        <p className="text-detail text-fg-secondary">
          Check the issue there and submit it. Nothing is public until you do.
        </p>
        {notice ? (
          <p role="status" className="mt-1.5 text-detail text-fg">
            {notice}
          </p>
        ) : null}
      </div>
      <div className="mx-6 mb-6 rounded-tile border border-hairline bg-side px-3.5 py-3">
        <TruncatedText text={title} className="text-body font-medium text-fg" />
        <ul className="mt-2 flex flex-wrap gap-1.5">
          {included.map((item) => (
            <li key={item}>
              <Chip icon={<Check aria-hidden />}>{item}</Chip>
            </li>
          ))}
        </ul>
      </div>
      <div className="flex items-center justify-between gap-2 border-t border-hairline bg-side px-6 py-3">
        <Button variant="ghost" onClick={onBack}>
          Back to report
        </Button>
        <Button onClick={onAnother}>Write another report</Button>
      </div>
    </Card>
  );
}
