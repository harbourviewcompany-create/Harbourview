import { NextRequest, NextResponse } from "next/server";
import { getSignals } from "@/lib/queries/signals";
export async function GET(request:NextRequest) { const s = request.nextUrl.searchParams; return NextResponse.json({ data: await getSignals({ q:s.get('q') ?? undefined, status:s.get('status') ?? undefined, jurisdiction:s.get('jurisdiction') ?? undefined, data_class:s.get('data_class') ?? undefined, confidence:s.get('confidence') ?? undefined }) }); }
