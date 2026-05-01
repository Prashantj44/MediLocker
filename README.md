# MediLocker 🏥🔐

A secure, intelligent, and cross-platform medical records vault built with **Flutter**, **Firebase**, and **Google Gemini AI**.

![MediLocker Preview](assets/images/app_icon.jpg)

## Features
- **Intelligent Medical Summaries**: Instantly extracts key findings and doctor recommendations from your uploaded medical documents (PDFs, Images) using the latest `gemini-3-flash-preview` model.
- **Medi AI Chat**: Talk to a personal, context-aware AI assistant that can analyze your entire medical history securely.
- **Bank-Grade Security**: All health records are locally encrypted via **AES-256** before touching the cloud, ensuring total patient privacy.
- **Web-Native Attachments**: Flawlessly streams bytes securely to **Firebase Storage** over the web.

## Tech Stack
- **Frontend**: Flutter (Cross-platform Web & Mobile)
- **Backend Infrastructure**: Firebase Authentication, Cloud Firestore, Firebase Storage
- **AI Brain**: Google Generative AI SDK (Gemini)
- **Security**: encrypt (AES-256 local encryption)

## Getting Started
1. Clone the repository: `git clone https://github.com/Prashantj44/MediLocker.git`
2. Run `flutter pub get`
3. Create a `.env` file in the root directory and add your key: `GEMINI_API_KEY=your_key_here`
4. Run the app: `flutter run -d chrome`

*Designed with 💙 for the future of healthcare.*
