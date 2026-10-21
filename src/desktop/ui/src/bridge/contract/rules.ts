export interface CustomWindowRule {
  id: string;
  app: string;
  title: string;
}

export interface RulesState {
  floatingApps: string[];
  customRules: CustomWindowRule[];
  externalRules: { app: string; title: string }[];
  icons: Record<string, string>;
}

export interface RulesMethods {
  "rules.getState": { params: Record<string, never>; result: RulesState };
  /** Native application picker. Cancelling changes nothing. */
  "rules.addApplication": { params: Record<string, never>; result: null };
  "rules.removeFloating": { params: { app: string }; result: null };
  "rules.saveCustom": { params: { rule: CustomWindowRule }; result: null };
  "rules.removeCustom": { params: { id: string }; result: null };
}

export type RulesEvent =
  | { type: "rules.changed"; state: RulesState }
  | { type: "rules.unavailable"; state: { message: string } };
