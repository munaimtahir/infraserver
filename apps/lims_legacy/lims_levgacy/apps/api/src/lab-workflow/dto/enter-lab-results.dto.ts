import {
  ArrayMinSize,
  IsArray,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class EnterLabResultValueDto {
  @IsUUID()
  parameterId: string;

  @IsString()
  value: string;
}

export class EnterLabResultsDto {
  @IsUUID()
  orderItemId: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => EnterLabResultValueDto)
  results: EnterLabResultValueDto[];
}
