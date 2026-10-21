import { Puzzle } from "lucide-react";
import { useState } from "react";

import { usePageSearch } from "~/components/layout/page-chrome";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { EmptyState } from "~/components/ui/empty-state";
import { TabPanel, Tabs } from "~/components/ui/tabs";
import { useStore } from "~/lib/store";

import { FeaturedCard, PluginCard, PluginSection, SoonNote } from "./plugin-cards";
import { PluginDialog } from "./plugin-dialog";
import { pluginLayout, type PluginView, viewCounts } from "./plugins-layout";
import { featuredPlugins, pluginCategories, plugins } from "./plugins-mock";
import type { PluginsStore } from "./plugins-store";

const views: readonly PluginView[] = ["All", ...pluginCategories];
const tabsId = "plugin-views";

export function PluginsPage({ store }: { store: PluginsStore }) {
  const { notify } = useStore(store);
  const [view, setView] = useState<PluginView>("All");
  const [query, setQuery] = usePageSearch("Search plugins");
  // The plugin outlives the open flag so the dialog keeps its content while it closes.
  const [details, setDetails] = useState({ id: plugins[0]?.id ?? "", open: false });
  // Mock: the catalogue is the Studio design's; nothing can be installed yet.
  const layout = pluginLayout(plugins, featuredPlugins, view, query);
  const counts = viewCounts(plugins);
  const shown = plugins.find((plugin) => plugin.id === details.id);
  const open = (id: string) => setDetails({ id, open: true });

  const card = (plugin: (typeof plugins)[number]) => ({
    plugin,
    notified: notify.has(plugin.id),
    onNotify: () => store.toggleNotify(plugin.id),
    onOpen: () => open(plugin.id),
  });

  return (
    <>
      <PageHeader title="Plugins" />
      <Tabs
        id={tabsId}
        label="Plugin categories"
        tabs={views.map((id) => ({ id, label: id, count: counts[id] }))}
        value={view}
        onChange={setView}
      />
      <TabPanel tabs={tabsId} value={view} className="@container pt-1.5">
        {layout.total === 0 ? (
          <EmptyState
            icon={<Puzzle aria-hidden />}
            title="No plugins found"
            action={
              query ? (
                <Button size="sm" onClick={() => setQuery("")}>
                  Clear search
                </Button>
              ) : undefined
            }
          />
        ) : (
          <div className="flex flex-col gap-10">
            {layout.featured.length ? (
              <PluginSection title="Featured" aside={<SoonNote />}>
                <div className="grid grid-cols-1 gap-5 @min-[640px]:grid-cols-2">
                  {layout.featured.map((plugin) => (
                    <FeaturedCard key={plugin.id} {...card(plugin)} />
                  ))}
                </div>
              </PluginSection>
            ) : null}
            {layout.groups.map((group, index) => (
              <PluginSection
                key={group.category}
                title={group.category}
                aside={!layout.featured.length && index === 0 ? <SoonNote /> : null}
              >
                <div className="grid grid-cols-1 gap-5 @min-[600px]:grid-cols-3">
                  {group.items.map((plugin, position) => (
                    <PluginCard
                      key={plugin.id}
                      shape={group.shapes[position] ?? "normal"}
                      {...card(plugin)}
                    />
                  ))}
                </div>
              </PluginSection>
            ))}
          </div>
        )}
      </TabPanel>
      {shown ? (
        <PluginDialog
          plugin={shown}
          open={details.open}
          notified={notify.has(shown.id)}
          onNotify={() => store.toggleNotify(shown.id)}
          onOpenChange={(next) => setDetails((current) => ({ ...current, open: next }))}
        />
      ) : null}
    </>
  );
}
