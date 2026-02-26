import { IsUUID } from 'class-validator';

export class AddTestToEncounterDto {
  @IsUUID()
  testId: string;
}
