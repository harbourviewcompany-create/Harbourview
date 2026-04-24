import { NextRequest, NextResponse } from "next/server";
import { getSources } from "@/lib/queries/sources";
export async function GET(request:NextRequest) { const s = request.nextUrl.searchParams; return NextResponse.json({ data: await getSources({ q:s.get('q') ?? undefined, status:s.get('status') ?? undefined, jurisdiction:s.get('jurisdiction') ?? undefined, source_tier:s.get('source_tier') ?? undefined }) }); }
