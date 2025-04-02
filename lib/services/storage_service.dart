import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // 이미지 파일을 Firebase Storage에 업로드하고 다운로드 URL을 반환
  Future<String?> uploadImage(File imageFile) async {
    try {
      // 이미지 압축
      final compressedFile = await _compressImage(imageFile);
      if (compressedFile == null) {
        print('이미지 압축 실패');
        return null;
      }
      
      // 고유한 파일 이름 생성
      final String fileName = '${_uuid.v4()}.jpg';
      final String folderPath = 'posts';
      final String fullPath = '$folderPath/$fileName';
      
      print('이미지 업로드 시작: $fullPath');
      print('Firebase Storage 버킷: ${_storage.bucket}');
      
      // 이미지 파일 경로 설정 (posts 폴더 아래에 저장)
      final Reference ref = _storage.ref().child(folderPath).child(fileName);
      
      // 이미지 파일 업로드 및 진행 상태 모니터링
      final UploadTask uploadTask = ref.putFile(
        compressedFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'fileName': fileName,
            'uploaded': DateTime.now().toString(),
          }
        ),
      );
      
      // 업로드 진행 상태 모니터링 (선택사항)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('업로드 진행률: ${(progress * 100).toStringAsFixed(2)}%');
      });
      
      // 타임아웃 처리
      bool isCompleted = false;
      
      // 업로드 작업 처리
      final uploadFuture = uploadTask.whenComplete(() {
        isCompleted = true;
        print('업로드 완료: $fullPath');
      });
      
      // 타임아웃 처리
      await Future.any([
        uploadFuture,
        Future.delayed(const Duration(seconds: 180), () {
          if (!isCompleted) {
            print('이미지 업로드 타임아웃 발생: $fullPath');
          }
        })
      ]);
      
      // 업로드가 완료되지 않았으면 null 반환
      if (!isCompleted) {
        print('업로드 실패 (타임아웃): $fullPath');
        return null;
      }
      
      // 업로드 완료 대기
      final TaskSnapshot taskSnapshot = await uploadTask;
      
      // 이미지 URL 반환
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('다운로드 URL 획득: $downloadUrl');
      print('다운로드 URL에 alt=media 있는지 확인: ${downloadUrl.contains('alt=media') ? '있음' : '없음'}');
      
      try {
        // URL이 유효한지 테스트
        final uri = Uri.parse(downloadUrl);
        print('URL 스키마: ${uri.scheme}, 호스트: ${uri.host}, 경로: ${uri.path}');
        
        // 이미지 URL이 정상인지 확인
        if (downloadUrl.contains('firebasestorage.googleapis.com') || 
            downloadUrl.contains('.firebasestorage.app')) {
          print('Firebase Storage URL 확인: 정상');
        } else {
          print('경고: Firebase Storage URL 형식이 예상과 다릅니다');
        }
        
        // URL이 public 액세스 가능한지 확인
        if (!downloadUrl.contains('alt=media')) {
          // Firebase Storage URL에 alt=media 파라미터 추가 (공개 액세스 허용)
          print('URL에 public 액세스 파라미터 추가');
          if (downloadUrl.contains('?')) {
            final modifiedUrl = '$downloadUrl&alt=media';
            print('수정된 URL: $modifiedUrl');
            return modifiedUrl;
          } else {
            final modifiedUrl = '$downloadUrl?alt=media';
            print('수정된 URL: $modifiedUrl');
            return modifiedUrl;
          }
        }
      } catch (e) {
        print('URL 파싱 오류: $e');
      }
      
      // 임시 파일 삭제
      if (compressedFile.path != imageFile.path) {
        await compressedFile.delete();
      }
      
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      
      // 오류 상세 정보 수집
      String errorDetails = '';
      if (e is FirebaseException) {
        errorDetails = '코드: ${e.code}, 메시지: ${e.message}';
      }
      print('Firebase 오류 상세: $errorDetails');
      
      return null;
    }
  }
  
  // 이미지 압축 메서드
  Future<File?> _compressImage(File file) async {
    try {
      // 이미지 정보 확인
      final fileSize = await file.length();
      print('원본 이미지 크기: ${(fileSize / 1024).round()}KB');
      
      // 파일 확장자 확인
      final ext = path.extension(file.path).toLowerCase();
      
      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}$ext';
      
      int quality = 85; // 기본 품질
      
      // 이미지 크기에 따라 압축 품질 조정
      if (fileSize > 10 * 1024 * 1024) { // 10MB 이상
        quality = 50;
      } else if (fileSize > 5 * 1024 * 1024) { // 5MB 이상
        quality = 60;
      } else if (fileSize > 2 * 1024 * 1024) { // 2MB 이상
        quality = 70;
      }
      
      // 이미지 압축
      var result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: 1024, 
        minHeight: 1024, 
        format: ext == '.png' ? CompressFormat.png : CompressFormat.jpeg,
      );
      
      if (result == null) {
        print('이미지 압축 실패, 원본 사용');
        return file;
      }
      
      final compressedSize = await File(result.path).length();
      print('압축 후 이미지 크기: ${(compressedSize / 1024).round()}KB');
      
      // XFile을 File로 변환하여 반환
      return File(result.path);
    } catch (e) {
      print('이미지 압축 오류: $e');
      return file; // 압축 실패 시 원본 반환
    }
  }
  
  // URL로 이미지 삭제
  Future<bool> deleteImage(String imageUrl) async {
    try {
      String cleanUrl = imageUrl;
      
      // alt=media 파라미터 제거 (참조 추출에 문제가 될 수 있음)
      if (imageUrl.contains('?alt=media')) {
        cleanUrl = imageUrl.replaceAll('?alt=media', '');
      } else if (imageUrl.contains('&alt=media')) {
        cleanUrl = imageUrl.replaceAll('&alt=media', '');
      }
      
      print('이미지 삭제 - 정제된 URL: $cleanUrl');
      final Reference ref = _storage.refFromURL(cleanUrl);
      
      // 이미지 삭제
      await ref.delete();
      return true;
    } catch (e) {
      print('이미지 삭제 오류: $e');
      return false;
    }
  }
}