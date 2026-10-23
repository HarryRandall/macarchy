import { Eye, Plus } from "lucide-react";
import { type ReactNode, useState } from "react";

import type { BarItemKind } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";

import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, makeable, type Zone, zoneLabels } from "./menu-bar-items";

/**
 * What can go in one zone: a new text, spacer or command item, or one of the
 * bar's own items that is hidden. Open while `zone` is set; the last zone
 * stays drawn while the dialog fades out.
 */
export function ItemLibrary({
  zone,
  hidden,
  onMake,
  onShow,
  onClose,
}: {
  zone: Zone | null;
  /** The bar's own items that are hidden, to show again. */
  hidden: BarItem[];
  onMake: (kind: BarItemKind, zone: Zone) => void;
  onShow: (id: string, zone: Zone) => void;
  onClose: () => void;
}) {
  const [last, setLast] = useState<Zone>("left");
  if (zone !== null && zone !== last) setLast(zone);
  const shownZone = zone ?? last;
  const zoneName = zoneLabels[shownZone].toLowerCase();

  return (
    <Dialog.Root open={zone !== null} onOpenChange={(open) => (open ? undefined : onClose())}>
      <Dialog.Popup className="w-[480px]">
        <Dialog.Header>
          <Dialog.Title>Add to the {zoneName} zone</Dialog.Title>
        </Dialog.Header>
        <Dialog.Body className="gap-0 px-2 pt-0 pb-2">
          <Section title="Make an item">
            {makeable.map((entry) => (
              <Entry
                key={entry.kind}
                item={{ id: entry.kind, kind: entry.kind }}
                name={entry.name}
                detail={entry.detail}
                action={
                  <Button
                    size="sm"
                    aria-label={`Add ${entry.name}`}
                    onClick={() => {
                      onMake(entry.kind, shownZone);
                      onClose();
                    }}
                  >
                    <Plus aria-hidden size={12} /> Add
                  </Button>
                }
              />
            ))}
          </Section>
          {hidden.length > 0 ? (
            <Section title="Hidden on your bar">
              {hidden.map((item) => (
                <Entry
                  key={item.id}
                  item={item}
                  name={item.title}
                  detail={`In the ${zoneLabels[item.zone].toLowerCase()} zone`}
                  action={
                    <Button
                      size="sm"
                      aria-label={`Show ${item.title} here`}
                      onClick={() => {
                        onShow(item.id, shownZone);
                        onClose();
                      }}
                    >
                      <Eye aria-hidden size={12} /> Show here
                    </Button>
                  }
                />
              ))}
            </Section>
          ) : null}
        </Dialog.Body>
        <Dialog.Footer>
          <Button variant="primary" onClick={onClose}>
            Done
          </Button>
        </Dialog.Footer>
      </Dialog.Popup>
    </Dialog.Root>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section aria-label={title}>
      <h3 className="px-3 pt-3 pb-1 text-label text-fg-tertiary uppercase">{title}</h3>
      <ul>{children}</ul>
    </section>
  );
}

function Entry({
  item,
  name,
  detail,
  action,
}: {
  item: Pick<BarItem, "id" | "kind">;
  name: string;
  detail: string;
  action: ReactNode;
}) {
  return (
    <li className="flex items-center gap-3 rounded-control px-3 py-2 transition-colors hover:bg-hover">
      <span className="grid size-8 shrink-0 place-items-center rounded-tile border border-hairline bg-card text-fg-secondary">
        <ItemIcon item={item} size={14} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-body font-medium text-fg">{name}</div>
        <div className="truncate text-small text-fg-secondary">{detail}</div>
      </div>
      {action}
    </li>
  );
}
