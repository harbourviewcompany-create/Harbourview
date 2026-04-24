import { NextResponse } from "next/server";
import { getSourceDetail } from "@/lib/queries/sources";
export async function GET(_:Request, { params }:{ params:Promise<{id:string}> }) { const { id } = await params; return NextResponse.json({ data: await getSourceDetail(id) }); }
