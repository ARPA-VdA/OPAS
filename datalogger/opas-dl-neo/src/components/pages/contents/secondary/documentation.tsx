'use client';

import { ServiceDocsPanel } from '@/components/documentation/service-docs-panel';
import { DocumentationOverview } from '@/components/documentation/documentation-overview';
import { useDocumentation } from '@/context/DocumentationContext';

export function DocumentationContent() {
  const { section } = useDocumentation();

  return (
    <div className="h-full flex flex-col p-4">
      {section === 'service' && <ServiceDocsPanel />}
      {section === 'ui' && (
        <div className="text-sm text-muted-foreground p-4">
          Documentazione e tutorial della parte UI — in arrivo.
        </div>
      )}
      {section === 'overview' && <DocumentationOverview />}
    </div>
  );
}
