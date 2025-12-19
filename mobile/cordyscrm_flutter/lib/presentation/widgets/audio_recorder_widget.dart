import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/services/media_service.dart';
import '../theme/app_theme.dart';

/// 音频录制组件
class AudioRecorderWidget extends StatefulWidget {
  const AudioRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.maxDuration = const Duration(minutes: 5),
  });

  final void Function(File audioFile) onRecordingComplete;
  final Duration maxDuration;

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  final MediaService _mediaService = MediaService();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      _mediaService.cancelRecording();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _mediaService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _startTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法开始录音，请检查麦克风权限'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
      
      // 检查最大时长
      if (_recordDuration >= widget.maxDuration) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final file = await _mediaService.stopRecording();
    
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (file != null) {
      widget.onRecordingComplete(file);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _mediaService.cancelRecording();
    
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 录音动画和时长
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RecordingIndicator(),
                const SizedBox(width: 12),
                Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ ${_formatDuration(widget.maxDuration)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 取消按钮
                TextButton.icon(
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  label: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 24),
                // 完成按钮
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('完成', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 开始录音按钮
    return InkWell(
      onTap: _startRecording,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_outlined, size: 20, color: AppTheme.textSecondary),
            SizedBox(width: 6),
            Text('语音', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 录音指示器动画
class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.errorColor.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
