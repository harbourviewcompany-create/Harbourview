import { NextResponse } from "next/server";
import { getDossierDetail } from "@/lib/queries/dossiers";
export async function GET(_:Request, { params }:{ params:Promise<{id:string}> }) { const { id } = await params; return NextResponse.json({ data: await getDossierDetail(id) }); }
