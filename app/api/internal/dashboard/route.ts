import { NextResponse } from "next/server";
import { getDashboardStats, getRecentSignals } from "@/lib/queries/dashboard";
export async function GET() { return NextResponse.json({ stats: await getDashboardStats(), recent_signals: await getRecentSignals(8) }); }
