import { NextRequest, NextResponse } from "next/server";
import { getAuditEvents } from "@/lib/queries/audit";
export async function GET(request:NextRequest) { const limit = Number(request.nextUrl.searchParams.get('limit') ?? 50); return NextResponse.json({ data: await getAuditEvents(limit) }); }
