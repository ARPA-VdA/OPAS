import React, { createContext, useContext } from 'react';

interface NavigationContextType {
  activePage: string;
  navigateTo: (titleKey: string, payload?: unknown) => void;
  // One-shot payload carried along by the navigateTo() call that landed on
  // the current page (e.g. "select this specific instrument once you get
  // there") - the destination page should read it once on mount/change and
  // call clearPayload(), so it doesn't get re-applied on a later, unrelated
  // navigation back to the same page.
  payload: unknown;
  clearPayload: () => void;
}

const NavigationContext = createContext<NavigationContextType | undefined>(undefined);

export function NavigationProvider({
  children,
  activePage,
  onNavigate,
  payload,
  onClearPayload,
}: {
  children: React.ReactNode;
  activePage: string;
  onNavigate: (titleKey: string, payload?: unknown) => void;
  payload: unknown;
  onClearPayload: () => void;
}) {
  return (
    <NavigationContext.Provider value={{ activePage, navigateTo: onNavigate, payload, clearPayload: onClearPayload }}>
      {children}
    </NavigationContext.Provider>
  );
}

export function useNavigation(): NavigationContextType | undefined {
  return useContext(NavigationContext);
}
