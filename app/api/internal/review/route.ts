import { NextResponse } from "next/server";
import { getReviewQueue } from "@/lib/queries/review";
export async function GET() { return NextResponse.json({ data: await getReviewQueue() }); }
