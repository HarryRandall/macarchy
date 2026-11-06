import { Bell, BellRing, Check } from "lucide-react";

import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";

import {
  Avatar,
  hueInk,
  hueLine,
  hueStyle,
  hueTint,
  PluginArt,
  PluginTile,
  Stage,
} from "./plugin-art";
import { officialAuthor, type Plugin } from "./plugins-mock";

/** A plugin's details: its preview, what it does and what it would add. */
export function PluginDialog({
  plugin,
  open,
  notified,
  onNotify,
  onOpenChange,
}: {
  plugin: Plugin;
  open: boolean;
  notified: boolean;
  onNotify: () => void;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Popup style={hueStyle(plugin)} className="w-[540px]">
        <Dialog.Header>
          <div className="flex min-w-0 items-start gap-3">
            <PluginTile plugin={plugin} size={44} />
            <div className="flex min-w-0 flex-col gap-0.5">
              <div className="flex min-w-0 items-center gap-2">
                <Dialog.Title>{plugin.name}</Dialog.Title>
                {plugin.author === officialAuthor ? <Badge>Official</Badge> : null}
              </div>
              <Dialog.Description className="flex min-w-0 items-center gap-1.5">
                <Avatar author={plugin.author} size={16} />
                <span className="truncate">
                  {plugin.category} plugin by {plugin.author}
                </span>
              </Dialog.Description>
            </div>
          </div>
        </Dialog.Header>
        <Dialog.Body className="gap-5">
          <div className="overflow-hidden rounded-panel border" style={{ borderColor: hueLine }}>
            <Stage plugin={plugin} height={220} scale={1.4}>
              <PluginArt id={plugin.id} />
            </Stage>
          </div>
          <p className="text-body leading-[1.55] text-fg">{plugin.about}</p>
          <div>
            <h3 className="mb-2 text-label text-fg-tertiary uppercase">What it adds</h3>
            <ul className="space-y-1.5">
              {plugin.brings.map((item) => (
                <li key={item} className="flex items-center gap-2 text-body text-fg">
                  <span
                    aria-hidden
                    className="grid size-4 shrink-0 place-items-center rounded-full"
                    style={{ background: hueTint(16), color: hueInk }}
                  >
                    <Check size={10} strokeWidth={2.5} />
                  </span>
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </Dialog.Body>
        <Dialog.Footer leading={<span className="text-small text-fg-tertiary">Coming soon</span>}>
          <Dialog.Close render={<Button variant="ghost" />}>Close</Dialog.Close>
          <Button
            variant={notified ? "secondary" : "primary"}
            aria-pressed={notified}
            onClick={onNotify}
          >
            {notified ? <BellRing aria-hidden size={13} /> : <Bell aria-hidden size={13} />}
            {notified ? "Notifying" : "Notify me"}
          </Button>
        </Dialog.Footer>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
