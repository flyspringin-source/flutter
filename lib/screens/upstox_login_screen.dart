import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/upstox_auth.dart';
import '../theme/app_theme.dart';

class UpstoxLoginScreen extends StatefulWidget {
  const UpstoxLoginScreen({
    super.key,
    required this.apiKey,
    required this.redirectUrl,
    required this.state,
  });

  final String apiKey;
  final String redirectUrl;
  final String state;

  @override
  State<UpstoxLoginScreen> createState() => _UpstoxLoginScreenState();
}

class _UpstoxLoginScreenState extends State<UpstoxLoginScreen> {
  late final WebViewController _web;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && isUpstoxRedirect(uri, widget.redirectUrl)) {
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];
              if (error != null && error.isNotEmpty) {
                Navigator.of(context).pop('error:$error');
              } else {
                Navigator.of(context).pop(code);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        upstoxLoginUri(
          apiKey: widget.apiKey,
          redirectUrl: widget.redirectUrl,
          state: widget.state,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upstox login'),
        backgroundColor: colors.surface,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
