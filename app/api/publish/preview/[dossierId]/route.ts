import { NextRequest, NextResponse } from "next/server";
import { buildPublishPreview } from "@/lib/publish/validate";
export async function GET(request:NextRequest, { params }:{ params:Promise<{dossierId:string}> }) { const { dossierId } = await params; const effectiveAt = request.nextUrl.searchParams.get('effective_at') ?? undefined; return NextResponse.json(await buildPublishPreview(dossierId, effectiveAt)); }
