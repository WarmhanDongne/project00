import 'template_command_service.dart';
import 'template_query_service.dart';

/// Command/Query 서비스를 묶는 파사드입니다. 모든 게임이 이 모양을 따릅니다.
class TemplateService {
  TemplateService({
    TemplateCommandService? command,
    TemplateQueryService? query,
  }) : command = command ?? TemplateCommandService(),
       query = query ?? TemplateQueryService();

  final TemplateCommandService command;
  final TemplateQueryService query;
}
