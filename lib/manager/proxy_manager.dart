import 'dart:async';

import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager>
    with WidgetsBindingObserver {
  Future<void> _proxyTask = Future.value();

  Future<void> _stopProxy() async {
    await proxy?.stopProxy();
  }

  void _scheduleProxyTask(Future<void> Function() action) {
    _proxyTask = _proxyTask
        .catchError((_) {})
        .then((_) => mounted ? action() : Future<void>.value());
  }

  Future<void> _updateProxy(ProxyState proxyState) async {
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    if (isStart && systemProxy) {
      await proxy?.startProxy(port, proxyState.bassDomain);
    } else {
      await _stopProxy();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialState = ref.read(proxyStateProvider);
    if (!(initialState.isStart && initialState.systemProxy)) {
      _scheduleProxyTask(_stopProxy);
    }
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _scheduleProxyTask(() => _updateProxy(next));
      }
    }, fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _scheduleProxyTask(_stopProxy);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleProxyTask(_stopProxy);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
