import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

export 'package:feedback/feedback.dart';
export 'package:github/github.dart';

/// extension to call [uploadToGitHub]
extension FeedbackGitHub on FeedbackController {
  /// Check [uploadToGitHub] for more documentation
  Future<Issue> showAndUploadToGitHub({
    required String repoUrl,
    required String gitHubToken,
    List<String> labels = const ['feedback'],
    bool packageInfo = true,
    bool deviceInfo = true,
    bool allowEmptyText = true,
    String? extraData,
    bool allowProdEmulatorFeedback = true,
    void Function(Issue)? onSucces,
    void Function(Object error)? onError,
    void Function()? onCancel,
  }) {
    final Completer<Issue> completer = Completer<Issue>();

    show((feedback) async {
      hide(); // don't block the UI
      if (!allowEmptyText && feedback.text.isEmpty) {
        debugPrint("Feedback text is empty, cancelling");
        onCancel?.call();
        return;
      }
      try {
        final issue = await uploadToGitHub(
          repoUrl: repoUrl,
          gitHubToken: gitHubToken,
          feedbackText: feedback.text,
          screenshot: feedback.screenshot,
          filename: "file.png",
          labels: labels,
          packageInfo: packageInfo,
          deviceInfo: deviceInfo,
          extraData: extraData,
          allowProdEmulatorFeedback: allowProdEmulatorFeedback,
        );
        onSucces?.call(issue);
        completer.complete(issue);
      } catch (e) {
        onError?.call(e);
        completer.completeError(e);
      }
    });

    return completer.future;
  }
}

/// Store image in GitHub repository and create GitHub issue with feedback
///
/// [repoUrl] is the URL of the GitHub repository.
///
/// [gitHubToken] is the token used for GitHub authentication.
///
/// [title] is the title of the issue created
///
/// [feedbackText] is the main content of the feedback.
///
/// [screenshot] the screenshot
///
/// [labels] are the labels to be applied to the GitHub issue. Default is `['feedback']`.
///
/// [packageInfo] indicates whether to include package information. Default is `true`.
///
/// [deviceInfo] indicates whether to include device information. Default is `true`.
///
/// [extraData] is any additional data to be included.
///
/// [allowProdEmulatorFeedback] if true, feedback from emulator in production will be allowed (could be google play bots)
///
/// [imageDisplayWidth] is the width of the image displayed in the issue. Default is `300`.
Future<Issue> uploadToGitHub({
  required String repoUrl,
  required String gitHubToken,
  required String feedbackText,
  String? title,
  Uint8List? screenshot,
  String? filename,
  List<String> labels = const ['feedback'],
  bool packageInfo = true,
  bool deviceInfo = true,
  String? extraData,
  bool allowProdEmulatorFeedback = true,
  int imageDisplayWidth = 300,
}) async {
  assert(
      (screenshot == null && filename == null) ||
          (screenshot != null && filename != null),
      "Both screenshot and filename should be either provided or neither should be provided");

  await Future.delayed(const Duration(milliseconds: 500));
  final String? imageUrl = screenshot != null
      ? await uploadImageToStorage(screenshot, filename!, repoUrl, gitHubToken)
      : null;

  final String image = imageUrl != null
      ? '<img src="$imageUrl" width="$imageDisplayWidth" />\n\n'
      : "no image attached";

  final String package = packageInfo
      ? "## Package\n${Platform.operatingSystem}\n${_formatKeys((await PackageInfo.fromPlatform()).data, [
              "version",
              "buildNumber",
              "installerStore"
            ])}\n\n"
      : "";

  final deviceData = (await DeviceInfoPlugin().deviceInfo).data;

  final String device = deviceInfo
      ? "## Device\n${_formatKeys(deviceData, [
              "model",
              "brand",
              "version",
              "systemVersion",
              "isPhysicalDevice"
            ])}\n\n"
      : "";

  // cancel if emulator in production (only ios and android)
  if (!allowProdEmulatorFeedback &&
      kReleaseMode &&
      (Platform.isAndroid || Platform.isIOS)) {
    final bool isPhysicalDevice = (deviceData["isPhysicalDevice"] ?? false);
    if (!isPhysicalDevice) {
      throw Exception("Emulator feedback not allowed in production");
    }
  }

  final String extra = extraData != null ? '## Extra\n$extraData' : "";

  final String body = '$feedbackText \n\n $image $package $device $extra';

  final String issueTitle = title ??
      '[FEEDBACK] ${feedbackText.substring(0, min(100, feedbackText.length))}';

  return createGithubIssue(
      repoUrl: repoUrl,
      title: issueTitle,
      body: body,
      gitHubToken: gitHubToken,
      labels: labels);
}

/// Upload image to GitHub repository and return the download url
Future<String?> uploadImageToStorage(
  Uint8List imageData,
  String filename,
  String repoUrl,
  String gitHubToken,
) async {
  try {
    final github = GitHub(auth: Authentication.withToken(gitHubToken));
    final slug = _parseRepositorySlug(repoUrl);

    // Generate unique filename to avoid conflicts
    final ext = filename.split(".").last;
    final newFilename = '${const Uuid().v4()}.$ext';
    final imagePath = 'images/$newFilename';

    final imageBase64 = base64Encode(imageData);

    // Create file in repository
    await github.repositories.createFile(
      slug,
      CreateFile(
        message: 'upload feedback screenshot',
        content: imageBase64,
        path: imagePath,
      ),
    );

    // Return URL in format: https://github.com/owner/repo/blob/main/images/filename.png?raw=true
    // This format works without authentication and returns the raw image
    return 'https://github.com/${slug.owner}/${slug.name}/blob/main/$imagePath?raw=true';
  } catch (e) {
    debugPrint(e.toString());
    return null;
  }
}

/// Create issue on the specified repo
Future<Issue> createGithubIssue({
  required String repoUrl,
  required String title,
  required String body,
  required String gitHubToken,
  List<String> labels = const ['feedback'],
}) async {
  final github = GitHub(auth: Authentication.withToken(gitHubToken));
  final slug = _parseRepositorySlug(repoUrl);

  IssueRequest issue = IssueRequest(
    title: title,
    body: body,
    labels: labels,
  );
  return github.issues.create(slug, issue);
}

/// Parse repository slug from GitHub URL
/// Supports URLs like:
/// - https://github.com/owner/repo
/// - https://github.com/owner/repo.git
RepositorySlug _parseRepositorySlug(String repoUrl) {
  final split = repoUrl.split("/");
  final owner = split[split.length - 2];
  final name =
      split[split.length - 1].split(".").first; // remove .git if present
  return RepositorySlug(owner, name);
}

String _formatKeys(Map<String, dynamic> map, List<String> keys) {
  return keys
      .map((key) => map.containsKey(key) && map[key] != null
          ? "$key: ${map[key].toString()}"
          : null)
      .where((value) => value != null)
      .join("\n");
}
