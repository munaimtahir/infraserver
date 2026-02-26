import {
  IsDateString,
  IsDefined,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateEncounterPrepPayloadDto {
  @IsDefined()
  @IsDateString()
  sample_collected_at!: string;

  @IsOptional()
  @IsDateString()
  sample_received_at?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateEncounterPrepCommandDto {
  @IsUUID()
  encounter_id!: string;

  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => UpdateEncounterPrepPayloadDto)
  prep!: UpdateEncounterPrepPayloadDto;
}
