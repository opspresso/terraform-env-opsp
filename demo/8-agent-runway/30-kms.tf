# Agent Runway가 Secrets Manager에 저장하는 테넌트 Variable 전용 키입니다.
# Agent Runway 정책은 alias로, 테넌트 읽기 역할 정책은 key ARN으로 이 키를 선택하며, 둘 다 Secrets Manager를 거친 요청만 허용합니다.
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
