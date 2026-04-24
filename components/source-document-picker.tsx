"use client";

import { useEffect, useMemo, useState } from "react";

type DocumentOption = {
  id: string;
  source_id: string;
  title: string;
  url: string | null;
  publication_date: string | null;
  status: string;
};

type SourceWithDocuments = {
  source_id: string;
  source_name: string;
  documents: DocumentOption[];
};

export function SourceDocumentPicker({
  sources,
  defaultSourceId,
}: {
  sources: SourceWithDocuments[];
  defaultSourceId?: string;
}) {
  const initialSourceId = useMemo(() => {
    if (defaultSourceId && sources.some((source) => source.source_id === defaultSourceId)) {
      return defaultSourceId;
    }
    return sources[0]?.source_id ?? "";
  }, [defaultSourceId, sources]);

  const [sourceId, setSourceId] = useState(initialSourceId);

  const documents = useMemo(
    () => sources.find((source) => source.source_id === sourceId)?.documents ?? [],
    [sourceId, sources]
  );

  const [documentId, setDocumentId] = useState(documents[0]?.id ?? "");

  useEffect(() => {
    setSourceId(initialSourceId);
  }, [initialSourceId]);

  useEffect(() => {
    if (!documents.some((doc) => doc.id === documentId)) {
      setDocumentId(documents[0]?.id ?? "");
    }
  }, [documents, documentId]);

  const selectedDocument = documents.find((doc) => doc.id === documentId) ?? null;

  return (
    <>
      <div>
        <label className="hv-label">Source</label>
        <select name="source_id" value={sourceId} onChange={(e) => setSourceId(e.target.value)} required>
          {sources.map((source) => (
            <option key={source.source_id} value={source.source_id}>
              {source.source_name}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="hv-label">Source document</label>
        <select
          name="source_document_id"
          value={documentId}
          onChange={(e) => setDocumentId(e.target.value)}
          required
          disabled={!documents.length}
        >
          {documents.length ? null : <option value="">No documents available</option>}
          {documents.map((doc) => {
            const dateLabel = doc.publication_date ? ` · ${doc.publication_date}` : "";
            return (
              <option key={doc.id} value={doc.id}>
                {doc.title}{dateLabel}
              </option>
            );
          })}
        </select>
      </div>
      <div className="hv-field-full">
        <label className="hv-label">Selected document</label>
        <div className="hv-note">
          {selectedDocument ? (
            <>
              <div className="hv-card-title">{selectedDocument.title}</div>
              <div className="hv-meta">
                {selectedDocument.publication_date ?? "No publication date"}
                {selectedDocument.url ? ` · ${selectedDocument.url}` : ""}
              </div>
            </>
          ) : (
            <div>No source documents available for the selected source.</div>
          )}
        </div>
      </div>
    </>
  );
}
