import { redirect } from "next/navigation";
import { createServerClient } from "@/lib/supabase/server";

export default async function LoginPage({ searchParams }:{ searchParams:Promise<{ error?: string }> }) {
  const params = await searchParams;
  const supabase = await createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect("/app");
  return <main style={{ minHeight:"100vh", display:"flex", alignItems:"center", justifyContent:"center", background:"#0B1A2F" }}><div style={{ background:"#fff", borderRadius:12, padding:"2.5rem 2rem", width:"100%", maxWidth:380 }}><h1 style={{ fontSize:22, fontWeight:600, color:"#0B1A2F", marginBottom:4 }}>Harbourview</h1><p style={{ fontSize:13, color:"#666", marginBottom:28 }}>Intelligence platform — sign in to continue</p>{params.error ? <p style={{ fontSize:13, color:"#b91c1c", background:"#fef2f2", border:"1px solid #fecaca", borderRadius:6, padding:"8px 12px", marginBottom:16 }}>{params.error}</p> : null}<form action="/auth/sign-in" method="POST"><div style={{ marginBottom:16 }}><label htmlFor="email" style={{ fontSize:13, fontWeight:500, display:"block", marginBottom:4 }}>Email</label><input id="email" name="email" type="email" required autoComplete="email" style={{ width:"100%", padding:"8px 12px", fontSize:14, border:"1px solid #d1d5db", borderRadius:6, outline:"none" }} /></div><div style={{ marginBottom:24 }}><label htmlFor="password" style={{ fontSize:13, fontWeight:500, display:"block", marginBottom:4 }}>Password</label><input id="password" name="password" type="password" required autoComplete="current-password" style={{ width:"100%", padding:"8px 12px", fontSize:14, border:"1px solid #d1d5db", borderRadius:6, outline:"none" }} /></div><button type="submit" style={{ width:"100%", padding:"10px", background:"#0B1A2F", color:"#C6A55A", fontSize:14, fontWeight:600, border:"none", borderRadius:6, cursor:"pointer" }}>Sign in</button></form></div></main>;
}
