# Agent Runway가 Secrets Manager에 저장하는 테넌트 Variable 전용 키입니다.
# Agent Runway와 테넌트 읽기 역할의 IAM 정책이 alias로 이 키를 선택하고, Secrets Manager를 거친 요청만 허용합니다.
resource "aws_kms_key" "variables" {
  description             = "Agent Runway tenant variables"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "runway_variables" {
  name          = "alias/agent-runway"
  target_key_id = aws_kms_key.variables.key_id
}
