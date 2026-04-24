import { NextRequest, NextResponse } from "next/server";
import { getDossiers } from "@/lib/queries/dossiers";
export async function GET(request:NextRequest) { const s = request.nextUrl.searchParams; return NextResponse.json({ data: await getDossiers({ q:s.get('q') ?? undefined, status:s.get('status') ?? undefined, jurisdiction:s.get('jurisdiction') ?? undefined }) }); }
