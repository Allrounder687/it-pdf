import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolTaskStatus {
  idle,
  running, // Amber / Yellow
  completed, // Emerald Green
  error, // Crimson Red
}

class ToolTask {
  final String id;
  final String toolId;
  final String toolTitle;
  final IconData toolIcon;
  final String? inputPath;
  final String? outputPath;
  final ToolTaskStatus status;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ToolTask({
    required this.id,
    required this.toolId,
    required this.toolTitle,
    required this.toolIcon,
    this.inputPath,
    this.outputPath,
    this.status = ToolTaskStatus.idle,
    this.progress = 0.0,
    this.statusMessage = 'Queued',
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  ToolTask copyWith({
    String? inputPath,
    String? outputPath,
    ToolTaskStatus? status,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return ToolTask(
      id: id,
      toolId: toolId,
      toolTitle: toolTitle,
      toolIcon: toolIcon,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final ToolTaskStatus status;
  final VoidCallback? onAction;
  final String? actionLabel;

  const InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    this.onAction,
    this.actionLabel,
  });
}

class ToolTaskManagerNotifier extends Notifier<List<ToolTask>> {
  @override
  List<ToolTask> build() => [];

  ToolTask startTask({
    required String toolId,
    required String toolTitle,
    required IconData toolIcon,
    String? inputPath,
    String initialMessage = 'Processing in background...',
  }) {
    final task = ToolTask(
      id: '${toolId}_${DateTime.now().millisecondsSinceEpoch}',
      toolId: toolId,
      toolTitle: toolTitle,
      toolIcon: toolIcon,
      inputPath: inputPath,
      status: ToolTaskStatus.running,
      progress: 0.1,
      statusMessage: initialMessage,
      startedAt: DateTime.now(),
    );
    state = [task, ...state];
    return task;
  }

  void updateProgress(String taskId, double progress, String message) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            progress: progress.clamp(0.0, 1.0),
            statusMessage: message,
            status: ToolTaskStatus.running,
          )
        else
          t,
    ];
  }

  void completeTask(
    String taskId, {
    required String outputPath,
    String message = 'Task completed successfully!',
  }) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            status: ToolTaskStatus.completed,
            progress: 1.0,
            outputPath: outputPath,
            statusMessage: message,
            completedAt: DateTime.now(),
          )
        else
          t,
    ];

    final task = state.firstWhere((t) => t.id == taskId);
    ref
        .read(inAppNotificationsProvider.notifier)
        .push(
          InAppNotification(
            id: taskId,
            title: '${task.toolTitle} Finished',
            message: message,
            status: ToolTaskStatus.completed,
          ),
        );
  }

  void failTask(String taskId, {required String error}) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            status: ToolTaskStatus.error,
            errorMessage: error,
            statusMessage: 'Failed: $error',
            completedAt: DateTime.now(),
          )
        else
          t,
    ];

    final task = state.firstWhere((t) => t.id == taskId);
    ref
        .read(inAppNotificationsProvider.notifier)
        .push(
          InAppNotification(
            id: taskId,
            title: '${task.toolTitle} Failed',
            message: error,
            status: ToolTaskStatus.error,
          ),
        );
  }

  void dismissTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  void clearCompleted() {
    state = state.where((t) => t.status == ToolTaskStatus.running).toList();
  }
}

final toolTaskManagerProvider =
    NotifierProvider<ToolTaskManagerNotifier, List<ToolTask>>(
      ToolTaskManagerNotifier.new,
    );

class InAppNotificationsNotifier extends Notifier<List<InAppNotification>> {
  @override
  List<InAppNotification> build() => [];

  void push(InAppNotification notification) {
    state = [...state, notification];
    Future.delayed(const Duration(seconds: 5), () {
      dismiss(notification.id);
    });
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final inAppNotificationsProvider =
    NotifierProvider<InAppNotificationsNotifier, List<InAppNotification>>(
      InAppNotificationsNotifier.new,
    );
