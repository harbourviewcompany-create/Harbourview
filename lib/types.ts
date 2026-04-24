export type PlatformRole = "admin" | "analyst";
export type ReviewStatus = "draft" | "in_review" | "approved" | "rejected";
export type DataClass = "observed" | "derived" | "inferred" | "unverified";
export type ConfidenceLevel = "low" | "medium" | "high" | "confirmed";
export type SourceTier = "official_primary" | "official_secondary" | "company_primary" | "trusted_secondary" | "media_secondary" | "community_low_trust";

export type DashboardStats = { approvedSignals:number; pendingReview:number; publishedDossiers:number; activeSources:number; recentApprovedSignals:number; workspaces:number; };

export type ReviewQueueRow = {
  id:string;
  signal_id:string;
  status:"pending"|"approved"|"rejected"|"returned";
  assigned_to_profile_id:string|null;
  submitted_by_profile_id:string;
  reviewer_notes:string|null;
  rejection_reason:string|null;
  return_reason:string|null;
  resolved_at:string|null;
  created_at:string;
  updated_at:string;
  signal_title:string|null;
  signal_summary:string|null;
  data_class:DataClass|null;
  confidence_level:ConfidenceLevel|null;
  jurisdiction:string|null;
  signal_type:string|null;
  evidence_count:number;
  human_evidence_count:number;
};
