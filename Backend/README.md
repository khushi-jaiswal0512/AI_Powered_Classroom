AI-Powered Remote Classroom System

An intelligent remote classroom platform that enables seamless video-based learning, AI transcription, and automated quiz generation for enhanced student engagement.

🚀 Features
🎥 Video Management
Upload lecture videos (via file or URL)
Store videos securely using AWS S3
Stream videos in frontend (Flutter UI)

🧠 AI Transcription
Automatic speech-to-text using Whisper AI
Generate transcripts from uploaded lectures
Backend API support for transcription

📝 Quiz Generation
AI-generated quizzes from lecture transcripts
Teacher-triggered quiz generation
Interactive quiz UI for students

📊 Attendance System
Smart attendance tracking
Face recognition-based system (optional / future scope)

🔐 Authentication & Security
Role-based access (Teacher / Student)
Secure API endpoints using Spring Security

🏗️ Project Architecture
project-root/
│
├── Backend/                # Spring Boot Backend
│   ├── src/main/java/
│   ├── pom.xml
│   ├── Dockerfile
│   └── APIs (Video, Quiz, Transcription)
│
├── Frontend/              # Flutter App
│   ├── lib/
│   ├── UI Screens
│   └── API Integration
│
└── README.md

⚙️ Tech Stack
Backend
Java (OpenJDK 17)
Spring Boot
Spring Security
Maven
AWS S3
PostgreSQL / Render DB
Docker
Frontend
Flutter
Dart
REST API Integration
AI / ML
Whisper AI (Speech-to-Text)
LLM (for quiz generation, optional)

🔌 API Endpoints (Sample)
Video
POST /video/upload
POST /video/upload-url
GET  /video/{id}
Transcription
POST /api/transcribe
Quiz
POST /quiz/generate
GET  /quiz/{videoId}
🛠️ Setup Instructions

1️⃣ Clone Repository
git clone https://github.com/your-username/project.git
cd project

2️⃣ Backend Setup
cd Backend
./mvnw clean install
./mvnw spring-boot:run
Or using Docker:
docker build -t backend-app .
docker run -p 8080:8080 backend-app

3️⃣ Frontend Setup
cd Frontend
flutter pub get
flutter run

4️⃣ Environment Variables
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_BUCKET_NAME=
DB_URL=
DB_USERNAME=
DB_PASSWORD=

☁️ Deployment
Backend
Render / AWS / DigitalOcean
Configure DB + S3 + environment variables
Frontend
flutter build apk
flutter build web
🧪 Testing
Use Postman for API testing
Verify:
Video upload
Transcription API
Quiz generation

🔥 Future Improvements
Live classes (WebRTC / Zoom integration)
Real-time chat
AI recommendation system
Performance analytics
Production-ready face recognition
👨‍💻 Contributors
Shubh Sharma
📜 License

This project is for educational and research purposes.