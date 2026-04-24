import { getScopedSupabase, toArray } from "@/lib/queries/_shared";

export async function getSourceDocumentOptions() {
  const { supabase } = await getScopedSupabase();
  const { data, error } = await supabase
    .from("sources")
    .select(`
      id,
      name,
      status,
      source_documents(
        id,
        source_id,
        title,
        url,
        publication_date,
        status,
        created_at
      )
    `)
    .eq("status", "active")
    .order("name", { ascending: true });

  if (error) throw new Error(`getSourceDocumentOptions: ${error.message}`);

  return toArray(data)
    .map((source: any) => ({
      source_id: source.id,
      source_name: source.name,
      documents: toArray(source.source_documents)
        .filter((doc: any) => doc.status !== "failed")
        .sort((a: any, b: any) => {
          const aDate = a.publication_date ?? a.created_at ?? "";
          const bDate = b.publication_date ?? b.created_at ?? "";
          return String(bDate).localeCompare(String(aDate));
        })
        .map((doc: any) => ({
          id: doc.id,
          source_id: doc.source_id,
          title: doc.title || doc.url || "Untitled source document",
          url: doc.url,
          publication_date: doc.publication_date,
          status: doc.status,
        })),
    }))
    .filter((source: any) => source.documents.length > 0);
}
