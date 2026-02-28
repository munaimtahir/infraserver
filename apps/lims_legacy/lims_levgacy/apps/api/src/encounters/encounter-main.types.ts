import type { EncounterType } from './encounter-prep.types';

export type LabMainSaveRequest = {
  resultSummary?: string | null;
  verifiedBy?: string | null;
  verifiedAt?: string | null;
};

export type RadMainSaveRequest = {
  reportText?: string | null;
  impression?: string | null;
  radiologistName?: string | null;
  reportedAt?: string | null;
};

export type OpdMainSaveRequest = {
  chiefComplaint?: string | null;
  assessment?: string | null;
  plan?: string | null;
  prescriptionText?: string | null;
};

export type BbMainSaveRequest = {
  crossmatchResult?: 'COMPATIBLE' | 'INCOMPATIBLE' | null;
  componentIssued?: string | null;
  unitsIssued?: number | null;
  issuedAt?: string | null;
  issueNotes?: string | null;
};

export type IpdMainSaveRequest = {
  dailyNote?: string | null;
  orders?: string | null;
};

export type EncounterMainSaveRequest =
  | LabMainSaveRequest
  | RadMainSaveRequest
  | OpdMainSaveRequest
  | BbMainSaveRequest
  | IpdMainSaveRequest;

export type EncounterMainResponse = {
  encounterId: string;
  type: EncounterType;
  updatedAt: string | null;
  labMain: LabMainSaveRequest | null;
  radMain: RadMainSaveRequest | null;
  opdMain: OpdMainSaveRequest | null;
  bbMain: BbMainSaveRequest | null;
  ipdMain: IpdMainSaveRequest | null;
};
