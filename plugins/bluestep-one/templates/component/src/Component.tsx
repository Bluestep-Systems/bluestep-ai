/**
 * The component module `component.json` names under `modules.component`.
 *
 * The host loads this file's default export: a factory it calls once per placement with the
 * `ComponentHost`, which returns the React component it renders. Hooks belong in the returned
 * component, never in the factory body. Reads and writes go through `host`.
 *
 * This is a starting point. Replace the card with the component's own screen, and declare its
 * props in `component.json` (and in the factory's type parameter) when it takes any.
 */

import type { FederatedComponentFactory } from "#component-host";
import { B6pCard, B6pCardDescription, B6pCardHeader, B6pCardTitle } from "@bluestep/ui";

const TITLE = "{{displayName}}";

const factory: FederatedComponentFactory<Record<string, never>> = (host) => {
  return function Component() {
    return (
      <B6pCard>
        <B6pCardHeader>
          <B6pCardTitle>{TITLE}</B6pCardTitle>
          <B6pCardDescription>This component has no content yet.</B6pCardDescription>
        </B6pCardHeader>
      </B6pCard>
    );
  };
};

export default factory;
