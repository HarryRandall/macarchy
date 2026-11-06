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
  /**
   * A sentence saying why yabai's live rules could not be read. When set, only
   * saved rules are shown, `externalRules` is empty and edits cannot apply.
   */
  unavailableReason: string | null;
}

export interface RulesMethods {
  "rules.getState": { params: Record<string, never>; result: RulesState };
  /** Native application picker. Cancelling changes nothing. */
  "rules.addApplication": { params: Record<string, never>; result: null };
  "rules.removeFloating": { params: { app: string }; result: null };
  /**
   * `existing` is true when the editor opened a saved rule. Saving fails if that
   * rule was removed elsewhere, rather than adding it back.
   */
  "rules.saveCustom": { params: { rule: CustomWindowRule; existing: boolean }; result: null };
  "rules.removeCustom": { params: { id: string }; result: null };
}

export type RulesEvent =
  | { type: "rules.changed"; state: RulesState }
  | { type: "rules.unavailable"; state: { message: string } };
