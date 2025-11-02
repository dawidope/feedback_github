# feedback_github

A Flutter package that enables users to submit feedback as GitHub issues, storing images directly in the GitHub repository.

## Features
- Allows the user to provide interactive feedback directly in the app, by annotating a screenshot of the current page, as well as by adding text.
- Send this feedback as GitHub issues, storing screenshot images as files directly in the repository
- Optionally add debug informations (package and device info)


<!--
commands :

dart doc
dart format .
flutter pub publish --dry-run
-->

<p align="center">
  <img src="https://raw.githubusercontent.com/ueman/feedback/master/img/example_0.1.0-beta.gif" width="200" alt="Example Image">
</p>

## Getting started

1. Create a GitHub token (see below)
2. Wrap you app with BetterFeedbackWidget : 

```dart
void main() {
  runApp(
    BetterFeedback(
      child: const App(),
    ),
  );
}
```

3. Provide a way to show the feedback and that's it !
```dart
// you can check how it will look here https://github.com/tempo-riz/dummy-repo/issues/2
BetterFeedback.of(context).showAndUploadToGitHub(
    repoUrl: "https://github.com/tempo-riz/dummy-repo",
    // Save it in an environment variable :)
    gitHubToken: dotenv.get("GITHUB_ISSUE_TOKEN"),
    // those are optionals (default values)
    labels: ['feedback'], // labels to add to the issue
    packageInfo: true, // show package Info
    deviceInfo: true, // show device Info
    extraData: "Some extra data you want to add in the issue",
    onSucces: (issue) => print("succes !"),
    onError: (error) => print("failed :/ $error"),
)
// this returns a Future<Issue> so you can await it if you want or use callbacks
```

Alternatively you can use directly `uploadToGitHub()` if you don't want to use the panel (image is optional)


You can also call `BetterFeedback.of(context).hide()` to manually dimiss the panel


## Get a GitHub token
- go [Here](https://github.com/settings/personal-access-tokens)
- generate new token with : 
    1. name it and add an optional expiration time
    2. Repository access : Only select repositories, select your repo
    3. Add permissions : 
       - **Issues** (read and write) - to create feedback issues
       - **Contents** (read and write) - to upload screenshot images to the repository
    4. Generate your token and save it securely (don't commit it in a repo)

## 🔐 Security considerations

⚠️ **Important security notes:**

- **Token security**: Never commit your GitHub token to version control. Always use environment variables or secure storage.
- **Repository access**: The token has **Contents write access**, which means it can create, modify, and delete files in your repository. 
- **Image storage**: Screenshots are stored as files in an `images/` folder in your repository, making them publicly accessible if your repository is public.
- **Token scope**: Grant the minimum necessary permissions. Only give access to specific repositories that need feedback functionality.
- **Token rotation**: Regularly rotate your tokens and set reasonable expiration dates.
- **Monitoring**: Monitor your repository for unexpected file uploads in the `images/` folder.

**Potential risks:**
- If the token is compromised, attackers could upload arbitrary files to your repository
- In public repositories, all feedback screenshots become publicly viewable
- High feedback volume could consume significant repository storage space

## 🎨 Configuration & customization

```dart
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(
    BetterFeedback(
      child: const MyApp(),
      theme: FeedbackThemeData(
        background: Colors.grey,
        feedbackSheetColor: Colors.grey[50]!,
        drawColors: [
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.yellow,
        ],
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalFeedbackLocalizationsDelegate(),
      ],
      localeOverride: const Locale('en'),
    ),
  );
}
```
How the properties of `FeedbackThemeData` correspond to the view can be seen in the following image. 
<img src="https://raw.githubusercontent.com/ueman/feedback/master/img/theme_description.png" max-height="400" alt="Theme Usages">

## Changing the localizations texts

You can customize the localizations as follows.
Create your own implementation of `FeedbackLocalizations` or subclass one of 
the existing translations, if you just want to change one or two texts.
Then create your own `GlobalFeedbackLocalizationsDelegate` and pass it to 
`BetterFeedback`.

```dart
class CustomFeedbackLocalizations implements FeedbackLocalizations {
  // ...
}

class CustomFeedbackLocalizationsDelegate
    extends GlobalFeedbackLocalizationsDelegate {
  static final supportedLocales = <Locale, FeedbackLocalizations>{
    // remember to change the locale identifier
    // as well as that defaultLocale (defaults to en) should ALWAYS be
    // present here or overridden
    const Locale('en'): const CustomFeedbackLocalizations(),
  };
}

void main() {
  runApp(
    BetterFeedback(
      child: const MyApp(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        CustomFeedbackLocalizationsDelegate(),
      ],
    ),
  );
}
```

### Why store images in the repository ?

GitHub's API doesn't allow uploading files directly to issues (only via the web interface), so images are stored as files in the repository and linked in the issue description. This eliminates the need for external storage services like Firebase Storage.


### Credits 🙏

This package is based on the original work of [Jonas Uekötter](https://github.com/ueman). Check out the original repository [here](https://github.com/ueman/feedback/tree/master).

The GitHub integration functionality was originally developed in [tempo-riz/dummy-repo](https://github.com/tempo-riz/dummy-repo) and has been extracted into this standalone package.

### Issues, questions and contributing

Contributions are always welcome ! Consider creating issues in the original repo if related to the UI part :)