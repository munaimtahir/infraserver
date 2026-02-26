import { IsUUID } from 'class-validator';

export class VerifyLabResultsDto {
  @IsUUID()
  orderItemId: string;
}
