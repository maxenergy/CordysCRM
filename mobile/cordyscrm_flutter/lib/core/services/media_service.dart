import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../utils/adaptive_file_picker.dart';
import 'platform_service.dart';

/// 媒体服务 - 处理图片选择、压缩和音频录制
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;

  /// 请求相机权限
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 请求存储权限（Android）
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  /// 从相册选择图片（自适应移动端和桌面端）
  Future<List<File>> pickImagesFromGallery({int maxImages = 9}) async {
    try {
      // 使用自适应文件选择器
      final filePaths = await AdaptiveFilePicker.pickImages(
        maxImages: maxImages,
        allowCamera: false,
      );
      
      if (filePaths == null || filePaths.isEmpty) return [];
      
      // 压缩图片
      final compressedFiles = <File>[];
      for (final path in filePaths) {
        final compressed = await _compressImage(File(path));
        if (compressed != null) {
          compressedFiles.add(compressed);
        }
      }
      
      return compressedFiles;
    } catch (e) {
      debugPrint('[MediaService] 选择图片失败: $e');
      return [];
    }
  }

  /// 拍照（仅移动端支持）
  Future<File?> takePhoto() async {
    try {
      // 桌面端不支持相机
      final platformService = PlatformService();
      if (!platformService.supportsCameraFeatures) {
        debugPrint('[MediaService] 当前平台不支持相机功能');
        return null;
      }

      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        debugPrint('[MediaService] 相机权限被拒绝');
        return null;
      }

      final filePath = await AdaptiveFilePicker.pickImageFromCamera();
      
      if (filePath == null) return null;
      
      return await _compressImage(File(filePath));
    } catch (e) {
      debugPrint('[MediaService] 拍照失败: $e');
      return null;
    }
  }

  /// 压缩图片
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, '${_uuid.v4()}.jpg');
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      if (result != null) {
        return File(result.path);
      }
      return file;
    } catch (e) {
      debugPrint('[MediaService] 压缩图片失败: $e');
      return file;
    }
  }

  /// 开始录音
  Future<bool> startRecording() async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('[MediaService] 麦克风权限被拒绝');
        return false;
      }

      if (_isRecording) {
        await stopRecording();
      }

      final dir = await getTemporaryDirectory();
      _currentRecordingPath = p.join(dir.path, '${_uuid.v4()}.m4a');

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      debugPrint('[MediaService] 开始录音: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('[MediaService] 开始录音失败: $e');
      _isRecording = false;
      return false;
    }
  }

  /// 停止录音
  Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('[MediaService] 录音完成: $path');
          return file;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[MediaService] 停止录音失败: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
        
        // 删除临时文件
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('[MediaService] 取消录音失败: $e');
    }
  }

  /// 获取录音时长流
  Stream<RecordState> get recordStateStream => _audioRecorder.onStateChanged();

  /// 释放资源
  Future<void> dispose() async {
    await cancelRecording();
    await _audioRecorder.dispose();
  }
}
