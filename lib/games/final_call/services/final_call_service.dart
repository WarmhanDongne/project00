import 'final_call_command_service.dart';
import 'final_call_query_service.dart';

/// Final Call의 읽기 구독과 서버 명령을 분리해 제공하는 진입 서비스입니다.
class FinalCallService {
  FinalCallService({
    FinalCallCommandService? command,
    FinalCallQueryService? query,
  }) : command = command ?? FinalCallCommandService(),
       query = query ?? FinalCallQueryService();

  final FinalCallCommandService command;
  final FinalCallQueryService query;
}
