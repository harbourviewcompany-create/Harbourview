import { NextResponse } from "next/server";
import { getSignalDetail } from "@/lib/queries/signals";
export async function GET(_:Request, { params }:{ params:Promise<{id:string}> }) { const { id } = await params; return NextResponse.json({ data: await getSignalDetail(id) }); }
