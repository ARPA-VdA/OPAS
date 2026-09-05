'use client';

import { ServiceDocsPanel } from '@/components/documentation/service-docs-panel';
import { UiDocsPanel } from '@/components/documentation/ui-docs-panel';
import { DocumentationOverview } from '@/components/documentation/documentation-overview';
import { useDocumentation } from '@/context/DocumentationContext';

export function DocumentationContent() {
  const { section } = useDocumentation();

  return (
    <div className="h-full flex flex-col p-4">
      {section === 'service' && <ServiceDocsPanel />}
      {section === 'ui' && <UiDocsPanel />}
      {section === 'overview' && <DocumentationOverview />}
    </div>
  );
}
