import { IsBoolean, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateTestDto {
  @IsString()
  @MinLength(1)
  code: string;

  @IsString()
  @MinLength(1)
  name: string;

  @IsString()
  @MinLength(1)
  department: string;

  @IsBoolean()
  @IsOptional()
  active?: boolean;
}
