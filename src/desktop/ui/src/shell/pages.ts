import { rulesPage } from "~/features/rules/page";
import { advancedPage } from "~/features/advanced/page";
import { bordersPage } from "~/features/borders/page";
import { homePage } from "~/features/home/page";
import { healthPage } from "~/features/health/page";
import { reportPage } from "~/features/report/page";
import { themesPage } from "~/features/themes/page";
import { shortcutsPage } from "~/features/shortcuts/page";
import { layoutPage } from "~/features/layout/page";
import { pluginsPage } from "~/features/plugins/page";
import { menuBarPage } from "~/features/menu-bar/page";
import { workshopPage } from "~/features/workshop/page";

import type { RegisteredPage } from "./page";

/**
 * Every pane React draws. A pane not listed here opens the classic window.
 * To migrate a page, add its definition here and its pane to `Pane.migrated`
 * in Swift.
 */
export const pages: RegisteredPage[] = [
  layoutPage,
  rulesPage,
  advancedPage,
  bordersPage,
  homePage,
  healthPage,
  reportPage,
  themesPage,
  shortcutsPage,
  pluginsPage,
  menuBarPage,
  workshopPage,
];
