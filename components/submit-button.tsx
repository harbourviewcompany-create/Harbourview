"use client";
import { useFormStatus } from "react-dom";
export function SubmitButton({ children, className="" }:{ children:React.ReactNode; className?:string; }) { const { pending } = useFormStatus(); return <button type="submit" className={`hv-btn ${className}`.trim()} disabled={pending}>{pending ? "Working..." : children}</button>; }
