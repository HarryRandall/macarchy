import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";

import { AppTile } from "./app-tile";

export function AboutDialog({
  open,
  onOpenChange,
  version,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  version: string;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Popup className="w-[300px]">
        <div className="flex flex-col items-center gap-1 px-6 pt-7 pb-5 text-center">
          <AppTile size={56} />
          <Dialog.Title className="mt-3 text-[15px] font-semibold">Macarchy</Dialog.Title>
          <Dialog.Description className="tabular-nums">Version {version}</Dialog.Description>
          <p className="mt-2 text-meta text-fg-tertiary">
            Settings for yabai, SketchyBar, borders and skhd.
          </p>
        </div>
        <Dialog.Footer>
          <Dialog.Close render={<Button variant="primary" />}>Done</Dialog.Close>
        </Dialog.Footer>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
