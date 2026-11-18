import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatGptPlanException implements Exception {
  const ChatGptPlanException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ChatGptPlan {
  static final instance = ChatGptPlan();
  static const _issuer = 'https://auth.openai.com';
  static const _api = 'https://api.openai.com/v1';
  static const _scope = 'chatgpt.tokens.use.direct';
  static const _timeout = Duration(seconds: 20);
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  final _refreshes = <String, Future<String>>{};

  String _key(String id) => 'chatgpt_plan_$id';

  String _randomToken() {
    final random = Random.secure();
    return _base64(List.generate(32, (_) => random.nextInt(256)));
  }

  String _base64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  Future<Map<String, dynamic>>? _metadata;
  Future<Map<String, dynamic>> _discovery() => _metadata ??= _loadDiscovery();

  Future<Map<String, dynamic>> _loadDiscovery() async {
    try {
      return _read(
        await http
            .get(Uri.parse('$_issuer/.well-known/openid-configuration'))
            .timeout(_timeout),
      );
    } catch (_) {
      _metadata = null;
      rethrow;
    }
  }

  Map<String, dynamic> _read(http.Response response) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // HTTP errors can be HTML, and token payloads must never reach logs.
    }
    final body = decoded is Map<String, dynamic> ? decoded : null;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body == null) {
      final error = body?['error'];
      final detail = body?['detail'];
      throw _requestError(
        error is Map ? error['code'] : error,
        response.statusCode,
        requestId:
            response.headers['x-request-id'] ??
            response.headers['openai-request-id'],
        detail: detail is String ? detail : null,
      );
    }
    return body;
  }

  ChatGptPlanException _requestError(
    Object? code,
    int? status, {
    String? requestId,
    String? detail,
  }) {
    final regionDetail = detail?.toLowerCase() ?? '';
    final message = switch (code) {
      'subscription_sharing_user_not_eligible' =>
        '所选 ChatGPT 账号或工作区当前无法在此应用使用套餐额度。',
      'subscription_sharing_usage_unavailable' ||
      'subscription_sharing_user_unavailable' => '暂时无法检查 ChatGPT 套餐用量，请稍后重试。',
      'subscription_sharing_usage_limit_exceeded' =>
        '已达到 ChatGPT 用量限制，请稍后重试或切换模型配置。',
      'subscription_sharing_route_not_supported' => 'OpenAI 套餐接口不支持此请求路径。',
      'chatpass_v2_scope_not_authorized' ||
      'chatpass_v2_invalid_authorization_context' =>
        'OpenAI 拒绝了此操作的套餐授权，请检查所选账号和应用授权。',
      'unsupported_country_region_territory' => 'OpenAI 拒绝了当前地区的 API 请求。',
      'invalid_grant' ||
      'subscription_sharing_invalid_user' => 'ChatGPT 会话已失效，请在模型配置中重新登录。',
      _ => switch (status) {
        401 => 'ChatGPT 会话无法验证，请在模型配置中重新登录。',
        403
            when regionDetail.contains('region') ||
                regionDetail.contains('country') ||
                regionDetail.contains('territory') =>
          'OpenAI 拒绝了当前地区的 API 请求。',
        403 => 'OpenAI 拒绝了此请求。请检查当前账号、工作区或地区是否支持套餐接入。',
        429 => '已达到 ChatGPT 用量限制，请稍后重试或切换模型配置。',
        _ => 'ChatGPT 未能完成请求，请重试。',
      },
    };
    final safeId = RegExp(r'^[A-Za-z0-9_-]{1,100}$');
    final diagnostics = [
      if (status != null) 'HTTP $status',
      if (code is String && safeId.hasMatch(code)) code,
      if (requestId != null && safeId.hasMatch(requestId)) '请求 ID $requestId',
    ];
    return ChatGptPlanException(
      diagnostics.isEmpty ? message : '$message（${diagnostics.join(' · ')}）',
    );
  }

  Future<Map<String, dynamic>?> _session(String id) async {
    final encoded = await _storage.read(key: _key(id));
    return encoded == null ? null : jsonDecode(encoded) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _exchange(Map<String, String> body) async {
    return _read(
      await http
          .post(
            Uri.parse('$_issuer/api/accounts/oauth/token'),
            body: {...body, 'resource': _api},
          )
          .timeout(_timeout),
    );
  }

  Future<String> signIn(String id, {Future<void>? cancelled}) async {
    final saved = await _session(id);
    final prefs = await SharedPreferences.getInstance();
    const hostKey = 'chatgpt_plan_host';
    var host = prefs.getString(hostKey);
    if (host == null) {
      final random = Random.secure();
      final bytes = List.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      host =
          'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      await prefs.setString(hostKey, host);
    }

    final state = _randomToken();
    final nonce = _randomToken();
    final verifier = _randomToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}/auth/callback';
    final clientId = saved?['client_id'] as String?;
    final callback = Completer<Map<String, String>>();
    var callbackReceived = false;
    final listener = server.listen((request) async {
      final params = request.uri.queryParameters;
      if (request.method != 'GET' ||
          request.uri.path != '/auth/callback' ||
          params['state'] != state ||
          callbackReceived) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      // Claim the callback before responding to the browser.
      callbackReceived = true;
      request.response.headers.contentType = ContentType(
        'text',
        'plain',
        charset: 'utf-8',
      );
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.write('请返回 AI Dictionary 查看登录结果。');
      try {
        await request.response.close();
      } finally {
        callback.complete(params);
      }
    });
    Map<String, String> params;
    try {
      final launched = await launchUrl(
        Uri.https('auth.openai.com', '/api/accounts/authorize', {
          'client_id': clientId ?? 'dynamic_agent_client',
          if (clientId == null) 'agent_name_hint': 'AI Dictionary',
          'ext_agent_host_id': host,
          if (saved?['id_token'] case final String token)
            'id_token_hint': token,
          'response_type': 'code',
          'redirect_uri': redirect,
          'scope':
              'openid profile email offline_access resource.invoke $_scope',
          'resource': _api,
          'state': state,
          'nonce': nonce,
          'code_challenge_method': 'S256',
          'code_challenge': _base64(
            sha256.convert(ascii.encode(verifier)).bytes,
          ),
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw const ChatGptPlanException('无法打开系统浏览器。');
      final waiting = callback.future;
      params =
          await (cancelled == null
                  ? waiting
                  : Future.any([
                      waiting,
                      cancelled.then<Map<String, String>>(
                        (_) =>
                            throw const ChatGptPlanException('已取消 ChatGPT 登录。'),
                      ),
                    ]))
              .timeout(
                const Duration(minutes: 3),
                onTimeout: () {
                  throw const ChatGptPlanException('ChatGPT 登录超时，请重试。');
                },
              );
    } finally {
      await listener.cancel();
      await server.close(force: true);
    }

    final issued = params['client_id'] ?? clientId;
    final code = params['code'];
    if (params.containsKey('error') ||
        code == null ||
        issued == null ||
        issued == 'dynamic_agent_client' ||
        (clientId != null && issued != clientId)) {
      throw const ChatGptPlanException('ChatGPT 授权未完成，请重新登录并授权套餐用量。');
    }
    final tokens = await _exchange({
      'grant_type': 'authorization_code',
      'client_id': issued,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirect,
    });
    final idToken = tokens['id_token'] as String;
    final claims = await _validateIdentity(idToken, issued, nonce);
    if (saved != null && saved['subject'] != claims['sub']) {
      throw const ChatGptPlanException('登录账号与此配置不匹配。');
    }
    await _saveTokens(id, {
      'client_id': issued,
      'subject': claims['sub'],
      'email': claims['email'],
      'id_token': idToken,
    }, tokens);
    return claims['email'] as String? ?? 'ChatGPT';
  }

  Future<Map<String, dynamic>> _validateIdentity(
    String token,
    String clientId,
    String nonce,
  ) async {
    Map<String, dynamic>? claims;
    try {
      final metadata = await _discovery();
      final jwks = _read(
        await http
            .get(Uri.parse(metadata['jwks_uri'] as String))
            .timeout(_timeout),
      );
      final keys = JsonWebKeyStore();
      for (final key in jwks['keys'] as List) {
        keys.addKey(JsonWebKey.fromJson(key as Map<String, dynamic>));
      }
      final jwt = JsonWebToken.unverified(token);
      if (await jwt.verify(keys, allowedArguments: ['RS256'])) {
        claims = jwt.claims.toJson();
      }
    } on FormatException {
      // Invalid identity tokens are handled below.
    }
    final audience = claims?['aud'];
    final validAudience =
        audience == clientId ||
        (audience is List &&
            audience.contains(clientId) &&
            (audience.length == 1 || claims?['azp'] == clientId));
    final expiry = claims?['exp'];
    final subject = claims?['sub'];
    if (claims == null ||
        claims['iss'] != _issuer ||
        !validAudience ||
        claims['nonce'] != nonce ||
        expiry is! num ||
        expiry <= DateTime.now().millisecondsSinceEpoch / 1000 ||
        subject is! String ||
        subject.isEmpty) {
      throw const ChatGptPlanException('无法验证 ChatGPT 登录身份，请重试。');
    }
    return claims;
  }

  Future<String> _saveTokens(
    String id,
    Map<String, dynamic> saved,
    Map<String, dynamic> tokens,
  ) async {
    final scope = tokens['scope'] as String? ?? saved['scope'] as String? ?? '';
    final access = tokens['access_token'];
    final refresh = tokens['refresh_token'] ?? saved['refresh_token'];
    final expires = tokens['expires_in'];
    if (!scope.split(RegExp(r'\s+')).contains(_scope)) {
      throw const ChatGptPlanException('请在登录时允许 AI Dictionary 使用 ChatGPT 套餐。');
    }
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expires is! num ||
        expires <= 0) {
      throw const ChatGptPlanException('ChatGPT 未返回有效的套餐凭证，请重新登录。');
    }
    await _storage.write(
      key: _key(id),
      value: jsonEncode({
        ...saved,
        'scope': scope,
        'access_token': access,
        'refresh_token': refresh,
        'expires_at':
            DateTime.now().millisecondsSinceEpoch + (expires * 1000).round(),
      }),
    );
    return access;
  }

  Future<String> _accessToken(String id) =>
      _refreshes.putIfAbsent(id, () async {
        try {
          final saved = await _session(id);
          if (saved == null) {
            throw const ChatGptPlanException('请在模型配置中登录 ChatGPT。');
          }
          if ((saved['expires_at'] as int) >
              DateTime.now()
                  .add(const Duration(minutes: 1))
                  .millisecondsSinceEpoch) {
            return saved['access_token'] as String;
          }
          return await _saveTokens(
            id,
            saved,
            await _exchange({
              'grant_type': 'refresh_token',
              'client_id': saved['client_id'] as String,
              'refresh_token': saved['refresh_token'] as String,
            }),
          );
        } finally {
          _refreshes.remove(id);
        }
      });

  Future<void> disconnect(String id) async {
    try {
      await _refreshes[id];
    } catch (_) {
      // A failed refresh must not prevent local sign-out.
    }
    final session = await _session(id);
    if (session == null) return;
    try {
      final metadata = await _discovery();
      await http
          .post(
            Uri.parse(metadata['revocation_endpoint'] as String),
            body: {
              'token': session['refresh_token'] as String,
              'token_type_hint': 'refresh_token',
              'client_id': session['client_id'] as String,
            },
          )
          .timeout(_timeout);
    } catch (_) {
      // Clear local credentials even when remote revocation is unavailable.
    } finally {
      await _storage.delete(key: _key(id));
    }
  }

  Future<Map<String, String>> models(String id) async {
    final token = await _accessToken(id);
    final data = _read(
      await http
          .get(
            Uri.parse('$_api/models'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout),
    );
    return {
      for (final model in (data['models'] as List? ?? []).whereType<Map>())
        if (model['visibility'] == 'list' && model['slug'] is String)
          model['slug'] as String:
              model['display_name'] as String? ?? model['slug'] as String,
    };
  }

  Future<({String text, int? inputTokens, int? outputTokens})> infer({
    required String id,
    required String model,
    required String input,
    required String instructions,
    required Duration timeout,
  }) async {
    final client = http.Client();
    try {
      return await _accessToken(id)
          .then((token) => _stream(client, token, model, input, instructions))
          .timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<({String text, int? inputTokens, int? outputTokens})> _stream(
    http.Client client,
    String token,
    String model,
    String input,
    String instructions,
  ) async {
    final request = http.Request('POST', Uri.parse('$_api/responses'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..followRedirects = false
      ..body = jsonEncode({
        'model': model,
        'input': [
          {'role': 'user', 'content': input},
        ],
        'instructions': instructions,
        'store': false,
        'stream': true,
      });
    final response = await client.send(request);
    if (response.statusCode != 200) {
      _read(await http.Response.fromStream(response));
      throw _requestError(null, response.statusCode);
    }
    final output = StringBuffer();
    final data = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
      if (line.isNotEmpty || data.isEmpty) continue;
      final payload = data.join('\n');
      data.clear();
      if (payload == '[DONE]') break;
      final event = jsonDecode(payload) as Map<String, dynamic>;
      switch (event['type']) {
        case 'response.output_text.delta':
          output.write(event['delta'] as String);
        case 'response.completed':
          final usage = (event['response'] as Map?)?['usage'] as Map?;
          if (output.isEmpty) {
            throw const ChatGptPlanException('ChatGPT 未返回文本。');
          }
          return (
            text: output.toString(),
            inputTokens: usage?['input_tokens'] as int?,
            outputTokens: usage?['output_tokens'] as int?,
          );
        case 'response.failed':
        case 'response.incomplete':
        case 'error':
          final error = (event['response'] as Map?)?['error'] as Map?;
          throw _requestError(error?['code'] ?? event['code'], null);
      }
    }
    throw const ChatGptPlanException('ChatGPT 响应中断，请重试。');
  }
}
